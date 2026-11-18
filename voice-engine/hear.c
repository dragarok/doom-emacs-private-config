/*  hear – speech to text, kept loaded, for Emacs on the phone and the Mac.
 *
 *    hear serve  WEIGHTS SOCKET [--vocab FILE[,FILE…]] [--save DIR] [--beam N] [--boost B] [--cache-codes]
 *    hear file   WEIGHTS AUDIO.wav… [--vocab FILE[,FILE…]] [--beam N] [--boost B]
 *    hear client SOCKET [key=value…]     raw 16 kHz mono s16le on stdin, the replies on stdout
 *    hear send   SOCKET LINE             one request line (PING, QUIT, FILE /x.wav), the replies on stdout
 *
 *  The server holds the model and listens on a Unix socket, one client at a time, and none can hold it: the request
 *  line must come within 2 s, a stream that stops coming for 2 s is taken as ended, and none goes on past maxsec + 4 s
 *  of the clock (a client once went quiet without closing, the server waited on it, and the next client's microphone
 *  stayed on behind it).  A client opens with a line:
 *
 *    LISTEN [vocab=F,G] [hangover=MS] [nospeech=MS] [maxsec=S] [partial=MS] [beam=N] [boost=B] [save=0|1] [tag=WORD]
 *         [tail=MS] [preroll=MS] [pad=MS] [snr=DB] [vadmode=0-3]
 *        then streams raw 16 kHz mono s16le.  The server finds where speech starts and ends and answers, a line each:
 *        START (speech began) · PARTIAL text (with partial=MS) · END (stop sending) · TEXT best · ALT other ·
 *        NONE (nothing said) · INFO timings.  Closing the stream early (shutdown write) means "done, decode now";
 *        closing the socket means cancel.
 *    FILE /path.wav [vocab=…]   transcribe a file: TEXT, ALT, INFO.
 *    PING                       PONG with the phrase count.
 *    QUIT                       the server exits.
 *
 *  Where speech starts and ends: a frame is speech when WebRTC's voice detector (libfvad, fetched by the Makefile),
 *  in its strictest mode as FUTO's voice input uses it, says so and the frame stands `snr' dB (3) above the room's
 *  own floor.  Speech has begun after 150 ms of it (or a frame of it clearly loud) and ended after `hangover' (1 s)
 *  of none.  Once begun, a frame carries it on only in a run of three (90 ms) standing half way from the room to the
 *  speaker's level: a keyboard's clicks don't keep it listening.  Measured on real recordings over a typing room
 *  (test/endpoint.py): ends 0.5-0.8 s after speech, room alone never speech; 6 dB louder, the same.  The lenient
 *  modes catch a voice at arm's length (-50 dBFS) but end seconds late in the louder room; 12 dB louder, every
 *  mode does, and only a neural detector would tell typing from talk.
 *
 *  The words come from the vocabulary files at every request, read again whenever one changes: the phrases the
 *  decoder is pulled toward (bias.h).  Saved utterances (--save DIR) are DIR/STAMP.wav plus a line in
 *  DIR/heard.tsv: epoch, file, tag, text, alternatives, milliseconds – what a weekly retraining learns from.
 */

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include "phonon25.h"
#include "bias.h"
#include "fvad.h"

#include <errno.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define RATE        16000
#define VAD_FRAME   480            /* 30 ms: the voice detector's frames */
#define IGNORE      (RATE * 15 / 100)  /* the first 150 ms: the press itself is heard */
#define PREROLL     (RATE * 3 / 10)
#define MAX_ALTS    4
#define LINE_MS     2000           /* for the request line */
#define IDLE_MS     2000           /* no audio this long: the client has stopped sending without saying so */
#define OVERRUN_S   4              /* a stream ends this long past maxsec, by the clock */

static const P25Engine *engine;
static int   g_beam = 4;
static float g_boost = 3.0f;
static char  g_vocab[2048];
static char  g_save[1024];

/* ── Decoding ─────────────────────────────────────────────────────────────── */

typedef struct {
    char  *text[MAX_ALTS];
    int    n;
    double enc_s, dec_s;
} Heard;

static void heard_free(Heard *h)
{
    for (int i = 0; i < h->n; i++) free(h->text[i]);
    memset(h, 0, sizeof(*h));
}

/* The words alone: lower case, letters and digits, single spaces – so "Open X." and "open x" are one answer. */
static void words_only(const char *t, char *out, size_t cap)
{
    size_t j = 0;
    int space = 0;
    for (const unsigned char *c = (const unsigned char *)t; *c && j + 2 < cap; c++) {
        if ((*c >= '0' && *c <= '9') || (*c >= 'a' && *c <= 'z') || *c >= 0x80) { if (space && j) out[j++] = ' '; out[j++] = *c; space = 0; }
        else if (*c >= 'A' && *c <= 'Z') { if (space && j) out[j++] = ' '; out[j++] = *c + 32; space = 0; }
        else if (*c == ' ' || *c == '-') space = 1;
    }
    out[j] = 0;
}

static int decode(const float *a, int n, const HearContext *ctx, int beam, Heard *o)
{
    memset(o, 0, sizeof(*o));
    const P25Model *m = p25_engine_model(engine);
    const P25Tokens *tk = p25_engine_tokens(engine);
    float *mel;
    int nf;
    if (n < RATE / 10 || p25_mel_spectrogram(a, n, &mel, &nf) != 0) return 0;
    if (nf < P25_SUB_FACTOR) { free(mel); return 0; }
    double t0 = p25_now_sec();
    float *enc;
    int T;
    int rc = p25_encoder(m, mel, nf, &enc, &T);
    free(mel);
    if (rc != 0) return -1;
    double t1 = p25_now_sec();
    if (!ctx && beam <= 1) {
        P25Token *toks;
        int k = p25_greedy_decode(m, enc, T, &toks);
        o->text[o->n++] = p25_tokens_text(tk, toks, k);
        free(toks);
    } else {
        /* Your words may change how what was said is spelled, never make speech of what wasn't: with no words
           at all from the model left to itself, nothing was said.  On a whisper from across the desk and on a
           breath, the vocabulary alone made "12 Rules for Life ... Play Store" and "Thank you"; the model alone,
           nothing.  Greedy, on the encoder's output already there: a few ms. */
        if (ctx) {
            P25Token *toks;
            int k = p25_greedy_decode(m, enc, T, &toks);
            char *plain = p25_tokens_text(tk, toks, k);
            free(toks);
            char w[1024];
            words_only(plain ? plain : "", w, sizeof(w));
            free(plain);
            if (!w[0]) {
                free(enc);
                o->enc_s = t1 - t0;
                o->dec_s = p25_now_sec() - t1;
                return 0;
            }
        }
        HearHyp hy[MAX_ALTS];
        int k = hear_beam_decode(m, enc, T, ctx, beam, hy, MAX_ALTS);
        for (int i = 0; i < k; i++) {
            char *t = p25_tokens_text(tk, hy[i].tokens, hy[i].n);
            int dup = 0;
            char wa[1024], wb[1024];
            words_only(t, wa, sizeof(wa));
            for (int j = 0; j < o->n; j++) { words_only(o->text[j], wb, sizeof(wb)); if (!strcmp(wa, wb)) dup = 1; }
            if (dup) free(t); else o->text[o->n++] = t;
            free(hy[i].tokens);
        }
    }
    free(enc);
    o->enc_s = t1 - t0;
    o->dec_s = p25_now_sec() - t1;
    for (int i = 0; i < o->n; i++)                       /* one line each, always */
        for (char *c = o->text[i]; *c; c++) if (*c == '\n' || *c == '\t' || *c == '\r') *c = ' ';
    return 0;
}

/* ── Vocabulary: files read again when they change ───────────────────────── */

#define MAX_VOCAB_FILES 8
static struct {
    char        list[2048];
    float       boost;
    time_t      mtime[MAX_VOCAB_FILES];
    off_t       size[MAX_VOCAB_FILES];
    HearContext *ctx;
} vc;

static char *slurp(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc(n + 2);
    size_t got = fread(buf, 1, n, f);
    fclose(f);
    buf[got] = '\n';
    buf[got + 1] = 0;
    *len = got + 1;
    return buf;
}

static const HearContext *vocab(const char *list, float boost)
{
    if (!list || !*list) return NULL;
    char paths[MAX_VOCAB_FILES][1024];
    int np = 0;
    char tmp[2048];
    snprintf(tmp, sizeof(tmp), "%s", list);
    for (char *s = strtok(tmp, ","); s && np < MAX_VOCAB_FILES; s = strtok(NULL, ","))
        snprintf(paths[np++], sizeof(paths[0]), "%s", s);
    int changed = strcmp(vc.list, list) != 0 || vc.boost != boost;
    struct stat st[MAX_VOCAB_FILES];
    for (int i = 0; i < np; i++) {
        if (stat(paths[i], &st[i]) != 0) { st[i].st_mtime = 0; st[i].st_size = -1; }
        if (st[i].st_mtime != vc.mtime[i] || st[i].st_size != vc.size[i]) changed = 1;
    }
    if (!changed) return vc.ctx;
    size_t total = 0;
    char *all = (char *)calloc(1, 1);
    for (int i = 0; i < np; i++) {
        size_t len;
        char *b = slurp(paths[i], &len);
        vc.mtime[i] = st[i].st_mtime;
        vc.size[i] = st[i].st_size;
        if (!b) continue;
        all = (char *)realloc(all, total + len + 1);
        memcpy(all + total, b, len + 1);
        total += len;
        free(b);
    }
    hear_context_free(vc.ctx);
    double t = p25_now_sec();
    vc.ctx = hear_context_build(p25_engine_tokens(engine), all, boost);
    free(all);
    snprintf(vc.list, sizeof(vc.list), "%s", list);
    vc.boost = boost;
    fprintf(stderr, "hear: vocabulary %d phrases, %d nodes, %.0f ms\n", hear_context_phrases(vc.ctx),
            hear_context_nodes(vc.ctx), (p25_now_sec() - t) * 1000);
    return vc.ctx;
}

/* ── Replies and requests ─────────────────────────────────────────────────── */

static int say(int fd, const char *fmt, ...)
{
    char line[8192];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(line, sizeof(line) - 1, fmt, ap);
    va_end(ap);
    if (n < 0) return -1;
    if (n > (int)sizeof(line) - 2) n = sizeof(line) - 2;
    line[n++] = '\n';
    return write(fd, line, n) == n ? 0 : -1;
}

typedef struct {
    char  vocab[2048], tag[32];
    int   hangover, nospeech, maxsec, partial, beam, save, preroll, tail, pad, vadmode;
    float snr;
    float boost;
} Opts;

static void parse_opts(char *words, Opts *o)
{
    snprintf(o->vocab, sizeof(o->vocab), "%s", g_vocab);
    snprintf(o->tag, sizeof(o->tag), "listen");
    o->hangover = 1000; o->nospeech = 5000; o->preroll = 300; o->tail = 250; o->pad = 0; o->vadmode = 3; o->snr = 3; o->maxsec = 30; o->partial = 0;
    o->beam = g_beam; o->boost = g_boost; o->save = g_save[0] != 0;
    for (char *w = strtok(words, " "); w; w = strtok(NULL, " ")) {
        char *eq = strchr(w, '=');
        if (!eq) continue;
        *eq = 0;
        const char *v = eq + 1;
        if (!strcmp(w, "vocab")) snprintf(o->vocab, sizeof(o->vocab), "%s", v);
        else if (!strcmp(w, "tag")) {
            int j = 0;
            for (const char *c = v; *c && j < 31; c++)
                if ((*c >= 'a' && *c <= 'z') || *c == '-' || (*c >= '0' && *c <= '9')) o->tag[j++] = *c;
            o->tag[j] = 0;
        }
        else if (!strcmp(w, "hangover")) o->hangover = atoi(v);
        else if (!strcmp(w, "preroll")) o->preroll = atoi(v);
        else if (!strcmp(w, "tail")) o->tail = atoi(v);
        else if (!strcmp(w, "nospeech")) o->nospeech = atoi(v);
        else if (!strcmp(w, "maxsec")) o->maxsec = atoi(v);
        else if (!strcmp(w, "pad")) o->pad = atoi(v);
        else if (!strcmp(w, "vadmode")) o->vadmode = atoi(v);
        else if (!strcmp(w, "snr")) o->snr = (float)atof(v);
        else if (!strcmp(w, "partial")) o->partial = atoi(v);
        else if (!strcmp(w, "beam")) o->beam = atoi(v);
        else if (!strcmp(w, "boost")) o->boost = (float)atof(v);
        else if (!strcmp(w, "save")) o->save = atoi(v) && g_save[0];
    }
}

static void reply_heard(int fd, const Heard *h, double audio_s, double wait_s)
{
    if (h->n == 0 || !h->text[0][0]) say(fd, "NONE");
    else {
        say(fd, "TEXT %s", h->text[0]);
        for (int i = 1; i < h->n; i++) say(fd, "ALT %s", h->text[i]);
    }
    say(fd, "INFO audio=%.2f encoder=%.3f decoder=%.3f wait=%.3f", audio_s, h->enc_s, h->dec_s, wait_s);
}

static void write_wav(const char *path, const float *a, int n)
{
    FILE *f = fopen(path, "wb");
    if (!f) return;
    int bytes = n * 2;
    unsigned char h[44] = "RIFF....WAVEfmt \x10\0\0\0\x01\0\x01\0....\0\0\0\0\x02\0\x10\0data....";
    int v;
    v = 36 + bytes; memcpy(h + 4, &v, 4);
    v = RATE; memcpy(h + 24, &v, 4);
    v = RATE * 2; memcpy(h + 28, &v, 4);
    memcpy(h + 40, &bytes, 4);
    fwrite(h, 1, 44, f);
    for (int i = 0; i < n; i++) {
        float x = a[i] * 32768.0f;
        short s = x > 32767 ? 32767 : x < -32768 ? -32768 : (short)lrintf(x);
        fwrite(&s, 2, 1, f);
    }
    fclose(f);
}

static void save_utterance(const Opts *o, const float *a, int n, const Heard *h, double ms)
{
    if (!o->save || !g_save[0] || n <= 0) return;
    mkdir(g_save, 0700);
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    struct tm tm;
    localtime_r(&ts.tv_sec, &tm);
    char stamp[64], path[1200];
    snprintf(stamp, sizeof(stamp), "%04d%02d%02d-%02d%02d%02d-%03ld", tm.tm_year + 1900, tm.tm_mon + 1,
             tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, ts.tv_nsec / 1000000);
    snprintf(path, sizeof(path), "%s/%s.wav", g_save, stamp);
    write_wav(path, a, n);
    snprintf(path, sizeof(path), "%s/heard.tsv", g_save);
    FILE *f = fopen(path, "a");
    if (!f) return;
    fprintf(f, "%ld\t%s.wav\t%s\t%s\t", (long)ts.tv_sec, stamp, o->tag, h->n ? h->text[0] : "");
    for (int i = 1; i < h->n; i++) fprintf(f, "%s%s", i > 1 ? " | " : "", h->text[i]);
    fprintf(f, "\t%.0f\n", ms);
    fclose(f);
}

/* The room's floor: the 20th percentile of the last frames not taken for speech (3 s of them), in dB.  Too few
   yet, a quiet room's. */
#define FLOOR_FRAMES 100
static int cmp_float(const void *a, const void *b)
{
    float x = *(const float *)a, y = *(const float *)b;
    return x < y ? -1 : x > y;
}
static float room_floor(const float *db, int n)
{
    if (n < 5) return -70.0f;
    float s[FLOOR_FRAMES];
    memcpy(s, db, (size_t)n * sizeof(float));
    qsort(s, (size_t)n, sizeof(float), cmp_float);
    return s[n / 5];
}

/* DECODE of A with PAD ms of silence after it: a transducer emits the last word only once it has heard a little
   past it (FUTO pads 200 ms, Dictate 400). */
static int decode_padded(const float *a, int n, int pad, const HearContext *ctx, int beam, Heard *o)
{
    int z = pad * (RATE / 1000);
    if (z <= 0) return decode(a, n, ctx, beam, o);
    float *b = (float *)calloc((size_t)(n + z), sizeof(float));
    if (!b) return decode(a, n, ctx, beam, o);
    memcpy(b, a, (size_t)n * sizeof(float));
    int rc = decode(b, n + z, ctx, beam, o);
    free(b);
    return rc;
}

/* LISTEN: take audio until speech has started and then stopped, and say what was said. */
static void listen_stream(int fd, Opts *o)
{
    const HearContext *ctx = vocab(o->vocab, o->boost);
    int cap = RATE * (o->maxsec + 2), n = 0, done = 0;
    float *buf = (float *)malloc(cap * sizeof(float));
    unsigned char bytes[8192];
    int carry = -1;                                  /* a byte of a sample split across reads */
    Fvad *vad = fvad_new();
    if (vad && (fvad_set_sample_rate(vad, RATE) != 0 || fvad_set_mode(vad, o->vadmode) != 0)) { fvad_free(vad); vad = NULL; }
    int16_t frame16[VAD_FRAME];
    float quiet_db[FLOOR_FRAMES];                    /* recent frames not taken for speech, in dB */
    int quiet_n = 0, quiet_i = 0;
    float voice_db = 0;                              /* how loud the speaker is, once begun */
    int speech_run = 0, started = 0, start = 0, run_start = 0, last_loud = 0, analysed = 0;
    Heard spec = { 0 };
    int spec_end = -1, spec_from = 0;
    double last_partial = p25_now_sec(), t_end = 0;
    int tail = o->tail * (RATE / 1000);
    /* The guess made early is of the audio up to TAIL after the speech: it needs that much quiet. */
    int spec_ms = o->tail + 50 < o->hangover ? o->tail + 50 : o->hangover * 2 / 3;
    int eof = 0;
    const char *gone = NULL;                         /* why it stopped by the clock: idle, clock */
    double t_begin = p25_now_sec(), t_data = t_begin;

    while (!done) {
        struct pollfd p = { fd, POLLIN, 0 };
        int pr = poll(&p, 1, 100);
        if (pr < 0 && errno != EINTR) break;
        if (pr > 0) {
            ssize_t r = read(fd, bytes, sizeof(bytes));
            if (r < 0 && errno != EINTR) goto out;           /* reset: cancelled */
            if (r == 0) eof = 1;
            if (r > 0) t_data = p25_now_sec();
            for (ssize_t i = 0; i < r && n < cap; i++) {
                if (carry < 0) { carry = bytes[i]; continue; }
                short s = (short)(carry | (bytes[i] << 8));
                buf[n++] = s / 32768.0f;
                carry = -1;
            }
        }
        /* Where speech is: the voice detector, frame by frame.  Begun after five frames of speech running (150
           ms), or one clearly loud (as FUTO's: RMS over 0.01); the speech ends where its last frame does. */
        while (analysed + VAD_FRAME <= n) {
            const float *f = buf + analysed;
            double s2 = 0;
            for (int i = 0; i < VAD_FRAME; i++) {
                float x = f[i] * 32768.0f;
                frame16[i] = (int16_t)(x > 32767.0f ? 32767 : x < -32768.0f ? -32768 : x);
                s2 += (double)f[i] * f[i];
            }
            float rms = (float)sqrt(s2 / VAD_FRAME);
            float db = 10.0f * log10f((float)(s2 / VAD_FRAME) + 1e-12f);
            float floor_db = room_floor(quiet_db, quiet_n);
            /* Once begun, the bar is half way from the room to the speaker: a voice at -32 dBFS over a room at
               -57 isn't carried on by a keyboard's clicks at -48, and a quiet voice still gets a low bar. */
            float bar = floor_db + o->snr;
            if (started && (floor_db + voice_db) / 2 > bar) bar = (floor_db + voice_db) / 2;
            int speech = (vad ? fvad_process(vad, frame16, VAD_FRAME) == 1 : rms > 0.01f) && db >= bar;
            if (!speech && db > -90.0f) {               /* the room, as it is now; digital silence isn't it */
                quiet_db[quiet_i] = db;
                quiet_i = (quiet_i + 1) % FLOOR_FRAMES;
                if (quiet_n < FLOOR_FRAMES) quiet_n++;
            }
            analysed += VAD_FRAME;
            if (analysed <= IGNORE) continue;
            if (!speech) { speech_run = 0; continue; }
            if (speech_run++ == 0) { run_start = analysed - VAD_FRAME; if (!started) voice_db = db; }
            voice_db = started ? 0.95f * voice_db + 0.05f * db : (voice_db * (speech_run - 1) + db) / speech_run;
            /* Once begun, a frame or two of noise taken for speech is not the speaker going on: it takes a run
               of three (90 ms).  Else one cough or click in a noisy room keeps it listening. */
            if (!started || speech_run >= 3) last_loud = analysed;
            /* Begun after 150 ms of speech running, or a frame of it clearly loud (FUTO's RMS over 0.01): a
               short "no" is no more than that. */
            if (!started && (speech_run >= 5 || rms > 0.01f)) {
                started = 1;
                start = run_start - o->preroll * (RATE / 1000);
                if (start < 0) start = 0;
                if (say(fd, "START") != 0) goto out;
            }
        }
        /* Never held by a client: one that stops sending without closing is taken as done, and none goes on
           past its time (counted in samples above, which a stalled client never reaches). */
        if (!eof) {
            double now = p25_now_sec();
            if ((now - t_data) * 1000 >= IDLE_MS) gone = "idle";
            else if (now - t_begin >= o->maxsec + OVERRUN_S) gone = "clock";
            if (gone) eof = 1;
        }
        if (eof) break;
        if (n >= cap) break;
        if (!started) {
            if (n >= RATE / 1000 * o->nospeech) {
                say(fd, "END");
                say(fd, "NONE");
                Heard none = { 0 };
                save_utterance(o, buf, n, &none, 0);     /* the room as it was: what tuning for it learns from */
                goto out;
            }
            continue;
        }
        int quiet_ms = (n - last_loud) / (RATE / 1000);
        if (spec_end >= 0 && spec_end != last_loud) { heard_free(&spec); spec_end = -1; }   /* spoke again */
        if (quiet_ms >= spec_ms && spec_end < 0) {
            int end = last_loud + tail < n ? last_loud + tail : n;
            decode_padded(buf + start, end - start, o->pad, ctx, o->beam, &spec);
            spec_end = last_loud;
            spec_from = end;
        }
        if (quiet_ms >= o->hangover) { done = 1; break; }
        if (o->partial > 0 && quiet_ms < spec_ms && (p25_now_sec() - last_partial) * 1000 >= o->partial) {
            Heard part;
            decode(buf + start, n - start, ctx, o->beam, &part);
            if (part.n && part.text[0][0] && say(fd, "PARTIAL %s", part.text[0]) != 0) { heard_free(&part); goto out; }
            heard_free(&part);
            last_partial = p25_now_sec();
        }
    }

    t_end = p25_now_sec();
    if (say(fd, "END") != 0) goto out;
    {
        Heard h;
        int from = started ? start : 0, to;
        if (done && spec_end == last_loud) { h = spec; memset(&spec, 0, sizeof(spec)); to = spec_from; }
        else {
            to = started && !eof ? (last_loud + tail < n ? last_loud + tail : n) : n;
            decode_padded(buf + from, to - from, o->pad, ctx, o->beam, &h);
        }
        double wait = p25_now_sec() - t_end;
        /* Where it found speech, in the stream: what the tests measure end-pointing by. */
        say(fd, "INFO at start=%d speech_end=%d end=%d why=%s", started ? start * 1000 / RATE : -1,
            last_loud * 1000 / RATE, n * 1000 / RATE, done ? "quiet" : gone ? gone : eof ? "eof" : n >= cap ? "maxsec" : "?");
        reply_heard(fd, &h, (to - from) / (double)RATE, wait);
        save_utterance(o, buf + from, to - from, &h, wait * 1000);
        heard_free(&h);
    }
out:
    if (vad) fvad_free(vad);
    heard_free(&spec);
    free(buf);
}

static int read_audio_file(const char *path, float **a, int *n)
{
    float *raw;
    int count, rate, ch;
    if (p25_wav_read(path, &raw, &count, &rate, &ch) != 0) return -1;
    if (rate == RATE) { *a = raw; *n = count; return 0; }
    int rc = p25_resample(raw, count, rate, RATE, a, n);
    free(raw);
    return rc;
}

static void serve_one(int fd)
{
    char line[4096];
    int len = 0;
    double until = p25_now_sec() + LINE_MS / 1000.0;
    while (len < (int)sizeof(line) - 1) {               /* the request line, byte by byte: audio follows it */
        int left = (int)((until - p25_now_sec()) * 1000);
        struct pollfd p = { fd, POLLIN, 0 };
        if (left <= 0 || poll(&p, 1, left) <= 0) return;  /* connected and said nothing: not held by it */
        ssize_t r = read(fd, line + len, 1);
        if (r <= 0) return;
        if (line[len] == '\n') break;
        len++;
    }
    line[len] = 0;
    if (len && line[len - 1] == '\r') line[--len] = 0;
    char *rest = strchr(line, ' ');
    if (rest) *rest++ = 0; else rest = line + len;
    Opts o;
    if (!strcmp(line, "LISTEN")) {
        parse_opts(rest, &o);
        listen_stream(fd, &o);
    } else if (!strcmp(line, "FILE")) {
        char *sp = strchr(rest, ' ');
        if (sp) *sp++ = 0; else sp = rest + strlen(rest);
        char path[2048];
        snprintf(path, sizeof(path), "%s", rest);
        parse_opts(sp, &o);
        float *a;
        int n;
        if (read_audio_file(path, &a, &n) != 0) { say(fd, "ERROR cannot read %s", path); return; }
        const HearContext *ctx = vocab(o.vocab, o.boost);
        double t = p25_now_sec();
        Heard h;
        decode(a, n, ctx, o.beam, &h);
        reply_heard(fd, &h, n / (double)RATE, p25_now_sec() - t);
        heard_free(&h);
        free(a);
    } else if (!strcmp(line, "PING")) {
        parse_opts(rest, &o);
        say(fd, "PONG phonon-2.5 phrases=%d", hear_context_phrases(vocab(o.vocab, o.boost)));
    } else if (!strcmp(line, "QUIT")) {
        say(fd, "BYE");
        exit(0);
    } else say(fd, "ERROR unknown request");
}

/* ── Commands ─────────────────────────────────────────────────────────────── */

static int cmd_serve(const char *sock)
{
    signal(SIGPIPE, SIG_IGN);
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = { 0 };
    addr.sun_family = AF_UNIX;
    if (strlen(sock) >= sizeof(addr.sun_path)) { fprintf(stderr, "hear: socket path too long\n"); return 1; }
    strcpy(addr.sun_path, sock);
    unlink(sock);
    mode_t old = umask(077);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(s, 4) != 0) {
        perror("hear: bind");
        return 1;
    }
    umask(old);
    fprintf(stderr, "hear: listening on %s\n", sock);
    for (;;) {
        int c = accept(s, NULL, NULL);
        if (c < 0) { if (errno == EINTR) continue; perror("hear: accept"); return 1; }
        struct timeval tv = { 2, 0 };                   /* a client that doesn't read its answers: not held by it */
        setsockopt(c, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        serve_one(c);
        close(c);
    }
}

static int connect_to(const char *sock)
{
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = { 0 };
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", sock);
    if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) { perror("hear: connect"); return -1; }
    return s;
}

static void copy_out(int s)
{
    char b[4096];
    ssize_t r;
    while ((r = read(s, b, sizeof(b))) > 0) fwrite(b, 1, r, stdout);
    fflush(stdout);
}

static int cmd_client(const char *sock, int argc, char **argv)
{
    signal(SIGPIPE, SIG_IGN);
    int s = connect_to(sock);
    if (s < 0) return 1;
    char line[4096] = "LISTEN";
    for (int i = 0; i < argc; i++) { strncat(line, " ", sizeof(line) - strlen(line) - 1); strncat(line, argv[i], sizeof(line) - strlen(line) - 1); }
    strncat(line, "\n", sizeof(line) - strlen(line) - 1);
    if (write(s, line, strlen(line)) < 0) return 1;
    int sending = 1;
    char b[4096], acc[8192];
    int alen = 0;
    for (;;) {
        struct pollfd p[2] = { { s, POLLIN, 0 }, { 0, POLLIN, 0 } };
        if (poll(p, sending ? 2 : 1, -1) < 0) { if (errno == EINTR) continue; return 1; }
        if (p[0].revents) {
            ssize_t r = read(s, b, sizeof(b));
            if (r <= 0) break;
            fwrite(b, 1, r, stdout);
            fflush(stdout);
            for (ssize_t i = 0; i < r; i++) {               /* stop sending at END */
                if (b[i] == '\n') {
                    acc[alen] = 0;
                    if (!strcmp(acc, "END")) sending = 0;
                    alen = 0;
                } else if (alen < (int)sizeof(acc) - 1) acc[alen++] = b[i];
            }
        }
        if (sending && p[1].revents) {
            ssize_t r = read(0, b, sizeof(b));
            if (r <= 0) { shutdown(s, SHUT_WR); sending = 0; }
            else if (write(s, b, r) != r) sending = 0;
        }
    }
    return 0;
}

static int cmd_send(const char *sock, const char *req)
{
    int s = connect_to(sock);
    if (s < 0) return 1;
    char line[4096];
    snprintf(line, sizeof(line), "%s\n", req);
    if (write(s, line, strlen(line)) < 0) return 1;
    shutdown(s, SHUT_WR);
    copy_out(s);
    return 0;
}

static int options(int argc, char **argv, int i0, int *cache)
{
    int k = i0;
    for (int i = i0; i < argc; i++) {
        if (!strcmp(argv[i], "--vocab") && i + 1 < argc) snprintf(g_vocab, sizeof(g_vocab), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--save") && i + 1 < argc) snprintf(g_save, sizeof(g_save), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--beam") && i + 1 < argc) g_beam = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--boost") && i + 1 < argc) g_boost = (float)atof(argv[++i]);
        else if (!strcmp(argv[i], "--cache-codes")) *cache = 1;
        else argv[k++] = argv[i];
    }
    return k;
}

int main(int argc, char **argv)
{
    if (argc >= 3 && !strcmp(argv[1], "client")) return cmd_client(argv[2], argc - 3, argv + 3);
    if (argc == 4 && !strcmp(argv[1], "send")) return cmd_send(argv[2], argv[3]);
    int cache = 0;
    argc = options(argc, argv, 1, &cache);
    if (argc < 4 || (strcmp(argv[1], "serve") && strcmp(argv[1], "file"))) {
        fprintf(stderr, "usage: hear serve WEIGHTS SOCKET | hear file WEIGHTS AUDIO… [--vocab F,G] [--save DIR]"
                        " [--beam N] [--boost B] [--cache-codes]\n       hear client SOCKET [key=value…] | hear send SOCKET LINE\n");
        return 2;
    }
    p25_verbose = 0;
    double t = p25_now_sec();
    P25Engine *e = p25_engine_open(argv[2]);
    if (!e) return 1;
    if (cache) p25_cache_codes((P25Model *)p25_engine_model(e));
    engine = e;
    fprintf(stderr, "hear: model loaded in %.2f s\n", p25_now_sec() - t);
    if (!strcmp(argv[1], "serve")) return cmd_serve(argv[3]);

    const HearContext *ctx = vocab(g_vocab, g_boost);
    for (int i = 3; i < argc; i++) {
        float *a;
        int n;
        if (read_audio_file(argv[i], &a, &n) != 0) { fprintf(stderr, "hear: cannot read %s\n", argv[i]); continue; }
        Heard h;
        decode(a, n, ctx, g_beam, &h);
        printf("%s\t%s", argv[i], h.n ? h.text[0] : "");
        for (int j = 1; j < h.n; j++) printf("\t| %s", h.text[j]);
        printf("\t(%.0f+%.0f ms)\n", h.enc_s * 1000, h.dec_s * 1000);
        heard_free(&h);
        free(a);
    }
    return 0;
}

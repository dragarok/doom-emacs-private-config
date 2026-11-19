/*  bias.c – the context graph and the biased beam search (bias.h).
 *
 *  Beam search: frame-synchronous.  Every hypothesis sits at the encoder frame it has reached; the hypotheses at the
 *  lowest frame are merged (the same pieces by different alignments: log-add), cut to the beam, and each is expanded
 *  by blank and by its best pieces, each taking the duration head's best duration (blank at least 1).  So only
 *  hypotheses that have heard the same audio are ever compared.  A hypothesis's prediction-network step is run only
 *  when it survives to be expanded.
 */

#include "bias.h"
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ── Piece lookup ─────────────────────────────────────────────────────────── */

typedef struct { const char *s; int len, id; } Slot;
typedef struct { Slot *slots; int cap, maxlen; } PieceMap;

static uint64_t fnv(const char *s, int n)
{
    uint64_t h = 1469598103934665603ULL;
    for (int i = 0; i < n; i++) { h ^= (unsigned char)s[i]; h *= 1099511628211ULL; }
    return h;
}

static int special(const char *p, int n) { return n > 2 && p[0] == '<' && p[n - 1] == '>'; }

static int pm_init(PieceMap *pm, const P25Tokens *tok)
{
    pm->cap = 1 << 15;
    pm->maxlen = 0;
    pm->slots = (Slot *)calloc(pm->cap, sizeof(Slot));
    if (!pm->slots) return -1;
    for (int id = 0; id < P25_BLANK; id++) {
        const char *p = p25_tokens_piece(tok, id);
        if (!p || !*p) continue;
        int n = (int)strlen(p);
        if (special(p, n)) continue;
        int i = (int)(fnv(p, n) & (uint64_t)(pm->cap - 1));
        while (pm->slots[i].s && !(pm->slots[i].len == n && !memcmp(pm->slots[i].s, p, n)))
            i = (i + 1) & (pm->cap - 1);
        if (pm->slots[i].s) continue;          /* a duplicate piece: the first id wins */
        pm->slots[i] = (Slot){ p, n, id };
        if (n > pm->maxlen) pm->maxlen = n;
    }
    return 0;
}

static int pm_get(const PieceMap *pm, const char *s, int n)
{
    int i = (int)(fnv(s, n) & (uint64_t)(pm->cap - 1));
    while (pm->slots[i].s) {
        if (pm->slots[i].len == n && !memcmp(pm->slots[i].s, s, n)) return pm->slots[i].id;
        i = (i + 1) & (pm->cap - 1);
    }
    return -1;
}

/* ── Spellings: every way to cover a string with pieces in its fewest pieces, or one more ── */

#define MAX_SPELLINGS 8
#define MAX_PIECES    48
#define INF           (1 << 20)

typedef struct { int ids[MAX_PIECES]; int n; } Spelling;

static void spell_dfs(const PieceMap *pm, const char *s, int len, int pos, const int *minp, int budget,
                      int *cur, int ncur, Spelling *out, int *nout)
{
    if (*nout >= MAX_SPELLINGS) return;
    if (pos == len) {
        memcpy(out[*nout].ids, cur, ncur * sizeof(int));
        out[*nout].n = ncur;
        (*nout)++;
        return;
    }
    if (ncur >= MAX_PIECES) return;
    int top = pm->maxlen < len - pos ? pm->maxlen : len - pos;
    for (int l = top; l >= 1; l--) {          /* longest pieces first: the likeliest spelling comes first */
        int id = pm_get(pm, s + pos, l);
        if (id < 0) continue;
        int rest = pos + l < len ? minp[pos + l] : 0;
        if (rest >= INF || ncur + 1 + rest > budget) continue;
        cur[ncur] = id;
        spell_dfs(pm, s, len, pos + l, minp, budget, cur, ncur + 1, out, nout);
    }
}

static int spellings(const PieceMap *pm, const char *s, Spelling *out)
{
    int len = (int)strlen(s);
    if (len == 0) return 0;
    int *minp = (int *)malloc((len + 1) * sizeof(int));
    minp[len] = 0;
    for (int i = len - 1; i >= 0; i--) {
        minp[i] = INF;
        int top = pm->maxlen < len - i ? pm->maxlen : len - i;
        for (int l = 1; l <= top; l++)
            if (minp[i + l] < INF && pm_get(pm, s + i, l) >= 0 && minp[i + l] + 1 < minp[i])
                minp[i] = minp[i + l] + 1;
    }
    int n = 0, cur[MAX_PIECES];
    if (minp[0] < INF) spell_dfs(pm, s, len, 0, minp, minp[0] + 1, cur, 0, out, &n);
    free(minp);
    return n;
}

/* "Hades 2" → "▁Hades▁2": the pieces' own spelling of a phrase. */
static char *to_pieces_text(const char *phrase)
{
    size_t n = strlen(phrase);
    char *out = (char *)malloc(n * 3 + 4), *o = out;
    int word = 0;
    for (const char *p = phrase; *p; p++) {
        if (*p == ' ' || *p == '\t') { word = 0; continue; }
        if (!word) { memcpy(o, "\xe2\x96\x81", 3); o += 3; word = 1; }
        *o++ = *p;
    }
    *o = 0;
    return out;
}

/* ── The context graph ────────────────────────────────────────────────────── */

typedef struct {
    int   token, first_child, sibling, fail, output, is_end, phrase;
    float token_score, node_score, output_score;
    float bank;               /* of node_score, what is kept even if the phrase goes no further: a shorter phrase
                                 it passed through, or one it ends with */
} CNode;

struct HearContext {
    CNode *n;
    int    count, cap;
    int   *root_child;        /* [P25_VOCAB]: the root's child for each piece, 0 for none */
    int   *root_list, n_root; /* the root's children, for starting a phrase anywhere */
    int    n_phrases;
    float  depth_scale;
};

static int child(const HearContext *c, int node, int tok)
{
    if (node == 0) return c->root_child[tok];
    for (int k = c->n[node].first_child; k; k = c->n[k].sibling)
        if (c->n[k].token == tok) return k;
    return 0;
}

static int add_node(HearContext *c, int parent, int tok, float boost)
{
    if (c->count == c->cap) {
        c->cap *= 2;
        c->n = (CNode *)realloc(c->n, c->cap * sizeof(CNode));
    }
    int k = c->count++;
    CNode *v = &c->n[k];
    memset(v, 0, sizeof(*v));
    v->token = tok;
    v->phrase = -1;
    v->token_score = boost;
    v->node_score = c->n[parent].node_score + boost;
    if (parent == 0) {
        c->root_child[tok] = k;
        c->root_list[c->n_root++] = k;
    } else {
        v->sibling = c->n[parent].first_child;
        c->n[parent].first_child = k;
    }
    return k;
}

static void insert(HearContext *c, const Spelling *s, float boost, int phrase)
{
    int node = 0;
    for (int i = 0; i < s->n; i++) {
        int k = child(c, node, s->ids[i]);
        /* Deeper pieces pull harder (Moonshine's and NeMo's depth scaling): a phrase's first piece is cheap to
         * start, its later ones are what tell it apart. */
        float b = c->depth_scale > 0 ? boost * (1.0f + c->depth_scale * logf((float)(i + 1))) : boost;
        node = k ? k : add_node(c, node, s->ids[i], b);
    }
    c->n[node].is_end = 1;
    c->n[node].phrase = phrase;
}

/* Aho-Corasick fail and output links, breadth first. */
static void link(HearContext *c)
{
    int *queue = (int *)malloc(c->count * sizeof(int)), head = 0, tail = 0;
    for (int i = 0; i < c->n_root; i++) {
        int k = c->root_list[i];
        c->n[k].fail = 0;
        queue[tail++] = k;
    }
    while (head < tail) {
        int u = queue[head++];
        for (int v = c->n[u].first_child; v; v = c->n[v].sibling) {
            int tok = c->n[v].token, f = c->n[u].fail;
            while (f && !child(c, f, tok)) f = c->n[f].fail;
            int fv = child(c, f, tok);
            c->n[v].fail = (fv && fv != v) ? fv : 0;
            int fl = c->n[v].fail;
            c->n[v].output = c->n[fl].is_end ? fl : c->n[fl].output;
            queue[tail++] = v;
        }
    }
    for (int k = 1; k < c->count; k++) {
        CNode *v = &c->n[k];
        v->output_score = v->is_end ? v->node_score : (v->output ? c->n[v->output].node_score : 0.0f);
    }
    /* Banks, parents before children (the queue is breadth first). */
    for (int i = 0; i < tail; i++) {
        int u = queue[i];
        CNode *pu = &c->n[u];
        if (pu->is_end) pu->bank = pu->node_score;
        else if (pu->output && c->n[pu->output].node_score > pu->bank) pu->bank = c->n[pu->output].node_score;
        if (pu->bank > pu->node_score) pu->bank = pu->node_score;
        for (int v = pu->first_child; v; v = c->n[v].sibling) c->n[v].bank = pu->bank;
    }
    free(queue);
}

static void add_variant(char **seen, int *n_seen, const char *v)
{
    for (int i = 0; i < *n_seen; i++)
        if (!strcmp(seen[i], v)) return;
    seen[(*n_seen)++] = strdup(v);
}

HearContext *hear_context_build(const P25Tokens *tok, const char *text, float boost)
{
    if (!text) return NULL;
    PieceMap pm;
    if (pm_init(&pm, tok)) return NULL;
    HearContext *c = (HearContext *)calloc(1, sizeof(*c));
    c->cap = 1024;
    c->n = (CNode *)calloc(c->cap, sizeof(CNode));
    c->root_child = (int *)calloc(P25_VOCAB, sizeof(int));
    c->root_list = (int *)calloc(P25_VOCAB, sizeof(int));
    c->count = 1;                               /* node 0 is the root */
    const char *ds = getenv("HEAR_DEPTH_SCALE");
    c->depth_scale = ds ? (float)atof(ds) : 1.0f;
    c->n[0].token = -1;
    c->n[0].phrase = -1;

    const char *p = text;
    while (*p) {
        const char *eol = strchr(p, '\n');
        size_t len = eol ? (size_t)(eol - p) : strlen(p);
        char *line = (char *)malloc(len + 1);
        memcpy(line, p, len);
        line[len] = 0;
        p += len + (eol ? 1 : 0);

        while (len && (line[len - 1] == '\r' || line[len - 1] == ' ')) line[--len] = 0;
        float b = boost;
        char *tab = strchr(line, '\t');
        if (tab) { *tab = 0; b = (float)atof(tab + 1); if (b <= 0) b = boost; }
        char *s = line;
        while (*s == ' ') s++;
        if (!*s || *s == '#') { free(line); continue; }

        char *variants[3];
        int nv = 0;
        add_variant(variants, &nv, s);
        char *lower = strdup(s);
        for (char *q = lower; *q; q++) if (*q >= 'A' && *q <= 'Z') *q += 32;
        add_variant(variants, &nv, lower);
        char *cap = strdup(s);
        if (cap[0] >= 'a' && cap[0] <= 'z') cap[0] -= 32;
        add_variant(variants, &nv, cap);
        free(lower); free(cap);

        int spelled = 0;
        for (int i = 0; i < nv; i++) {
            char *pt = to_pieces_text(variants[i]);
            Spelling sp[MAX_SPELLINGS];
            int ns = spellings(&pm, pt, sp);
            for (int j = 0; j < ns; j++) insert(c, &sp[j], b, c->n_phrases);
            spelled += ns;
            free(pt);
            free(variants[i]);
        }
        if (spelled) c->n_phrases++;
        free(line);
    }
    free(pm.slots);
    if (!c->n_phrases) { hear_context_free(c); return NULL; }
    link(c);
    return c;
}

void hear_context_free(HearContext *c)
{
    if (!c) return;
    free(c->n); free(c->root_child); free(c->root_list); free(c);
}

int hear_context_phrases(const HearContext *c) { return c ? c->n_phrases : 0; }
int hear_context_nodes(const HearContext *c)   { return c ? c->count - 1 : 0; }

/* One piece through the graph (sherpa-onnx ContextGraph::ForwardOneStep): the bonus to add, and the next state.
 * Leaving a phrase unfinished takes back its bonus but what is banked; finishing one keeps it, and starts again at
 * the root unless a longer phrase goes on from there ("doom", then "doom ayu light": both your words). */
static float ctx_step(const HearContext *c, int state, int tok, int *next)
{
    int nd = child(c, state, tok);
    float score;
    if (nd) score = c->n[nd].token_score;
    else {
        int f = c->n[state].fail;
        while (f && !child(c, f, tok)) f = c->n[f].fail;
        nd = child(c, f, tok);
        score = c->n[nd].node_score - c->n[state].node_score + c->n[state].bank;
    }
    const CNode *v = &c->n[nd];
    if (nd && v->first_child) { *next = nd; return score; }
    if (nd && v->output_score != 0.0f) {
        float out = v->is_end ? v->node_score : c->n[v->output].node_score;
        *next = 0;
        return score + out - v->node_score;
    }
    *next = nd;
    return score + v->output_score;
}

/* The bonus TOKENS would keep: what a reading found without the graph would have been given on it. */
float hear_context_score(const HearContext *c, const P25Token *tokens, int n)
{
    if (!c) return 0.0f;
    int state = 0;
    float b = 0.0f;
    for (int i = 0; i < n; i++) b += ctx_step(c, state, tokens[i].id, &state);
    if (state) b -= c->n[state].node_score - c->n[state].bank;
    return b;
}

/* ── Beam search ──────────────────────────────────────────────────────────── */

static const int DURATIONS[P25_N_DURATIONS] = { 0, 1, 2, 3, 4 };

typedef struct {
    P25Token *toks;
    int       n, cap;
    double    am;            /* log-probability of the pieces, blanks and durations */
    float     bias;          /* bonus held */
    int       ctx, t, symbols;
    int       pending;       /* a piece whose prediction-network step is still due, or -1 */
    uint64_t  hash;
    LSTMState st;
    float     dec_out[P25_JOINT_DIM];
} Hyp;

static double total(const Hyp *h) { return h->am + h->bias; }

static Hyp *hyp_copy(const Hyp *h, int extra)
{
    Hyp *g = (Hyp *)malloc(sizeof(Hyp));
    *g = *h;
    g->cap = h->n + extra + 4;
    g->toks = (P25Token *)malloc(g->cap * sizeof(P25Token));
    if (h->n) memcpy(g->toks, h->toks, h->n * sizeof(P25Token));
    return g;
}

static void hyp_free(Hyp *h) { if (h) { free(h->toks); free(h); } }

static int same_pieces(const Hyp *a, const Hyp *b)
{
    if (a->hash != b->hash || a->n != b->n) return 0;
    for (int i = 0; i < a->n; i++) if (a->toks[i].id != b->toks[i].id) return 0;
    return 1;
}

static int by_total_desc(const void *x, const void *y)
{
    double a = total(*(Hyp *const *)x), b = total(*(Hyp *const *)y);
    return (a < b) - (a > b);
}

static void log_softmax(const float *x, int n, float *out)
{
    float mx = x[0];
    for (int i = 1; i < n; i++) if (x[i] > mx) mx = x[i];
    double s = 0;
    for (int i = 0; i < n; i++) s += exp((double)(x[i] - mx));
    float lse = mx + (float)log(s);
    for (int i = 0; i < n; i++) out[i] = x[i] - lse;
}

static double log_add(double a, double b)
{
    double m = a > b ? a : b;
    return m + log(exp(a - m) + exp(b - m));
}

typedef struct { Hyp **h; int n, cap; } List;

static void push(List *l, Hyp *h)
{
    if (l->n == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 64;
        l->h = (Hyp **)realloc(l->h, l->cap * sizeof(Hyp *));
    }
    l->h[l->n++] = h;
}

#define PRUNE_NATS 10.0     /* a piece this far below the best one at its step is not tried */

int hear_beam_decode(const P25Model *m, const float *enc, int T, const HearContext *ctx,
                     int beam, HearHyp *out, int max_n)
{
    if (beam < 1) beam = 1;
    float *logits = (float *)malloc(P25_N_LOGITS * sizeof(float));
    float *lp = (float *)malloc(P25_VOCAB * sizeof(float));
    float dlp[P25_N_DURATIONS];
    List pool = { 0 }, done = { 0 }, group = { 0 };

    Hyp *h0 = (Hyp *)calloc(1, sizeof(Hyp));
    h0->pending = -1;
    h0->hash = 1469598103934665603ULL;
    p25_decoder_step(m, P25_BLANK, &h0->st, h0->dec_out);
    push(&pool, h0);

    int *cand = (int *)malloc((beam + P25_VOCAB) * sizeof(int));
    unsigned char *tried = (unsigned char *)calloc(P25_VOCAB, 1);

    while (pool.n) {
        /* The hypotheses at the lowest frame. */
        int f = pool.h[0]->t;
        for (int i = 1; i < pool.n; i++) if (pool.h[i]->t < f) f = pool.h[i]->t;
        group.n = 0;
        int keep = 0;
        for (int i = 0; i < pool.n; i++) {
            if (pool.h[i]->t == f) push(&group, pool.h[i]);
            else pool.h[keep++] = pool.h[i];
        }
        pool.n = keep;

        /* Merge the same pieces reached by different alignments. */
        for (int i = 0; i < group.n; i++) {
            if (!group.h[i]) continue;
            for (int j = i + 1; j < group.n; j++) {
                if (!group.h[j] || !same_pieces(group.h[i], group.h[j])) continue;
                Hyp *a = group.h[i], *b = group.h[j];
                if (total(b) > total(a)) { Hyp *x = a; a = b; b = x; group.h[i] = a; }
                a->am = log_add(a->am, b->am);
                hyp_free(b);
                group.h[j] = NULL;
            }
        }
        keep = 0;
        for (int i = 0; i < group.n; i++) if (group.h[i]) group.h[keep++] = group.h[i];
        group.n = keep;
        qsort(group.h, group.n, sizeof(Hyp *), by_total_desc);
        for (int i = beam; i < group.n; i++) hyp_free(group.h[i]);
        if (group.n > beam) group.n = beam;

        for (int gi = 0; gi < group.n; gi++) {
            Hyp *h = group.h[gi];
            if (h->pending >= 0) {
                p25_decoder_step(m, h->pending, &h->st, h->dec_out);
                h->pending = -1;
            }
            p25_joint(m, enc + (size_t)f * P25_JOINT_DIM, h->dec_out, logits);
            log_softmax(logits, P25_VOCAB, lp);
            log_softmax(logits + P25_VOCAB, P25_N_DURATIONS, dlp);
            int dbest = 0;
            for (int d = 1; d < P25_N_DURATIONS; d++) if (dlp[d] > dlp[dbest]) dbest = d;
            int dur = DURATIONS[dbest];

            /* Blank: the same pieces, further on. */
            Hyp *b = hyp_copy(h, 0);
            b->am += lp[P25_BLANK] + dlp[dbest];
            b->t = f + (dur ? dur : 1);
            b->symbols = 0;
            push(b->t >= T ? &done : &pool, b);

            /* Pieces: the best few, and those that would carry a phrase on or start one. */
            int nc = 0;
            float best = -1e30f;
            for (int k = 0; k < P25_BLANK; k++) if (lp[k] > best) best = lp[k];
            for (int r = 0; r < beam; r++) {
                int arg = -1;
                for (int k = 0; k < P25_BLANK; k++)
                    if (!tried[k] && (arg < 0 || lp[k] > lp[arg])) arg = k;
                if (arg < 0 || lp[arg] < best - PRUNE_NATS) break;
                tried[arg] = 1;
                cand[nc++] = arg;
            }
            if (ctx) {
                if (h->ctx)
                    for (int v = ctx->n[h->ctx].first_child; v; v = ctx->n[v].sibling) {
                        int k = ctx->n[v].token;
                        if (!tried[k] && lp[k] >= best - PRUNE_NATS) { tried[k] = 1; cand[nc++] = k; }
                    }
                for (int i = 0; i < ctx->n_root; i++) {
                    int k = ctx->n[ctx->root_list[i]].token;
                    if (!tried[k] && lp[k] >= best - PRUNE_NATS) { tried[k] = 1; cand[nc++] = k; }
                }
            }
            for (int i = 0; i < nc; i++) {
                int k = cand[i];
                tried[k] = 0;
                Hyp *g = hyp_copy(h, 1);
                int d = dur;
                if (d == 0 && h->symbols + 1 >= P25_MAX_SYMBOLS) d = 1;
                g->toks[g->n++] = (P25Token){ k, f, d };
                g->am += lp[k] + dlp[dbest];
                if (ctx) g->bias += ctx_step(ctx, h->ctx, k, &g->ctx);
                g->hash = (g->hash ^ (uint64_t)(k + 1)) * 1099511628211ULL;
                g->t = f + d;
                g->symbols = d == 0 ? h->symbols + 1 : 0;
                g->pending = k;
                push(g->t >= T ? &done : &pool, g);
            }
            hyp_free(h);
        }
        group.n = 0;

        /* Finished ones: an unfinished phrase gives its bonus back; keep the best few. */
        if (done.n > 4 * beam) {
            qsort(done.h, done.n, sizeof(Hyp *), by_total_desc);
            for (int i = 4 * beam; i < done.n; i++) hyp_free(done.h[i]);
            done.n = 4 * beam;
        }
    }

    for (int i = 0; i < done.n; i++) {
        Hyp *h = done.h[i];
        if (ctx && h->ctx) { h->bias -= ctx->n[h->ctx].node_score - ctx->n[h->ctx].bank; h->ctx = 0; }
    }
    /* Merge finished duplicates, then the best distinct ones out. */
    for (int i = 0; i < done.n; i++) {
        if (!done.h[i]) continue;
        for (int j = i + 1; j < done.n; j++) {
            if (!done.h[j] || !same_pieces(done.h[i], done.h[j])) continue;
            if (total(done.h[j]) > total(done.h[i])) { Hyp *x = done.h[i]; done.h[i] = done.h[j]; done.h[j] = x; }
            done.h[i]->am = log_add(done.h[i]->am, done.h[j]->am);
            hyp_free(done.h[j]);
            done.h[j] = NULL;
        }
    }
    int keep = 0;
    for (int i = 0; i < done.n; i++) if (done.h[i]) done.h[keep++] = done.h[i];
    done.n = keep;
    qsort(done.h, done.n, sizeof(Hyp *), by_total_desc);
    int n_out = 0;
    for (int i = 0; i < done.n; i++) {
        Hyp *h = done.h[i];
        if (n_out < max_n) {
            out[n_out].tokens = h->toks;
            out[n_out].n = h->n;
            out[n_out].score = (float)total(h);
            out[n_out].am = (float)h->am;
            n_out++;
            free(h);
        } else hyp_free(h);
    }
    free(pool.h); free(done.h); free(group.h);
    free(cand); free(tried); free(logits); free(lp);
    return n_out;
}

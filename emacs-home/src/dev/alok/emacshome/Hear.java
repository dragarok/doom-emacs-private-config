package dev.alok.emacshome;

import android.content.Context;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.util.Log;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * One utterance: the microphone, streamed to the speech engine (hear, in
 * Termux, the model kept loaded) over its Unix socket, and its answers back.
 * The engine finds where speech starts and stops; finish() stops now (a
 * tap, the island let go), cancel() drops it all.  If the engine isn't up,
 * Emacs is asked to start it and the audio is kept meanwhile, so nothing
 * said is lost.
 *
 * What makes it safe to leave alone:
 *  - The microphone has a thread of its own that only reads it and hands the
 *    audio on.  It never waits on the engine, Emacs or the socket, so nothing
 *    they do can keep the microphone open: it stops at MAX, a tap, the
 *    engine's END, any answer, or never mind.  (It once wrote to the socket
 *    itself: an engine that stopped reading filled the socket, the write
 *    blocked, and the microphone stayed on for a quarter of an hour.)
 *  - Should that thread get stuck anyway, the microphone is taken back from
 *    it GRACE after MAX; never mind takes it back at once.
 *  - Every utterance ends in exactly one of heard, nothing or failed (or, when
 *    cancelled, none), within ANSWER_WAIT of the audio ending (ENGINE_WAIT
 *    more while the engine is still starting).  Whatever ends it shuts the
 *    socket, so the engine is never left waiting on a connection nobody uses
 *    and no thread stays blocked on it.
 *  - One recording at a time: a new one waits for the last to let go.
 *
 * Listener calls come on this object's own threads.
 */
final class Hear {
    interface Listener {
        void level(float level);                 // 0..1, every 20 ms
        void waiting();                          // the engine isn't up: Emacs is starting it, the audio kept
        void speech();                           // speech began
        void partial(String words);
        void end();                              // stopped listening, deciding
        void heard(String text, List<String> alternatives);
        void nothing();
        void failed(String why);                 // microphone, muted, engine
    }

    static final File SOCKET = new File(Catalog.DIR, "hear.sock");
    private static final String TAG = "EmacsHome";
    private static final int RATE = 16000, FRAME = 320;          // 20 ms reads: a tap is heard within 20 ms
    private static final Semaphore MIC = new Semaphore(1);
    private static final ScheduledExecutorService WATCH = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "hear-watch");
        t.setDaemon(true);
        return t;
    });
    private static final byte[] AUDIO_END = new byte[0];  // in the queue: the audio has ended
    private static final long DRAIN = 250;          // after a tap or letting go: the last syllable (FUTO: 300)
    private static final long ENGINE_WAIT = 12_000; // for Emacs to start the engine
    private static final long ANSWER_WAIT = 8_000;  // for the answer, once the audio has ended
    private static final long GRACE = 1_500;        // past MAX by this, the microphone is taken back
    private static final long DEAD_MIC = 600;       // reads failing this long: the microphone is gone
    private static final long MUTED = 2_500;        // nothing but zeros this long: the microphone is off

    private final Context context;
    private final String request;
    private final long max;
    private final Listener out;
    private volatile boolean finishing, cancelled, ended;
    private volatile LocalSocket socket;
    private volatile AudioRecord rec;
    private final AtomicBoolean over = new AtomicBoolean(), endSaid = new AtomicBoolean(),
                                micHeld = new AtomicBoolean();
    private final CountDownLatch answered = new CountDownLatch(1);
    private final LinkedBlockingQueue<byte[]> audio = new LinkedBlockingQueue<>();

    /** OPTIONS for the engine's LISTEN; at most MAXMS of recording. */
    Hear(Context c, String options, long maxMs, Listener listener) {
        context = c.getApplicationContext();
        request = "LISTEN " + options + "\n";
        max = maxMs;
        out = listener;
    }

    void start() {
        new Thread(this::record, "hear-mic").start();
        new Thread(this::stream, "hear").start();
        // The last word, whatever else happens: the microphone off and an answer given.
        WATCH.schedule(() -> {
            if (micHeld.get()) { Log.w(TAG, "hear: microphone still held at the end: taken back"); letGoSoon(); }
            late();
        }, 1_500 + max + GRACE + ENGINE_WAIT + ANSWER_WAIT, TimeUnit.MILLISECONDS);
    }

    /** Done speaking: decode what there is now. */
    void finish() { finishing = true; }

    /** Never mind: nothing is decoded or done, and the microphone goes now. */
    void cancel() {
        cancelled = true;
        closeSocket();
        letGoSoon();
        answered.countDown();
    }

    boolean done() { return over.get() || cancelled; }

    private void end() { if (endSaid.compareAndSet(false, true)) out.end(); }

    /** The one answer: the first of these to come, unless cancelled.  It ends
     *  the utterance: the socket shut, the microphone let go. */
    private void answer(String text, List<String> alts, String failure) {
        if (!cancelled && over.compareAndSet(false, true)) {
            end();
            if (failure != null) out.failed(failure);
            else if (text == null || text.trim().isEmpty()) out.nothing();
            else out.heard(text.trim(), alts);
        }
        over.set(true);
        closeSocket();
        letGoSoon();
        answered.countDown();
    }

    /** No answer in time: the engine has it wrong, or is stuck. */
    private void late() {
        if (over.get() || cancelled) return;
        Log.w(TAG, "hear: no answer in time");
        answer(null, null, "engine");
    }

    /** Shut both ways first: a thread blocked reading or writing it wakes (a
     *  plain close leaves it blocked), and the engine sees the end. */
    private void closeSocket() {
        LocalSocket s = socket;
        if (s == null) return;
        try { s.shutdownInput(); } catch (Exception e) { /* not connected */ }
        try { s.shutdownOutput(); } catch (Exception e) { /* not connected */ }
        try { s.close(); } catch (Exception e) { /* closed */ }
    }

    /** The microphone stopped and released, and the next recording let in: once. */
    private void letGo() {
        if (!micHeld.compareAndSet(true, false)) return;
        AudioRecord r = rec;
        rec = null;
        if (r != null) {
            try { r.stop(); } catch (Exception e) { /* stopped */ }      // wakes a read blocked on it
            try { r.release(); } catch (Exception e) { /* released */ }
        }
        MIC.release();
    }

    /** letGo off the caller's thread: it talks to the audio server, which the
     *  island's thread and the watchdog must never wait on. */
    private void letGoSoon() {
        if (micHeld.get()) new Thread(this::letGo, "hear-letgo").start();
    }

    private static AudioRecord open() throws InterruptedException {
        int min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
        // A microphone just let go of can take a moment: five tries, 120 ms apart (Dictate's).
        for (int i = 0; i < 5; i++) {
            AudioRecord r = null;
            try {
                r = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE,
                                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                                    Math.max(min, RATE * 2));
                if (r.getState() == AudioRecord.STATE_INITIALIZED) {
                    r.startRecording();
                    if (r.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) return r;
                }
            } catch (Exception e) {
                Log.w(TAG, "hear: microphone, try " + (i + 1), e);
            }
            if (r != null) try { r.release(); } catch (Exception e) { /* gone */ }
            Thread.sleep(120);
        }
        return null;
    }

    /** The microphone's thread: read it, hand the audio on, nothing else. */
    private void record() {
        try {
            if (!MIC.tryAcquire(1500, TimeUnit.MILLISECONDS)) { answer(null, null, "microphone"); return; }
            micHeld.set(true);
            if (cancelled || over.get()) return;
            AudioRecord r = open();
            if (r == null) { answer(null, null, "microphone"); return; }
            rec = r;
            if (!micHeld.get()) {                        // taken back while it opened
                try { r.stop(); r.release(); } catch (Exception e) { /* gone */ }
                return;
            }
            WATCH.schedule(() -> {
                if (micHeld.get()) { Log.w(TAG, "hear: microphone past " + max + " ms: taken back"); letGoSoon(); }
            }, max + GRACE, TimeUnit.MILLISECONDS);
            short[] pcm = new short[FRAME];
            long t0 = System.currentTimeMillis(), finishAt = 0, failingSince = 0;
            boolean heardAnything = false;
            while (!cancelled && !ended && !over.get() && micHeld.get()) {
                long now = System.currentTimeMillis();
                if (finishing && finishAt == 0) finishAt = now;
                if (finishAt > 0 && now - finishAt >= DRAIN) break;
                if (now - t0 >= max) { Log.i(TAG, "hear: " + max + " ms, the most"); break; }
                int n = r.read(pcm, 0, FRAME);
                if (n <= 0) {
                    if (failingSince == 0) failingSince = now;
                    if (now - failingSince > DEAD_MIC) { Log.w(TAG, "hear: read " + n); break; }
                    Thread.sleep(20);
                    continue;
                }
                failingSince = 0;
                byte[] bytes = new byte[n * 2];
                double sum = 0;
                for (int i = 0; i < n; i++) {
                    if (pcm[i] != 0) heardAnything = true;
                    sum += (double) pcm[i] * pcm[i];
                    bytes[2 * i] = (byte) pcm[i];
                    bytes[2 * i + 1] = (byte) (pcm[i] >> 8);
                }
                if (!heardAnything && now - t0 > MUTED) { answer(null, null, "muted"); return; }
                double db = 10 * Math.log10(sum / n / (32768.0 * 32768.0) + 1e-10);
                out.level((float) Math.max(0, Math.min(1, (db + 62) / 48)));
                audio.add(bytes);
            }
        } catch (InterruptedException e) {
            answer(null, null, "microphone");
        } catch (Exception e) {
            Log.w(TAG, "hear", e);
        } finally {
            // Listening is over, whatever happens next: the microphone goes now.
            letGo();
            audio.add(AUDIO_END);
        }
        if (cancelled || over.get()) return;
        end();
        WATCH.schedule(this::late, ANSWER_WAIT + (socket == null ? ENGINE_WAIT : 0), TimeUnit.MILLISECONDS);
    }

    /** The next piece of audio, AUDIO_END once it has ended, null once the utterance is over. */
    private byte[] next() throws InterruptedException {
        for (;;) {
            if (cancelled || over.get()) return null;
            byte[] b = audio.poll(100, TimeUnit.MILLISECONDS);
            if (b != null) return b;
        }
    }

    /** The engine's thread: the audio to it as it comes.  A write here may wait
     *  on the engine; nothing else does. */
    private void stream() {
        try {
            byte[] b = next();                           // connect once there is audio to send
            if (b == null || b == AUDIO_END) return;     // never began: what ended it answered
            long t0 = System.currentTimeMillis();
            OutputStream sink = connect();
            if (sink == null) {
                // Not up: Emacs starts it, and the audio waits in the queue meanwhile.
                out.waiting();
                new Thread(() -> Emacs.eval(context, "(voice-engine-start)"), "hear-start").start();
                while (sink == null) {
                    if (cancelled || over.get()) return;
                    if (System.currentTimeMillis() - t0 > ENGINE_WAIT) { answer(null, null, "engine"); return; }
                    Thread.sleep(150);
                    sink = connect();
                }
            }
            boolean writing = true;
            for (; b != AUDIO_END; b = next()) {
                if (b == null) return;                   // over: its answer shut the socket
                if (!writing || ended) continue;         // the engine has what it needs
                try { sink.write(b); }
                catch (Exception e) { writing = false; } // it stopped reading: its answer says why
            }
            // The audio has ended: the engine decodes what it has.  The answer
            // comes on the reader; late() if it doesn't.
            LocalSocket s = socket;
            if (writing && !ended && s != null) try { s.shutdownOutput(); } catch (Exception e) { /* it has ended */ }
        } catch (InterruptedException e) {
            answer(null, null, "engine");
        }
    }

    /** The socket, the request sent and the reader started; null when the engine isn't there. */
    private OutputStream connect() {
        LocalSocket s = new LocalSocket();
        try {
            s.connect(new LocalSocketAddress(SOCKET.getPath(), LocalSocketAddress.Namespace.FILESYSTEM));
            OutputStream o = s.getOutputStream();
            o.write(request.getBytes(StandardCharsets.UTF_8));
            socket = s;
            if (cancelled || over.get()) { closeSocket(); return null; }
            new Thread(() -> read(s), "hear-replies").start();
            return o;
        } catch (Exception e) {
            try { s.close(); } catch (Exception x) { /* closed */ }
            return null;
        }
    }

    private void read(LocalSocket s) {
        String text = null;
        List<String> alts = new ArrayList<>();
        try (BufferedReader in = new BufferedReader(
                new InputStreamReader(s.getInputStream(), StandardCharsets.UTF_8))) {
            for (String line; (line = in.readLine()) != null; ) {
                if (cancelled || over.get()) return;
                int sp = line.indexOf(' ');
                String kind = sp < 0 ? line : line.substring(0, sp), rest = sp < 0 ? "" : line.substring(sp + 1);
                switch (kind) {
                    case "START": out.speech(); break;
                    case "PARTIAL": out.partial(rest); break;
                    case "END": ended = true; end(); break;
                    case "TEXT": text = rest; break;
                    case "ALT": alts.add(rest); break;
                    case "NONE": text = ""; break;
                    case "INFO": Log.i(TAG, "hear " + rest); break;
                    default: break;
                }
            }
        } catch (Exception e) {
            /* shut: by the engine, or by whatever ended this */
        } finally {
            ended = true;
        }
        answer(text, alts, text == null ? "engine" : null);
    }
}

package dev.alok.emacshome;

import android.content.Context;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.net.LocalSocket;
import android.net.LocalSocketAddress;
import android.util.Log;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
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
 * What makes it safe to leave alone: it records at most MAX ms; the
 * microphone is released the moment listening ends, on every path; and
 * every utterance ends in exactly one of heard, nothing or failed (or, when
 * cancelled, none), within ANSWER_WAIT of the audio ending.  One recording
 * at a time: a new one waits for the last one to let go of the microphone.
 *
 * Every listener call comes on this object's own threads.
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
    private static final int RATE = 16000, FRAME = 320;          // 20 ms reads: a tap is heard within 20 ms
    private static final Semaphore MIC = new Semaphore(1);
    private static final long DRAIN = 250;          // after a tap or letting go: the last syllable (FUTO: 300)
    private static final long ENGINE_WAIT = 12_000; // for Emacs to start the engine
    private static final long ANSWER_WAIT = 8_000;  // for the answer, once the audio has ended
    private static final long DEAD_MIC = 600;       // reads failing this long: the microphone is gone
    private static final long MUTED = 2_500;        // nothing but zeros this long: the microphone is off

    private final Context context;
    private final String request;
    private final long max;
    private final Listener out;
    private volatile boolean finishing, cancelled, ended;
    private volatile LocalSocket socket;
    private final AtomicBoolean over = new AtomicBoolean(), endSaid = new AtomicBoolean();
    private final CountDownLatch answered = new CountDownLatch(1);

    /** OPTIONS for the engine's LISTEN; at most MAXMS of recording. */
    Hear(Context c, String options, long maxMs, Listener listener) {
        context = c.getApplicationContext();
        request = "LISTEN " + options + "\n";
        max = maxMs;
        out = listener;
    }

    void start() { new Thread(this::run, "hear").start(); }

    /** Done speaking: decode what there is now. */
    void finish() { finishing = true; }

    /** Never mind: nothing is decoded or done. */
    void cancel() {
        cancelled = true;
        LocalSocket s = socket;
        if (s != null) try { s.close(); } catch (Exception e) { /* closed */ }
        answered.countDown();
    }

    boolean done() { return over.get() || cancelled; }

    private void end() { if (endSaid.compareAndSet(false, true)) out.end(); }

    /** The one answer: the first of these to come, unless cancelled. */
    private void answer(String text, List<String> alts, String failure) {
        if (cancelled || !over.compareAndSet(false, true)) return;
        end();
        if (failure != null) out.failed(failure);
        else if (text == null || text.trim().isEmpty()) out.nothing();
        else out.heard(text.trim(), alts);
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
                Log.w("EmacsHome", "hear: microphone, try " + (i + 1), e);
            }
            if (r != null) try { r.release(); } catch (Exception e) { /* gone */ }
            Thread.sleep(120);
        }
        return null;
    }

    private void run() {
        boolean haveMic = false;
        AudioRecord rec = null;
        OutputStream sink = null;
        ByteArrayOutputStream early = new ByteArrayOutputStream();
        try {
            haveMic = MIC.tryAcquire(1500, TimeUnit.MILLISECONDS);
            if (!haveMic || cancelled) { if (!cancelled) answer(null, null, "microphone"); return; }
            rec = open();
            if (rec == null) { answer(null, null, "microphone"); return; }
            short[] pcm = new short[FRAME];
            byte[] bytes = new byte[FRAME * 2];
            long t0 = System.currentTimeMillis(), finishAt = 0, failingSince = 0, lastTry = 0;
            boolean askedEmacs = false, heardAnything = false;
            while (!cancelled && !ended) {
                long now = System.currentTimeMillis();
                if (finishing && finishAt == 0) finishAt = now;
                if (finishAt > 0 && now - finishAt >= DRAIN) break;
                if (now - t0 >= max) { Log.i("EmacsHome", "hear: " + max + " ms, the most"); break; }
                int n = rec.read(pcm, 0, FRAME);
                if (n <= 0) {
                    if (failingSince == 0) failingSince = now;
                    if (now - failingSince > DEAD_MIC) { Log.w("EmacsHome", "hear: read " + n); break; }
                    Thread.sleep(20);
                    continue;
                }
                failingSince = 0;
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
                if (sink == null) {
                    // Not connected yet: keep it, and try again (Emacs starts the engine).
                    early.write(bytes, 0, n * 2);
                    if (now - lastTry >= 100) { lastTry = now; sink = connect(); }
                    if (sink == null) {
                        if (!askedEmacs && now - t0 > 150) {
                            askedEmacs = true;
                            out.waiting();
                            new Thread(() -> Emacs.eval(context, "(voice-engine-start)")).start();
                        }
                        if (now - t0 > ENGINE_WAIT) { answer(null, null, "engine"); return; }
                        continue;
                    }
                    sink.write(early.toByteArray());
                    early.reset();
                } else {
                    try { sink.write(bytes, 0, n * 2); }
                    catch (Exception e) { break; }      // the engine stopped reading: its answer says why
                }
            }
        } catch (InterruptedException e) {
            answer(null, null, "microphone");
            return;
        } catch (Exception e) {
            Log.w("EmacsHome", "hear", e);
        } finally {
            // Listening is over, whatever happens next: the microphone goes now.
            if (rec != null) {
                try { rec.stop(); } catch (Exception e) { /* stopped */ }
                try { rec.release(); } catch (Exception e) { /* released */ }
            }
            if (haveMic) MIC.release();
        }
        if (cancelled || over.get()) return;
        end();
        try {
            // Tapped before the engine was up: what was said goes to it once it is.
            long until = System.currentTimeMillis() + ENGINE_WAIT;
            while (sink == null && !cancelled && System.currentTimeMillis() < until) {
                sink = connect();
                if (sink == null) Thread.sleep(150);
                else { sink.write(early.toByteArray()); early.reset(); }
            }
            if (cancelled) return;
            if (sink == null) { answer(null, null, "engine"); return; }
            LocalSocket s = socket;
            if (!ended && s != null) try { s.shutdownOutput(); } catch (Exception e) { /* it has ended */ }
            if (!answered.await(ANSWER_WAIT, TimeUnit.MILLISECONDS)) {
                Log.w("EmacsHome", "hear: no answer in " + ANSWER_WAIT + " ms");
                if (s != null) try { s.close(); } catch (Exception e) { /* closed */ }
                answer(null, null, "engine");
            }
        } catch (Exception e) {
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
            if (cancelled) { s.close(); return null; }
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
                if (cancelled) return;
                int sp = line.indexOf(' ');
                String kind = sp < 0 ? line : line.substring(0, sp), rest = sp < 0 ? "" : line.substring(sp + 1);
                switch (kind) {
                    case "START": out.speech(); break;
                    case "PARTIAL": out.partial(rest); break;
                    case "END": ended = true; end(); break;
                    case "TEXT": text = rest; break;
                    case "ALT": alts.add(rest); break;
                    case "NONE": text = ""; break;
                    case "INFO": Log.i("EmacsHome", "hear " + rest); break;
                    default: break;
                }
            }
        } catch (Exception e) {
            if (cancelled) return;
        } finally {
            try { s.close(); } catch (Exception e) { /* closed */ }
            ended = true;
        }
        answer(text, alts, text == null ? "engine" : null);
        answered.countDown();
    }
}

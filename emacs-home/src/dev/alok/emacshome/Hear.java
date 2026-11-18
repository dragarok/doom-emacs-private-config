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

/**
 * One utterance: the microphone, streamed to the speech engine (hear, in
 * Termux, the model kept loaded) over its Unix socket, and its answers back.
 * The engine finds where speech starts and stops; finish() stops at once
 * (the island let go), cancel() drops it all.  If the engine isn't up,
 * Emacs is asked to start it, the audio kept meanwhile, so nothing said is
 * lost; if it can't be reached at all, failed("engine") and the caller
 * falls back to the voice app.
 *
 * Every listener call comes on this object's own threads.
 */
final class Hear {
    interface Listener {
        void level(float level);                 // 0..1, every 20 ms
        void speech();                           // speech began
        void partial(String words);
        void end();                              // stopped listening, deciding
        void heard(String text, List<String> alternatives);
        void nothing();
        void failed(String why);
    }

    static final File SOCKET = new File(Catalog.DIR, "hear.sock");
    private static final int RATE = 16000, FRAME = 320;

    private final Context context;
    private final String request;
    private final Listener out;
    private volatile boolean finishing, cancelled, ended, answered;
    private volatile LocalSocket socket;

    Hear(Context c, String options, Listener listener) {
        context = c.getApplicationContext();
        request = "LISTEN " + options + "\n";
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
    }

    boolean done() { return answered || cancelled; }

    private void run() {
        AudioRecord rec;
        try {
            int min = AudioRecord.getMinBufferSize(RATE, AudioFormat.CHANNEL_IN_MONO,
                                                   AudioFormat.ENCODING_PCM_16BIT);
            rec = new AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, RATE,
                                  AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                                  Math.max(min, RATE * 2 / 2));
            if (rec.getState() != AudioRecord.STATE_INITIALIZED) throw new IllegalStateException("not initialised");
            rec.startRecording();
        } catch (Exception e) {
            Log.w("EmacsHome", "hear: microphone", e);
            out.failed("microphone");
            return;
        }
        short[] pcm = new short[FRAME];
        byte[] bytes = new byte[FRAME * 2];
        ByteArrayOutputStream early = new ByteArrayOutputStream();
        OutputStream sink = null;
        long t0 = System.currentTimeMillis();
        boolean askedEmacs = false;
        try {
            while (!cancelled && !ended) {
                int n = rec.read(pcm, 0, FRAME);
                if (n <= 0) continue;
                double sum = 0;
                for (int i = 0; i < n; i++) {
                    sum += (double) pcm[i] * pcm[i];
                    bytes[2 * i] = (byte) pcm[i];
                    bytes[2 * i + 1] = (byte) (pcm[i] >> 8);
                }
                double db = 10 * Math.log10(sum / n / (32768.0 * 32768.0) + 1e-10);
                out.level((float) Math.max(0, Math.min(1, (db + 62) / 48)));
                if (sink == null) {
                    // Not connected yet: keep it, and try again (Emacs starts the engine).
                    early.write(bytes, 0, n * 2);
                    sink = connect();
                    if (sink == null) {
                        long waited = System.currentTimeMillis() - t0;
                        if (!askedEmacs && waited > 150) {
                            askedEmacs = true;
                            new Thread(() -> Emacs.eval(context, "(voice-engine-start)")).start();
                        }
                        if (waited > 6000) { out.failed("engine"); return; }
                        continue;
                    }
                    sink.write(early.toByteArray());
                    early = null;
                } else sink.write(bytes, 0, n * 2);
                if (finishing) break;
            }
            if (sink != null && !cancelled && !ended) socket.shutdownOutput();
        } catch (Exception e) {
            if (!cancelled && !ended) {
                Log.w("EmacsHome", "hear", e);
                out.failed("engine");
            }
        } finally {
            try { rec.stop(); } catch (Exception e) { /* stopped */ }
            rec.release();
        }
    }

    /** The socket, the request sent and the reader started; null when the engine isn't there. */
    private OutputStream connect() {
        try {
            LocalSocket s = new LocalSocket();
            s.connect(new LocalSocketAddress(SOCKET.getPath(), LocalSocketAddress.Namespace.FILESYSTEM));
            OutputStream o = s.getOutputStream();
            o.write(request.getBytes(StandardCharsets.UTF_8));
            socket = s;
            new Thread(() -> read(s), "hear-replies").start();
            return o;
        } catch (Exception e) {
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
                    case "END": ended = true; out.end(); break;
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
        }
        if (cancelled) return;
        answered = true;
        if (!ended) { ended = true; out.end(); }
        if (text == null) out.failed("engine");
        else if (text.trim().isEmpty()) out.nothing();
        else out.heard(text.trim(), alts);
    }
}

package dev.alok.emacshome;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.view.View;

/**
 * The island's voice, drawn: five bars that breathe while it waits, follow
 * your voice while it hears you, run as a wave while it thinks, and stand
 * still when it's done.  Driven by level() from the microphone thread;
 * drawn on the display's own frames.
 */
final class VoiceBars extends View {
    enum Mode { WAITING, HEARING, THINKING, DONE }

    private static final float[] SHAPE = { 0.55f, 0.82f, 1f, 0.82f, 0.55f };
    private final float[] h = new float[SHAPE.length];
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF r = new RectF();
    private volatile float level;
    private float smooth;
    private Mode mode = Mode.WAITING;
    private final long t0 = System.nanoTime();
    private int color = 0xFFFFFFFF;

    VoiceBars(Context c) { super(c); }

    void level(float l) { level = l; }

    void mode(Mode m) { mode = m; postInvalidateOnAnimation(); }

    Mode mode() { return mode; }

    void color(int c) { color = c; invalidate(); }

    @Override
    protected void onDraw(Canvas canvas) {
        float t = (System.nanoTime() - t0) / 1e9f;
        int n = SHAPE.length;
        float W = getWidth(), H = getHeight();
        float bw = Math.min(W / (n * 2f - 1f), H / 5f), gap = bw;
        float x0 = (W - (n * bw + (n - 1) * gap)) / 2f;
        smooth += (level - smooth) * (level > smooth ? 0.5f : 0.18f);   // quick up, slow down
        for (int i = 0; i < n; i++) {
            float target;
            switch (mode) {
                case HEARING:
                    float wobble = 0.72f + 0.28f * (float) Math.sin(t * 9 + i * 1.7);
                    target = 0.16f + 0.84f * smooth * SHAPE[i] * wobble;
                    break;
                case THINKING:
                    target = 0.2f + 0.45f * (0.5f + 0.5f * (float) Math.sin(t * 7 - i * 0.95));
                    break;
                case DONE:
                    target = 0.16f;
                    break;
                default:
                    target = 0.14f + 0.1f * (0.5f + 0.5f * (float) Math.sin(t * 2.4 + i * 0.8));
            }
            h[i] += (target - h[i]) * 0.3f;
            float bh = Math.max(bw, h[i] * H);
            float x = x0 + i * (bw + gap);
            r.set(x, (H - bh) / 2f, x + bw, (H + bh) / 2f);
            int a = Math.round(255 * (0.55f + 0.45f * Math.min(1f, h[i] * 1.4f)));
            paint.setColor((color & 0x00FFFFFF) | (a << 24));
            canvas.drawRoundRect(r, bw / 2f, bw / 2f, paint);
        }
        if (mode != Mode.DONE || Math.abs(h[n / 2] - 0.16f) > 0.01f) postInvalidateOnAnimation();
    }
}

package dev.alok.emacshome;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;

/** The floating clock's state icon, drawn rather than typed: text glyphs sit unevenly. */
final class Mark extends Drawable {
    enum Kind { CLOCKED, PAUSED, IDLE, LOCKED }

    private static final int LIGHT = 0xFFEEEEEE;
    private static final int ACCENT = 0xFF8BE9C8;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private Kind kind = Kind.IDLE;

    void set(Kind k) {
        if (k != kind) { kind = k; invalidateSelf(); }
    }

    @Override
    public void draw(Canvas c) {
        Rect b = getBounds();
        float s = Math.min(b.width(), b.height()), cx = b.exactCenterX(), cy = b.exactCenterY();
        switch (kind) {
        case CLOCKED:                                   // solid accent dot: running
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(ACCENT);
            c.drawCircle(cx, cy, s * 0.36f, paint);
            break;
        case IDLE:                                      // ring: nothing clocked
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(s * 0.13f);
            paint.setColor(LIGHT);
            c.drawCircle(cx, cy, s * 0.36f, paint);
            break;
        case PAUSED: {                                  // two rounded bars
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(LIGHT);
            float w = s * 0.2f, h = s * 0.7f, gap = s * 0.18f, r = w / 2;
            c.drawRoundRect(new RectF(cx - gap / 2 - w, cy - h / 2, cx - gap / 2, cy + h / 2), r, r, paint);
            c.drawRoundRect(new RectF(cx + gap / 2, cy - h / 2, cx + gap / 2 + w, cy + h / 2), r, r, paint);
            break;
        }
        case LOCKED:                                    // small solid dot
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(LIGHT);
            c.drawCircle(cx, cy, s * 0.3f, paint);
            break;
        }
    }

    @Override public void setAlpha(int a) { paint.setAlpha(a); }
    @Override public void setColorFilter(ColorFilter f) { paint.setColorFilter(f); }
    @Override public int getOpacity() { return PixelFormat.TRANSLUCENT; }
}

package dev.alok.emacshome;

import android.animation.TimeInterpolator;

/**
 * A damped spring, as a time curve: it moves fast, passes its mark by a
 * hair and settles, the way the island should move.  DAMPING below 1
 * overshoots (0.78: about 2 %); STIFFNESS sets how soon it settles within
 * the animation's duration.
 */
final class Spring implements TimeInterpolator {
    static final Spring GROW = new Spring(0.78, 12);    // growing: a touch of overshoot
    static final Spring SETTLE = new Spring(1.0, 10);   // shrinking: none

    private final double z, w, wd;

    Spring(double damping, double stiffness) {
        z = damping;
        w = stiffness;
        wd = w * Math.sqrt(Math.max(1e-6, 1 - z * z));
    }

    @Override
    public float getInterpolation(float t) {
        if (t >= 1f) return 1f;
        double e = Math.exp(-z * w * t);
        if (z >= 1) return (float) (1 - e * (1 + w * t));          // critically damped
        return (float) (1 - e * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t)));
    }
}

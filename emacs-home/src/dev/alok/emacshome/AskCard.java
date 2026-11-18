package dev.alok.emacshome;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.content.Context;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * A question from Emacs, in the middle of the screen: it grows out of the
 * island and goes back into it once answered.  The same black as the
 * island, so it reads as the island come down to ask.  While it is up the
 * island listens for the answer once, if you had just spoken, and the card
 * shows that it does; a tap on that line listens again.  Yes and No answer
 * by touch, a tap outside is a no.
 */
final class AskCard {
    interface Answer { void answer(String word); }

    private final Context ui;
    private final WindowManager wm;
    private final int type;
    private FrameLayout root;
    private View scrim;
    private LinearLayout card;
    private TextView eyebrow, title, hint;
    private VoiceBars bars;
    private boolean leaving;

    AskCard(Context ui, WindowManager wm, int windowType) {
        this.ui = ui;
        this.wm = wm;
        this.type = windowType;
    }

    boolean showing() { return root != null && !leaving; }

    private int dp(float v) { return Math.round(v * ui.getResources().getDisplayMetrics().density); }

    private TextView text(float size, String family, int color) {
        TextView t = new TextView(ui);
        t.setTextSize(size);
        t.setTypeface(Typeface.create(family, Typeface.NORMAL));
        t.setTextColor(color);
        t.setGravity(Gravity.CENTER);
        t.setIncludeFontPadding(false);
        return t;
    }

    private TextView button(String label, int bg, int fg, Runnable click) {
        TextView b = text(16, "sans-serif-medium", fg);
        b.setText(label);
        GradientDrawable d = new GradientDrawable();
        d.setColor(bg);
        d.setCornerRadius(dp(26));
        b.setBackground(d);
        b.setOnClickListener(v -> click.run());
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(52), 1f);
        p.setMargins(dp(5), 0, dp(5), 0);
        b.setLayoutParams(p);
        return b;
    }

    /** "Did you mean X?" reads as a small "Did you mean" over a large X. */
    private void setQuestion(String q) {
        String lead = "Did you mean ";
        if (q.startsWith(lead)) {
            eyebrow.setText("Did you mean");
            eyebrow.setVisibility(View.VISIBLE);
            String rest = q.substring(lead.length());
            if (rest.endsWith("?")) rest = rest.substring(0, rest.length() - 1);
            title.setText(rest);
        } else {
            eyebrow.setVisibility(View.GONE);
            title.setText(q);
        }
    }

    /** Ask QUESTION, growing out of ISLAND (its rect on screen); a tap on the
     *  listening line is LISTEN: answer by voice. */
    void show(String question, Rect island, int accent, Answer answer, Runnable listen) {
        if (root != null && !leaving) {             // a new question while one is up: just the words
            title.animate().alpha(0f).setDuration(90).withEndAction(() -> {
                setQuestion(question);
                title.animate().alpha(1f).setDuration(160).start();
            }).start();
            return;
        }
        if (root != null) { try { wm.removeView(root); } catch (Exception e) { /* gone */ } }
        leaving = false;
        root = new FrameLayout(ui);
        scrim = new View(ui);
        scrim.setBackgroundColor(0x99000000);
        scrim.setAlpha(0f);
        scrim.setOnClickListener(v -> answer.answer("no"));
        root.addView(scrim, new FrameLayout.LayoutParams(-1, -1));

        card = new LinearLayout(ui);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setGravity(Gravity.CENTER_HORIZONTAL);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(0xFF000000);
        bg.setCornerRadius(dp(34));
        bg.setStroke(dp(1), 0x1FFFFFFF);
        card.setBackground(bg);
        card.setPadding(dp(22), dp(26), dp(22), dp(18));
        card.setElevation(dp(24));
        card.setClickable(true);                    // taps on the card aren't taps outside

        eyebrow = text(13, "sans-serif-medium", 0xFF8E8E93);
        eyebrow.setLetterSpacing(0.02f);
        title = text(22, "sans-serif-medium", 0xFFF5F5F7);
        title.setMaxLines(3);
        title.setEllipsize(TextUtils.TruncateAt.END);
        title.setLineSpacing(0, 1.1f);
        title.setPadding(0, dp(8), 0, dp(14));
        setQuestion(question);

        LinearLayout listening = new LinearLayout(ui);
        listening.setGravity(Gravity.CENTER);
        bars = new VoiceBars(ui);
        bars.color(accent);
        listening.addView(bars, new LinearLayout.LayoutParams(dp(26), dp(16)));
        hint = text(13, "sans-serif", 0xFF8E8E93);
        hint.setText("Say yes or no");
        hint.setPadding(dp(8), 0, 0, 0);
        listening.addView(hint);
        listening.setPadding(0, dp(6), 0, dp(20));
        listening.setOnClickListener(v -> listen.run());

        LinearLayout row = new LinearLayout(ui);
        row.addView(button("No", 0xFF1C1C1E, 0xFFF5F5F7, () -> answer.answer("no")));
        row.addView(button("Yes", accent, 0xFF000000, () -> answer.answer("yes")));

        card.addView(eyebrow);
        card.addView(title, new LinearLayout.LayoutParams(-1, -2));
        card.addView(listening);
        card.addView(row, new LinearLayout.LayoutParams(-1, -2));
        int w = Math.min(ui.getResources().getDisplayMetrics().widthPixels - dp(40), dp(380));
        root.addView(card, new FrameLayout.LayoutParams(w, -2, Gravity.CENTER));

        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(-1, -1, type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        lp.setFitInsetsTypes(0);
        card.setVisibility(View.INVISIBLE);
        wm.addView(root, lp);
        card.post(() -> {
            from(island);
            card.setVisibility(View.VISIBLE);
            card.animate().scaleX(1f).scaleY(1f).translationY(0f).alpha(1f)
                .setDuration(560).setInterpolator(Spring.GROW).start();
            scrim.animate().alpha(1f).setDuration(280).start();
        });
    }

    /** Put the card where the island is, as small as it: the start of growing, the end of going back. */
    private void from(Rect island) {
        int[] at = new int[2];
        card.getLocationOnScreen(at);
        float cw = Math.max(1, card.getWidth()), ch = Math.max(1, card.getHeight());
        card.setPivotX(cw / 2f);
        card.setPivotY(ch / 2f);
        card.setScaleX(Math.max(0.05f, island.width() / cw));
        card.setScaleY(Math.max(0.05f, island.height() / ch));
        card.setTranslationY(island.centerY() - (at[1] + ch / 2f));
        card.setAlpha(0.2f);
    }

    void level(float l) { if (bars != null) bars.level(l); }

    void listening(VoiceBars.Mode m, String words) {
        if (bars == null) return;
        bars.mode(m);
        if (words != null) hint.setText(words);
    }

    /** Back into the island. */
    void dismiss(Rect island) {
        if (root == null || leaving) return;
        leaving = true;
        final FrameLayout gone = root;
        int[] at = new int[2];
        card.getLocationOnScreen(at);
        float cw = Math.max(1, card.getWidth()), ch = Math.max(1, card.getHeight());
        scrim.animate().alpha(0f).setDuration(220).start();
        card.animate()
            .scaleX(Math.max(0.05f, island.width() / cw)).scaleY(Math.max(0.05f, island.height() / ch))
            .translationY(island.centerY() - (at[1] - card.getTranslationY() + ch / 2f)).alpha(0f)
            .setDuration(320).setInterpolator(Spring.SETTLE)
            .setListener(new AnimatorListenerAdapter() {
                @Override public void onAnimationEnd(Animator a) {
                    try { wm.removeView(gone); } catch (Exception e) { /* gone */ }
                    if (root == gone) { root = null; leaving = false; }
                }
            }).start();
    }
}

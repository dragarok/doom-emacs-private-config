package dev.alok.emacshome;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.hardware.display.DisplayManager;
import android.os.FileObserver;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.Display;
import android.view.DisplayCutout;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.animation.DecelerateInterpolator;
import android.view.animation.OvershootInterpolator;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The floating clock: an island round the camera hole showing the org clock,
 * which grows into a card with the task and its buttons when tapped; the
 * same in an ongoing notification.
 * Emacs writes clock.tsv from its clock hooks and we watch it; buttons go
 * back through emacsclient to `emacs-home-clock-action'.  While running it
 * also logs every app that comes to the foreground into foreground.tsv, and
 * the presses Emacs never hears about (opening the island, Lock) into the
 * phone's usage log (usage-log.el).
 */
public class FloatService extends Service {
    private static final String CHANNEL = "clock";
    private static final File CLOCK = new File(Catalog.DIR, "clock.tsv");
    // In org, so it syncs to the Mac and is backed up; read by day-log.el.
    private static final File FOREGROUND = new File("/sdcard/org/logs/foreground_localhost.tsv");
    // usage-log.el's file for this machine: Emacs's `system-name' here is
    // "localhost".  We share Emacs's user, so its storage access too.
    private static final File USAGE = new File("/sdcard/org/logs/usage_log_localhost.tsv");

    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService bg = Executors.newSingleThreadExecutor();
    private WindowManager wm;
    private Context ui;               // IslandAccess when enabled, else this
    // The island: one window round the camera hole, collapsed or grown.
    private LinearLayout island, details, buttons;
    private WindowManager.LayoutParams lp;
    private GradientDrawable shape;
    private TextView minutes, title, sub;
    private final Mark mark = new Mark();
    private ImageView markView;
    private int pillH, cardW, gapW;   // collapsed height; grown width; camera gap
    private float open;               // 0 collapsed .. 1 grown, mid-morph between
    private boolean opening;
    private ValueAnimator morph;
    private final Runnable autoHide = () -> setOpen(false);
    private FileObserver observer;
    private Widgets widgets;

    // Locked: shrunk to a dot that touches pass through (games), until
    // Emacs is back in front -- Home, or the foreground log seeing it.
    private volatile boolean locked;
    private boolean clocked;
    private long start;          // epoch seconds, when clocked
    private String task = "";    // clocked task, or the last one when idle

    private long usageSince = System.currentTimeMillis();
    private String lastForeground;

    @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        getSystemService(NotificationManager.class).createNotificationChannel(
                new NotificationChannel(CHANNEL, "Clock", NotificationManager.IMPORTANCE_LOW));
        readClock();
        startForeground(1, notification());
        if (Settings.canDrawOverlays(this)) addOverlay();
        observer = new FileObserver(Catalog.DIR.getPath(),
                                    FileObserver.CLOSE_WRITE | FileObserver.MOVED_TO) {
            @Override public void onEvent(int event, String path) {
                if (CLOCK.getName().equals(path)) main.post(FloatService.this::refresh);
                if (Widgets.WANTED.getName().equals(path)) main.post(widgets::sync);
            }
        };
        observer.startWatching();
        widgets = new Widgets(this, main);
        widgets.start();
        main.post(tick);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int id) {
        String action = intent == null ? null : intent.getStringExtra("action");
        if (action != null) act(action);
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        main.removeCallbacks(tick);
        if (observer != null) observer.stopWatching();
        if (widgets != null) widgets.stop();
        if (island != null) wm.removeView(island);
        super.onDestroy();
    }

    /** Every 30s: the pill's minutes, and who has been in the foreground. */
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            updateIsland();
            bg.execute(FloatService.this::logForeground);
            main.postDelayed(this, locked ? 10_000 : 30_000);
        }
    };

    private void act(String action) {
        if (action.equals("lock")) { press("island-lock"); lock(); return; }
        if (action.equals("unlock")) { unlock(); return; }
        if (action.equals("reattach")) { reattach(); return; }
        // Done, Flow and Clock in prompt in the minibuffer, so they need Emacs on screen.
        if (action.equals("done") || action.equals("flow") || action.equals("clockin")) {
            Intent emacs = getPackageManager().getLaunchIntentForPackage(Emacs.PACKAGE);
            if (emacs != null) startActivity(emacs.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
        setOpen(false);
        bg.execute(() -> Emacs.eval(this, "(emacs-home-clock-action '" + action + ")"));
    }

    /** clock.tsv is one line: clocked|idle TAB start-epoch TAB task. */
    private void readClock() {
        try {
            String[] f = new String(Files.readAllBytes(CLOCK.toPath()), StandardCharsets.UTF_8)
                    .trim().split("\t", 3);
            clocked = f[0].equals("clocked");
            start = Long.parseLong(f[1]);
            task = f.length > 2 ? f[2] : "";
        } catch (Exception e) {
            clocked = false;
            task = "";
        }
    }

    private void refresh() {
        readClock();
        updateIsland();
        getSystemService(NotificationManager.class).notify(1, notification());
    }

    private String elapsed() {
        long m = Math.max(0, System.currentTimeMillis() / 1000 - start) / 60;
        return m < 60 ? m + "m" : String.format(Locale.US, "%dh%02d", m / 60, m % 60);
    }

    // ---- notification ---------------------------------------------------

    private Notification notification() {
        Notification.Builder b = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_recent_history)
                .setOngoing(true)
                .setOnlyAlertOnce(true);
        if (clocked) {
            b.setContentTitle(task)
             .setWhen(start * 1000).setUsesChronometer(true).setShowWhen(true)
             .addAction(action("Pause", "pause"))
             .addAction(action("Done", "done"))
             .addAction(action("Cancel", "cancel"));
        } else {
            b.setContentTitle("No clock")
             .setContentText(task.isEmpty() ? null : "Last: " + task)
             .setShowWhen(false)
             .addAction(action("Resume", "resume"))
             .addAction(action("Clock in", "clockin"))
             .addAction(action("Flow", "flow"));
        }
        return b.build();
    }

    private Notification.Action action(String label, String action) {
        Intent i = new Intent(this, FloatService.class).putExtra("action", action);
        PendingIntent p = PendingIntent.getService(this, action.hashCode(), i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Action.Builder(null, label, p).build();
    }

    // ---- the island round the camera hole ----------------------------------

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private boolean dark() {
        return (getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
               == Configuration.UI_MODE_NIGHT_YES;
    }

    // The collapsed island is black in either theme -- the camera hole is
    // part of it.  The grown card takes the system theme's Material You colours.
    private int surface() { return getColor(dark() ? android.R.color.system_neutral1_900
                                                   : android.R.color.system_neutral1_10); }
    private int onSurface() { return getColor(dark() ? android.R.color.system_neutral1_50
                                                     : android.R.color.system_neutral1_900); }
    private int muted() { return getColor(dark() ? android.R.color.system_neutral2_300
                                                 : android.R.color.system_neutral2_600); }
    private int accent() { return getColor(dark() ? android.R.color.system_accent1_200
                                                  : android.R.color.system_accent1_600); }
    private int pillAccent() { return getColor(android.R.color.system_accent1_200); }

    @Override
    public void onConfigurationChanged(Configuration c) {
        super.onConfigurationChanged(c);
        updateIsland();               // light/dark switched: recolour
    }

    /** The camera hole at the top centre, or a notional one if there's none.
     *  Its bounding rect runs from the screen's edge; the hole is the bottom
     *  of it, as tall as it is wide. */
    private Rect cutout() {
        DisplayCutout c = getSystemService(DisplayManager.class)
                .getDisplay(Display.DEFAULT_DISPLAY).getCutout();
        if (c != null && !c.getBoundingRectTop().isEmpty()) {
            Rect r = c.getBoundingRectTop();
            return new Rect(r.left, Math.max(0, r.bottom - r.width()), r.right, r.bottom);
        }
        int mid = getResources().getDisplayMetrics().widthPixels / 2;
        return new Rect(mid - dp(12), dp(10), mid + dp(12), dp(34));
    }

    /** Take the island down and put it back up, in whichever window we may. */
    private void reattach() {
        if (island == null) {
            if (Settings.canDrawOverlays(this) || IslandAccess.instance != null) addOverlay();
            return;
        }
        if (morph != null) morph.cancel();
        // Not isAttachedToWindow(): just after addView it isn't yet, and the
        // first window would be left behind under the second.
        try { wm.removeView(island); } catch (IllegalArgumentException x) { /* gone */ }
        island = null;
        opening = false;
        open = 0f;
        addOverlay();
    }

    private TextView text(float size, String family) {
        TextView t = new TextView(ui);
        t.setTextSize(size);
        t.setTypeface(Typeface.create(family, Typeface.NORMAL));
        t.setSingleLine(true);
        t.setEllipsize(TextUtils.TruncateAt.END);
        t.setIncludeFontPadding(false);
        return t;
    }

    private void addOverlay() {
        // Above the status bar if IslandAccess is on; under it otherwise.
        IslandAccess access = IslandAccess.instance;
        ui = access != null ? access : this;
        wm = ui.getSystemService(WindowManager.class);
        Rect hole = cutout();
        pillH = Math.max(dp(26), hole.height() + dp(4));
        gapW = hole.width() + dp(8);
        cardW = Math.min(getResources().getDisplayMetrics().widthPixels - dp(24), dp(400));

        // Top row: mark | camera | minutes -- all the collapsed island shows.
        markView = new ImageView(ui);
        markView.setImageDrawable(mark);
        minutes = text(13, "sans-serif-medium");
        minutes.setGravity(Gravity.CENTER);
        LinearLayout top = new LinearLayout(ui);
        top.setGravity(Gravity.CENTER);
        top.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, pillH));
        top.addView(markView);
        top.addView(new View(ui), new LinearLayout.LayoutParams(gapW, 1));
        top.addView(minutes);

        title = text(17, "sans-serif-medium");
        sub = text(13, "sans-serif");
        sub.setPadding(0, dp(6), 0, dp(14));
        buttons = new LinearLayout(ui);
        details = new LinearLayout(ui);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(dp(20), dp(4), dp(20), dp(18));
        details.addView(title);
        details.addView(sub);
        details.addView(buttons);
        details.setVisibility(View.GONE);

        island = new LinearLayout(ui);
        island.setOrientation(LinearLayout.VERTICAL);
        shape = new GradientDrawable();
        island.setBackground(shape);
        island.addView(top);
        island.addView(details);

        lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, pillH,
                access != null ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                               : WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
        lp.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        lp.setFitInsetsTypes(0);
        lp.y = Math.max(0, hole.centerY() - pillH / 2);

        // Tap the top row to grow or shrink; a touch anywhere else shrinks it.
        top.setOnClickListener(v -> setOpen(!opening));
        island.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_OUTSIDE) setOpen(false);
            else if (opening) keepOpen();
            return false;
        });

        updateIsland();
        wm.addView(island, lp);
    }

    private void keepOpen() {
        main.removeCallbacks(autoHide);
        main.postDelayed(autoHide, 8_000);
    }

    /** Grow into the card or shrink back into the pill, morphing the window. */
    private void setOpen(boolean want) {
        main.removeCallbacks(autoHide);
        if (island == null || want == opening || (want && locked)) return;
        opening = want;
        if (want) {
            press("island-open");
            keepOpen();
        }
        details.setVisibility(View.VISIBLE);
        updateIsland();
        int fromW = lp.width, fromH = lp.height;
        island.measure(View.MeasureSpec.makeMeasureSpec(cardW, View.MeasureSpec.EXACTLY),
                       View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
        int toW = want ? cardW : collapsedWidth(), toH = want ? island.getMeasuredHeight() : pillH;
        float from = open, to = want ? 1f : 0f;
        if (morph != null) morph.cancel();
        morph = ValueAnimator.ofFloat(0f, 1f).setDuration(want ? 320 : 220);
        morph.setInterpolator(want ? new OvershootInterpolator(0.8f)
                                   : new DecelerateInterpolator(1.5f));
        morph.addUpdateListener(a -> {
            float f = (float) a.getAnimatedValue();
            open = Math.max(0f, Math.min(1f, from + (to - from) * f));
            lp.width = Math.round(fromW + (toW - fromW) * f);
            lp.height = Math.max(pillH, Math.round(fromH + (toH - fromH) * f));
            paint();
            if (island.isAttachedToWindow()) wm.updateViewLayout(island, lp);
        });
        morph.addListener(new AnimatorListenerAdapter() {
            @Override public void onAnimationEnd(Animator a) {
                if (!opening && open == 0f) details.setVisibility(View.GONE);
            }
        });
        morph.start();
    }

    /** Colours and corners for how far open the island is. */
    private void paint() {
        ArgbEvaluator mix = new ArgbEvaluator();
        shape.setColor((int) mix.evaluate(open, 0xFF000000, surface()));
        shape.setCornerRadius(pillH / 2f + (dp(26) - pillH / 2f) * open);
        int fg = (int) mix.evaluate(open, 0xFFF2F2F2, onSurface());
        mark.colors(fg, (int) mix.evaluate(open, pillAccent(), accent()));
        minutes.setTextColor(fg);
        details.setAlpha(Math.max(0f, open * 1.4f - 0.4f));   // text in once there's room
        title.setTextColor(onSurface());
        sub.setTextColor(muted());
    }

    private int collapsedWidth() {
        return 2 * (sideWidth() + dp(10)) + gapW;
    }

    private int markSize() { return Math.round(pillH * (locked ? 0.22f : 0.3f)); }

    /** Width of each side of the camera: the wider of mark and minutes. */
    private int sideWidth() {
        int m = markSize();
        if (minutes.getVisibility() != View.VISIBLE) return m;
        minutes.measure(View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED));
        return Math.max(m, minutes.getMeasuredWidth());
    }

    private void lock() {
        if (island == null) return;
        setOpen(false);
        locked = true;
        island.setAlpha(0.35f);
        lp.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        updateIsland();
        main.removeCallbacks(tick);
        main.postDelayed(tick, 10_000);
    }

    private void unlock() {
        if (island == null || !locked) return;
        locked = false;
        island.setAlpha(1f);
        lp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        updateIsland();
    }

    private TextView chip(String label, String action) {
        TextView t = text(14, "sans-serif-medium");
        t.setText(label);
        t.setGravity(Gravity.CENTER);
        t.setTextColor(accent());
        GradientDrawable bg = new GradientDrawable();
        bg.setColor((accent() & 0x00FFFFFF) | 0x24000000);   // the accent, faintly
        bg.setCornerRadius(dp(18));
        t.setBackground(bg);
        t.setPadding(dp(4), dp(10), dp(4), dp(10));
        t.setOnClickListener(v -> act(action));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(38), 1f);
        p.setMarginEnd(dp(8));
        t.setLayoutParams(p);
        return t;
    }

    /** Mark, minutes, and the card's task and buttons, from the clock state. */
    private void updateIsland() {
        if (island == null) return;
        mark.set(locked ? Mark.Kind.LOCKED : clocked ? Mark.Kind.CLOCKED
                 : task.isEmpty() ? Mark.Kind.IDLE : Mark.Kind.PAUSED);
        int m = markSize();
        boolean showMinutes = clocked && !locked;
        minutes.setText(showMinutes ? elapsed() : "");
        minutes.setVisibility(showMinutes ? View.VISIBLE : View.GONE);
        // Both sides as wide as the wider, so the camera stays centred.
        int side = sideWidth();
        markView.setLayoutParams(new LinearLayout.LayoutParams(side, m));
        if (showMinutes) minutes.setLayoutParams(new LinearLayout.LayoutParams(side, pillH));

        title.setText(task.isEmpty() ? "Nothing clocked" : task);
        sub.setText(clocked ? "Clocked in · " + elapsed()
                    : task.isEmpty() ? "Pick something to do with Flow" : "Paused");
        buttons.removeAllViews();
        String[][] bs = clocked
                ? new String[][] {{"Pause", "pause"}, {"Done", "done"},
                                  {"Cancel", "cancel"}, {"Lock", "lock"}}
                : task.isEmpty()
                ? new String[][] {{"Clock in", "clockin"}, {"Flow", "flow"}, {"Lock", "lock"}}
                : new String[][] {{"Resume", "resume"}, {"Clock in", "clockin"},
                                  {"Flow", "flow"}, {"Lock", "lock"}};
        for (String[] b : bs) buttons.addView(chip(b[0], b[1]));
        paint();
        if (!opening && (morph == null || !morph.isRunning())) {
            lp.width = collapsedWidth();
            lp.height = pillH;
            if (island.isAttachedToWindow()) wm.updateViewLayout(island, lp);
        }
    }

    // ---- foreground log ---------------------------------------------------

    /**
     * Append app switches since the last call: TIME TAB PACKAGE TAB LABEL.
     * The screen turning off and on is logged as package "-" and "+", so
     * the day log can tell an app in use from a phone in a pocket.
     */
    private void logForeground() {
        long now = System.currentTimeMillis();
        UsageEvents events = getSystemService(UsageStatsManager.class).queryEvents(usageSince, now);
        usageSince = now;
        UsageEvents.Event e = new UsageEvents.Event();
        StringBuilder out = new StringBuilder();
        SimpleDateFormat time = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US);
        PackageManager pm = getPackageManager();
        while (events != null && events.hasNextEvent()) {
            events.getNextEvent(e);
            String pkg = e.getPackageName();
            int type = e.getEventType();
            if (type == UsageEvents.Event.SCREEN_NON_INTERACTIVE
                || type == UsageEvents.Event.SCREEN_INTERACTIVE) {
                boolean on = type == UsageEvents.Event.SCREEN_INTERACTIVE;
                out.append(time.format(new Date(e.getTimeStamp()))).append('\t')
                   .append(on ? "+\tscreen on\n" : "-\tscreen off\n");
                // Whatever comes up after the screen is back is a fresh session.
                lastForeground = null;
                continue;
            }
            if (type != UsageEvents.Event.MOVE_TO_FOREGROUND
                || pkg.equals(lastForeground) || pkg.equals(getPackageName())) continue;
            lastForeground = pkg;
            String label;
            try {
                label = pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString();
            } catch (Exception x) {
                label = pkg;
            }
            out.append(time.format(new Date(e.getTimeStamp()))).append('\t')
               .append(pkg).append('\t').append(label).append('\n');
        }
        if (locked && Emacs.PACKAGE.equals(lastForeground)) main.post(this::unlock);
        if (out.length() == 0) return;
        try (FileOutputStream f = new FileOutputStream(FOREGROUND, true)) {
            f.write(out.toString().getBytes(StandardCharsets.UTF_8));
        } catch (Exception x) {
            android.util.Log.w("EmacsHome", "foreground log", x);
        }
    }

    /** Log an island press to the usage log: TIME TAB island TAB NAME. */
    private void press(String name) {
        String line = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(new Date())
                + "\tisland\t" + name + "\n";
        bg.execute(() -> {
            try (FileOutputStream f = new FileOutputStream(USAGE, true)) {
                f.write(line.getBytes(StandardCharsets.UTF_8));
            } catch (Exception x) {
                android.util.Log.w("EmacsHome", "press log", x);
            }
        });
    }
}

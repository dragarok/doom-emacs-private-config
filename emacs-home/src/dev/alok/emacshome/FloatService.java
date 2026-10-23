package dev.alok.emacshome;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.FileObserver;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
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
 * The floating clock: a small pill over every app showing the clocked org
 * task, which expands into its buttons; the same in an ongoing notification.
 * Emacs writes clock.tsv from its clock hooks and we watch it; buttons go
 * back through emacsclient to `emacs-home-clock-action'.  While running it
 * also logs every app that comes to the foreground into foreground.tsv.
 */
public class FloatService extends Service {
    private static final String CHANNEL = "clock";
    private static final File CLOCK = new File(Catalog.DIR, "clock.tsv");
    private static final File FOREGROUND = new File(Catalog.DIR, "foreground.tsv");

    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService bg = Executors.newSingleThreadExecutor();
    private WindowManager wm;
    private WindowManager.LayoutParams lp;
    private LinearLayout root, row;
    private TextView pill;
    private FileObserver observer;

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
            }
        };
        observer.startWatching();
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
        if (root != null) wm.removeView(root);
        super.onDestroy();
    }

    /** Every 30s: the pill's minutes, and who has been in the foreground. */
    private final Runnable tick = new Runnable() {
        @Override public void run() {
            updatePill();
            bg.execute(FloatService.this::logForeground);
            main.postDelayed(this, locked ? 10_000 : 30_000);
        }
    };

    private void act(String action) {
        if (action.equals("lock")) { lock(); return; }
        if (action.equals("unlock")) { unlock(); return; }
        // Done and Flow prompt in the minibuffer, so they need Emacs on screen.
        if (action.equals("done") || action.equals("flow")) {
            Intent emacs = getPackageManager().getLaunchIntentForPackage(Emacs.PACKAGE);
            if (emacs != null) startActivity(emacs.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
        if (row != null) {
            row.setVisibility(View.GONE);
            updatePill();
        }
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
        updatePill();
        if (row != null) updateRow();
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

    // ---- floating pill --------------------------------------------------

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private void addOverlay() {
        wm = getSystemService(WindowManager.class);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable bgd = new GradientDrawable();
        bgd.setColor(0xCC1E1E1E);
        bgd.setCornerRadius(dp(14));
        root.setBackground(bgd);
        root.setPadding(dp(10), dp(4), dp(10), dp(4));

        pill = new TextView(this);
        pill.setTextColor(0xFFEEEEEE);
        pill.setTextSize(12);
        pill.setSingleLine(true);
        pill.setEllipsize(TextUtils.TruncateAt.END);
        pill.setMaxWidth(dp(200));
        pill.setGravity(Gravity.CENTER);
        row = new LinearLayout(this);
        row.setVisibility(View.GONE);
        root.addView(pill);
        root.addView(row);
        updatePill();
        updateRow();

        lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.END;
        lp.x = dp(8);
        lp.y = dp(36);
        // Tap toggles the buttons; drag moves the pill up and down.
        root.setOnTouchListener(new View.OnTouchListener() {
            float downY;
            int startY;
            boolean dragged;
            @Override public boolean onTouch(View v, MotionEvent e) {
                switch (e.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    downY = e.getRawY(); startY = lp.y; dragged = false;
                    return true;
                case MotionEvent.ACTION_MOVE:
                    if (Math.abs(e.getRawY() - downY) > dp(6)) dragged = true;
                    if (dragged) {
                        lp.y = Math.max(0, startY + Math.round(e.getRawY() - downY));
                        wm.updateViewLayout(root, lp);
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                    if (!dragged) {
                        row.setVisibility(row.getVisibility() == View.VISIBLE
                                          ? View.GONE : View.VISIBLE);
                        updatePill();
                    }
                    return true;
                }
                return false;
            }
        });
        wm.addView(root, lp);
    }

    /**
     * Re-measure the overlay window, which otherwise keeps its first size.
     * The locked dot and the idle collapsed ○ get small fixed sizes: a
     * wrapped window grows with the pill but doesn't shrink back from it.
     */
    private void relayout() {
        if (root == null || !root.isAttachedToWindow()) return;
        boolean collapsed = row.getVisibility() != View.VISIBLE;
        int size = locked ? dp(22)
                 : !clocked && collapsed ? dp(30)
                 : WindowManager.LayoutParams.WRAP_CONTENT;
        lp.width = lp.height = size;
        wm.updateViewLayout(root, lp);
    }

    private void lock() {
        if (root == null) return;
        locked = true;
        row.setVisibility(View.GONE);
        root.setAlpha(0.35f);
        lp.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        updatePill();
        main.removeCallbacks(tick);
        main.postDelayed(tick, 10_000);
    }

    private void unlock() {
        if (root == null || !locked) return;
        locked = false;
        root.setAlpha(1f);
        lp.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        updatePill();
    }

    private void updatePill() {
        if (pill == null) return;
        boolean expanded = row.getVisibility() == View.VISIBLE;
        pill.setText(locked ? "•"
                     : clocked ? "● " + elapsed() + "  " + task
                     // Idle: ○ when clean, ‖ when paused -- naming the
                     // paused task only when tapped open.
                     : task.isEmpty() ? "○"
                     : expanded ? "‖ " + task : "‖");
        relayout();
    }

    private void updateRow() {
        row.removeAllViews();
        String[][] buttons = clocked
                ? new String[][] {{"Pause", "pause"}, {"Done", "done"},
                                  {"Cancel", "cancel"}, {"Lock", "lock"}}
                : new String[][] {{"Resume", "resume"}, {"Flow", "flow"}, {"Lock", "lock"}};
        for (String[] b : buttons) {
            TextView t = new TextView(this);
            t.setText(b[0]);
            t.setTextColor(0xFF8BE9C8);
            t.setTextSize(13);
            t.setPadding(dp(4), dp(6), dp(12), dp(4));
            t.setOnClickListener(v -> act(b[1]));
            row.addView(t);
        }
        relayout();
    }

    // ---- foreground log ---------------------------------------------------

    /** Append app switches since the last call: TIME TAB PACKAGE TAB LABEL. */
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
            if (e.getEventType() != UsageEvents.Event.MOVE_TO_FOREGROUND
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
}

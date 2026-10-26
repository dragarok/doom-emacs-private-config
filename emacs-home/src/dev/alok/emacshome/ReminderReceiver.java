package dev.alok.emacshome;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * A reminder's alarm rings here: a notification -- tap it to open the task
 * in Emacs, Clock in, or Snooze 10 minutes.  The buttons come back here too,
 * and reach Emacs through its emacsclient (reminders.el's reminders-open and
 * reminders-clock-in), starting it first when it isn't running.
 */
public final class ReminderReceiver extends BroadcastReceiver {
    static final String CHANNEL = "reminders";
    static final int SNOOZE_MINUTES = 10;

    @Override
    public void onReceive(Context c, Intent i) {
        String action = i.getAction() == null ? "" : i.getAction();
        int id = (i.getStringExtra("file") + i.getStringExtra("heading")).hashCode();
        NotificationManager nm = c.getSystemService(NotificationManager.class);
        switch (action) {
            case Reminders.RING:
                nm.createNotificationChannel(new NotificationChannel(
                        CHANNEL, "Reminders", NotificationManager.IMPORTANCE_HIGH));
                String at = i.getStringExtra("at");
                nm.notify(id, new Notification.Builder(c, CHANNEL)
                        .setSmallIcon(android.R.drawable.ic_popup_reminder)
                        .setContentTitle(i.getStringExtra("title"))
                        .setContentText(at == null || at.isEmpty() ? "Reminder" : "At " + at)
                        .setCategory(Notification.CATEGORY_REMINDER)
                        .setAutoCancel(true)
                        .setContentIntent(button(c, i, "open"))
                        .addAction(new Notification.Action.Builder(null, "Clock in", button(c, i, "clockin")).build())
                        .addAction(new Notification.Action.Builder(null, "Snooze " + SNOOZE_MINUTES + "m", button(c, i, "snooze")).build())
                        .build());
                break;
            case "open":
            case "clockin":
                nm.cancel(id);
                if (action.equals("open")) {
                    Intent emacs = c.getPackageManager().getLaunchIntentForPackage(Emacs.PACKAGE);
                    if (emacs != null) c.startActivity(emacs.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                }
                String form = "(" + (action.equals("open") ? "reminders-open" : "reminders-clock-in")
                        + " " + lisp(i.getStringExtra("file")) + " " + lisp(i.getStringExtra("heading")) + ")";
                PendingResult done = goAsync();
                new Thread(() -> {
                    // Emacs may still be starting: try for a while.
                    for (int n = 0; n < 15 && !Emacs.tryEval(c, form); n++) {
                        try { Thread.sleep(1000); } catch (InterruptedException e) { break; }
                    }
                    done.finish();
                }).start();
                break;
            case "snooze":
                nm.cancel(id);
                Reminders.snooze(c, i, SNOOZE_MINUTES);
                break;
            default:
        }
    }

    private static PendingIntent button(Context c, Intent rung, String action) {
        Intent i = new Intent(rung).setAction(action);
        return PendingIntent.getBroadcast(c, (action + rung.getStringExtra("file") + rung.getStringExtra("heading")).hashCode(),
                i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** S as an Elisp string literal. */
    private static String lisp(String s) {
        return "\"" + (s == null ? "" : s).replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

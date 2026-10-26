package dev.alok.emacshome;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

/**
 * Sets an exact alarm for each reminder Emacs writes (reminders.el), so it
 * rings while Emacs sleeps.  reminders.tsv, one per line:
 *   TIME-MS \t TITLE \t AT \t FILE \t HEADING
 * AT is the task's own time ("09:00", or empty).  The alarms set last time
 * are cancelled first: their count is kept, and alarm i is request code i.
 */
final class Reminders {
    static final File FILE = new File(Catalog.DIR, "reminders.tsv");
    static final String RING = "dev.alok.emacshome.REMIND";

    static synchronized void schedule(Context c) {
        AlarmManager alarms = c.getSystemService(AlarmManager.class);
        SharedPreferences prefs = c.getSharedPreferences("reminders", Context.MODE_PRIVATE);
        for (int i = prefs.getInt("count", 0) - 1; i >= 0; i--) {
            alarms.cancel(ring(c, i, new String[] {"0", "", "", "", ""}));
        }
        long now = System.currentTimeMillis();
        int n = 0;
        for (String[] r : read()) {
            long at;
            try { at = Long.parseLong(r[0]); } catch (NumberFormatException e) { continue; }
            if (at <= now) continue;
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, ring(c, n++, r));
        }
        prefs.edit().putInt("count", n).apply();
        Log.i("EmacsHome", "reminders: " + n + " set");
    }

    /** Snooze: the same reminder again in MINUTES, as an alarm of its own. */
    static void snooze(Context c, Intent rung, int minutes) {
        String[] r = {"0", rung.getStringExtra("title"), rung.getStringExtra("at"),
                      rung.getStringExtra("file"), rung.getStringExtra("heading")};
        c.getSystemService(AlarmManager.class).setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + minutes * 60_000L,
                ring(c, 100_000 + Math.floorMod((r[3] + r[4]).hashCode(), 100_000), r));
    }

    static PendingIntent ring(Context c, int code, String[] r) {
        Intent i = new Intent(c, ReminderReceiver.class).setAction(RING)
                .putExtra("title", r[1]).putExtra("at", r[2])
                .putExtra("file", r[3]).putExtra("heading", r[4]);
        return PendingIntent.getBroadcast(c, code, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static List<String[]> read() {
        List<String[]> rows = new ArrayList<>();
        try {
            if (!FILE.exists()) return rows;
            for (String line : Files.readAllLines(FILE.toPath(), StandardCharsets.UTF_8)) {
                String[] r = line.split("\t", -1);
                if (r.length >= 5) rows.add(r);
            }
        } catch (Exception e) {
            Log.w("EmacsHome", "reminders: read", e);
        }
        return rows;
    }
}

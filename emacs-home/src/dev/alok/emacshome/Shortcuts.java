package dev.alok.emacshome;

import android.content.Context;
import android.content.pm.LauncherApps;
import android.content.pm.ShortcutInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Process;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Other apps' shortcuts (a long press on a launcher icon: Firefox's "New
 * private tab"), for Emacs to pin like apps:
 *   shortcuts.tsv                (we write)  LABEL \t PACKAGE \t ID \t ICON
 *   icons/ICON                   (we write)  shortcut_PKG_HASH.png
 * Listing and starting them is the home app's right, which we hold.
 */
final class Shortcuts {
    private static final String TAG = "EmacsHome";

    static void write(Context c) {
        try {
            LauncherApps la = c.getSystemService(LauncherApps.class);
            if (!la.hasShortcutHostPermission()) return;
            LauncherApps.ShortcutQuery q = new LauncherApps.ShortcutQuery().setQueryFlags(
                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST
                    | LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC
                    | LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED);
            List<ShortcutInfo> all = la.getShortcuts(q, Process.myUserHandle());
            if (all == null) return;
            android.content.pm.PackageManager pm = c.getPackageManager();
            int density = c.getResources().getDisplayMetrics().densityDpi;
            File icons = new File(Catalog.DIR, "icons");
            icons.mkdirs();
            StringBuilder tsv = new StringBuilder();
            for (ShortcutInfo s : all) {
                if (!s.isEnabled()) continue;
                String app = pm.getApplicationLabel(pm.getApplicationInfo(s.getPackage(), 0)).toString();
                CharSequence name = s.getShortLabel() != null ? s.getShortLabel() : s.getId();
                // Ids can be anything, a whole content: URI even; name the
                // icon by a hash and tell Emacs the name.
                String icon = "shortcut_" + s.getPackage() + "_" + Integer.toHexString(s.getId().hashCode()) + ".png";
                tsv.append((app + ": " + name).replaceAll("[\t\n]", " ")).append('\t')
                   .append(s.getPackage()).append('\t').append(s.getId().replaceAll("[\t\n]", " "))
                   .append('\t').append(icon).append('\n');
                File png = new File(icons, icon);
                try {
                    if (png.lastModified() < s.getLastChangedTimestamp()) {
                        Drawable d = la.getShortcutIconDrawable(s, density);
                        if (d != null) save(d, png);
                    }
                } catch (Exception e) {
                    Log.w(TAG, "shortcut icon " + s.getId(), e);
                }
            }
            File tmp = new File(Catalog.DIR, "shortcuts.tsv.tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                out.write(tsv.toString().getBytes(StandardCharsets.UTF_8));
            }
            tmp.renameTo(new File(Catalog.DIR, "shortcuts.tsv"));
        } catch (Exception e) {
            Log.w(TAG, "shortcuts", e);
        }
    }

    /** Start PKG's shortcut ID; only one the app published can be. */
    static void start(Context c, String pkg, String id) {
        try {
            c.getSystemService(LauncherApps.class).startShortcut(pkg, id, null, null, Process.myUserHandle());
        } catch (Exception e) {
            Log.w(TAG, "shortcut " + pkg + "/" + id, e);
        }
    }

    private static void save(Drawable icon, File png) throws Exception {
        Bitmap b = Bitmap.createBitmap(Catalog.ICON_PX, Catalog.ICON_PX, Bitmap.Config.ARGB_8888);
        icon.setBounds(0, 0, Catalog.ICON_PX, Catalog.ICON_PX);
        icon.draw(new Canvas(b));
        try (FileOutputStream out = new FileOutputStream(png)) {
            b.compress(Bitmap.CompressFormat.PNG, 100, out);
        }
    }
}

package dev.alok.emacshome;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Writes the installed apps where Emacs reads them (emacs-home.el):
 *   apps.tsv          LABEL \t PACKAGE \t ACTIVITY, one per line
 *   icons/PKG_ACT.png re-rendered only when the package updates
 */
final class Catalog {
    static final File DIR = new File("/data/data/com.termux/files/home/.emacs-home");
    static final int ICON_PX = 144;

    static synchronized void write(Context c) {
        try {
            PackageManager pm = c.getPackageManager();
            Intent launchable = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
            List<ResolveInfo> apps = pm.queryIntentActivities(launchable, 0);
            apps.sort(new ResolveInfo.DisplayNameComparator(pm));
            File icons = new File(DIR, "icons");
            icons.mkdirs();
            StringBuilder tsv = new StringBuilder();
            for (ResolveInfo ri : apps) {
                ActivityInfo ai = ri.activityInfo;
                if (ai.packageName.equals(c.getPackageName())) continue;
                String label = ri.loadLabel(pm).toString().replaceAll("[\t\n]", " ");
                tsv.append(label).append('\t').append(ai.packageName)
                   .append('\t').append(ai.name).append('\n');
                File png = new File(icons, ai.packageName + "_" + ai.name + ".png");
                long updated = pm.getPackageInfo(ai.packageName, 0).lastUpdateTime;
                if (png.lastModified() < updated) save(ri.loadIcon(pm), png);
            }
            File tmp = new File(DIR, "apps.tsv.tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                out.write(tsv.toString().getBytes(StandardCharsets.UTF_8));
            }
            tmp.renameTo(new File(DIR, "apps.tsv"));
        } catch (Exception e) {
            Log.w("EmacsHome", "catalog", e);
        }
    }

    private static void save(Drawable icon, File png) throws Exception {
        Bitmap b = Bitmap.createBitmap(ICON_PX, ICON_PX, Bitmap.Config.ARGB_8888);
        icon.setBounds(0, 0, ICON_PX, ICON_PX);
        icon.draw(new Canvas(b));
        try (FileOutputStream out = new FileOutputStream(png)) {
            b.compress(Bitmap.CompressFormat.PNG, 100, out);
        }
    }
}

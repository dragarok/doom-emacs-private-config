package dev.alok.emacshome;

import android.appwidget.AppWidgetHost;
import android.appwidget.AppWidgetHostView;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProviderInfo;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Handler;
import android.util.Log;
import android.view.ContextThemeWrapper;
import android.view.View;
import android.widget.RemoteViews;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Other apps' home-screen widgets, drawn for Emacs to show among the apps:
 *   providers.tsv      (we write)   LABEL \t PROVIDER \t CELLS-WIDE
 *   widgets.tsv        (Emacs)      PROVIDER \t WIDTH-PX \t HEIGHT-PX
 *   widgets/KEY.png    (we write)   each wanted widget as it looks now
 * Hosted by FloatService, which always runs: a provider pushing an update
 * gets its widget drawn again.  Binding one takes a right granted once:
 *   adb shell appwidget grantbind --package dev.alok.emacshome
 */
final class Widgets {
    private static final String TAG = "EmacsHome";
    private static final int HOST_ID = 4719;
    static final File WANTED = new File(Catalog.DIR, "widgets.tsv");
    private static final File OUT = new File(Catalog.DIR, "widgets");

    private final Context ctx;
    private final Handler main;
    private final AppWidgetManager mgr;
    private final AppWidgetHost host;
    private final SharedPreferences ids;
    private final Map<String, AppWidgetHostView> views = new HashMap<>();
    private final Map<String, int[]> sizes = new HashMap<>();

    Widgets(Context c, Handler main) {
        this.ctx = new ContextThemeWrapper(c, android.R.style.Theme_DeviceDefault);
        this.main = main;
        mgr = AppWidgetManager.getInstance(c);
        ids = c.getSharedPreferences("widgets", Context.MODE_PRIVATE);
        host = new AppWidgetHost(c, HOST_ID) {
            @Override
            protected AppWidgetHostView onCreateView(Context cx, int id, AppWidgetProviderInfo info) {
                return new AppWidgetHostView(cx) {
                    @Override public void updateAppWidget(RemoteViews rv) {
                        super.updateAppWidget(rv);
                        main.post(() -> render(this));
                    }
                };
            }
        };
    }

    void start() {
        host.startListening();
        sync();
    }

    void stop() { host.stopListening(); }

    /** The file name a provider's picture goes by. */
    static String key(String provider) { return provider.replaceAll("[^A-Za-z0-9._-]", "_"); }

    /** Every installed widget, for Emacs's pin picker. */
    static void writeProviders(Context c) {
        try {
            PackageManager pm = c.getPackageManager();
            StringBuilder tsv = new StringBuilder();
            for (AppWidgetProviderInfo p : AppWidgetManager.getInstance(c).getInstalledProviders()) {
                String app = pm.getApplicationLabel(pm.getApplicationInfo(p.provider.getPackageName(), 0)).toString();
                // An app's widgets often share one label ("Simple Patro" six
                // times): name each by its class too, TodayMiniWidget -> Today Mini.
                String kind = p.provider.getShortClassName().replaceAll(".*\\.", "")
                        .replaceAll("Widget$", "").replaceAll("([a-z])([A-Z])", "$1 $2");
                String label = (app + ": " + p.loadLabel(pm) + " (" + kind + ")").replaceAll("[\t\n]", " ");
                int cells = Math.max(1, Math.min(4, Math.round((float) p.minWidth / Math.max(1, p.minHeight))));
                tsv.append(label).append('\t').append(p.provider.flattenToString())
                   .append('\t').append(cells).append('\n');
            }
            File tmp = new File(Catalog.DIR, "providers.tsv.tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                out.write(tsv.toString().getBytes(StandardCharsets.UTF_8));
            }
            tmp.renameTo(new File(Catalog.DIR, "providers.tsv"));
        } catch (Exception e) {
            Log.w(TAG, "providers", e);
        }
    }

    /** Bring the hosted widgets in line with widgets.tsv, and draw them. */
    void sync() {
        Set<String> wanted = new HashSet<>();
        try {
            if (WANTED.exists()) {
                for (String line : new String(Files.readAllBytes(WANTED.toPath()), StandardCharsets.UTF_8).split("\n")) {
                    String[] f = line.trim().split("\t");
                    if (f.length < 3) continue;
                    wanted.add(f[0]);
                    sizes.put(f[0], new int[] {Integer.parseInt(f[1]), Integer.parseInt(f[2])});
                    AppWidgetHostView v = view(f[0]);
                    if (v != null) render(v);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "widgets", e);
        }
        // Unpinned: let them go.
        for (String provider : new HashSet<>(ids.getAll().keySet())) {
            if (wanted.contains(provider)) continue;
            host.deleteAppWidgetId(ids.getInt(provider, 0));
            ids.edit().remove(provider).apply();
            views.remove(provider);
            new File(OUT, key(provider) + ".png").delete();
        }
    }

    private AppWidgetHostView view(String provider) {
        AppWidgetHostView v = views.get(provider);
        if (v != null) return v;
        int id = ids.getInt(provider, -1);
        if (id == -1 || mgr.getAppWidgetInfo(id) == null) {
            ComponentName cn = ComponentName.unflattenFromString(provider);
            id = host.allocateAppWidgetId();
            if (cn == null || !mgr.bindAppWidgetIdIfAllowed(id, cn)) {
                host.deleteAppWidgetId(id);
                Log.w(TAG, "can't bind " + provider + " (grantbind over adb?)");
                return null;
            }
            ids.edit().putInt(provider, id).apply();
        }
        v = host.createView(ctx, id, mgr.getAppWidgetInfo(id));
        v.setTag(provider);
        views.put(provider, v);
        return v;
    }

    private void render(AppWidgetHostView v) {
        String provider = (String) v.getTag();
        int[] size = provider == null ? null : sizes.get(provider);
        if (size == null) return;
        // Laid out no smaller than the provider's minimum, keeping the tile's
        // shape: smaller squeezes its text to nothing.  Emacs scales it down.
        AppWidgetProviderInfo info = mgr.getAppWidgetInfo(ids.getInt(provider, -1));
        float scale = info == null ? 1
                : Math.max(1, Math.max((float) info.minWidth / size[0], (float) info.minHeight / size[1]));
        int w = Math.round(size[0] * scale), h = Math.round(size[1] * scale);
        float density = ctx.getResources().getDisplayMetrics().density;
        v.updateAppWidgetSize(null, (int) (w / density), (int) (h / density),
                              (int) (w / density), (int) (h / density));
        v.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                  View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY));
        v.layout(0, 0, w, h);
        Bitmap b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
        v.draw(new Canvas(b));
        try {
            OUT.mkdirs();
            File tmp = new File(OUT, key(provider) + ".png.tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                b.compress(Bitmap.CompressFormat.PNG, 100, out);
            }
            tmp.renameTo(new File(OUT, key(provider) + ".png"));
        } catch (Exception e) {
            Log.w(TAG, "render " + provider, e);
        }
    }
}

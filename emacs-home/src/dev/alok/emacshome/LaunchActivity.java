package dev.alok.emacshome;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Bundle;
import java.util.List;

/**
 * Opens emacs-home://launch/PACKAGE/ACTIVITY.  Any app can send that link,
 * and we run as Termux/Emacs's user, so only a real launcher entry is
 * started -- never one of our own user's unexported activities.
 * emacs-home://hail/ACTION sends Hail one of its own API actions
 * (com.aistra.hail.action.ACTION), from a fixed list.
 */
public class LaunchActivity extends Activity {
    private static final java.util.Set<String> HAIL = new java.util.HashSet<>(java.util.Arrays.asList(
            "FREEZE_ALL", "FREEZE_AUTO", "FREEZE_NON_WHITELISTED", "UNFREEZE_ALL", "LOCK", "LOCK_FREEZE"));

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Uri uri = getIntent().getData();
        List<String> seg = uri == null ? null : uri.getPathSegments();
        if (uri != null && "hail".equals(uri.getHost()) && seg.size() == 1
                && HAIL.contains(seg.get(0))) {
            try {
                startActivity(new Intent("com.aistra.hail.action." + seg.get(0))
                        .setPackage("com.aistra.hail").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (Exception e) {
                android.util.Log.w("EmacsHome", "hail " + seg.get(0), e);
            }
        } else if (uri != null && "launch".equals(uri.getHost()) && seg.size() == 2) {
            Intent launchable = new Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_LAUNCHER).setPackage(seg.get(0));
            for (ResolveInfo ri : getPackageManager().queryIntentActivities(launchable, 0)) {
                if (ri.activityInfo.name.equals(seg.get(1))) {
                    startActivity(launchable.setClassName(seg.get(0), seg.get(1))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                                      | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED));
                    break;
                }
            }
        }
        finish();
    }
}

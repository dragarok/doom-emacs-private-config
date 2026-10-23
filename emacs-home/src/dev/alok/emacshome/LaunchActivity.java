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
 */
public class LaunchActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Uri uri = getIntent().getData();
        List<String> seg = uri == null ? null : uri.getPathSegments();
        if (uri != null && "launch".equals(uri.getHost()) && seg.size() == 2) {
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

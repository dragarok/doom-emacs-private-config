package dev.alok.emacshome;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Intent;
import android.view.accessibility.AccessibilityEvent;

/**
 * Here only so the floating clock's island can sit above the status bar,
 * where it wraps the camera hole: an app overlay sits under the status bar,
 * which takes its taps; an accessibility overlay sits above.  It asks for no
 * events and reads nothing on screen.  Enabled over adb; see build.sh.
 */
public class IslandAccess extends AccessibilityService {
    static volatile IslandAccess instance;

    @Override
    protected void onServiceConnected() {
        AccessibilityServiceInfo info = new AccessibilityServiceInfo();
        info.eventTypes = 0;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        setServiceInfo(info);
        instance = this;
        reattach();
    }

    @Override
    public boolean onUnbind(Intent intent) {
        instance = null;
        reattach();
        return super.onUnbind(intent);
    }

    /** Have the clock re-add its island in the right kind of window. */
    private void reattach() {
        startForegroundService(new Intent(this, FloatService.class).putExtra("action", "reattach"));
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent e) {}
    @Override public void onInterrupt() {}
}

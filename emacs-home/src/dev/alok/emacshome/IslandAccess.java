package dev.alok.emacshome;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.accessibilityservice.InputMethod;
import android.content.Intent;
import android.os.Build;
import android.view.accessibility.AccessibilityEvent;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.SurroundingText;

/**
 * Here so the floating clock's island can sit above the status bar, where
 * it wraps the camera hole (an app overlay sits under the status bar, which
 * takes its taps; an accessibility overlay sits above), and so what you say
 * can be typed into any app: the system hands an accessibility service with
 * flagInputMethodEditor the text field that has the cursor, as it does a
 * keyboard (Android 13+).  It asks for no events and reads nothing on screen.
 * Enabled over adb; see build.sh.
 */
public class IslandAccess extends AccessibilityService {
    static volatile IslandAccess instance;

    @Override
    protected void onServiceConnected() {
        AccessibilityServiceInfo info = getServiceInfo();   // res/xml/island_access.xml
        if (info == null) info = new AccessibilityServiceInfo();
        info.eventTypes = 0;
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC;
        if (Build.VERSION.SDK_INT >= 33) info.flags |= AccessibilityServiceInfo.FLAG_INPUT_METHOD_EDITOR;
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

    private static InputMethod.AccessibilityInputConnection field() {
        IslandAccess a = instance;
        if (a == null || Build.VERSION.SDK_INT < 33) return null;
        InputMethod im = a.getInputMethod();
        return im == null ? null : im.getCurrentInputConnection();
    }

    /** The app whose text field has the cursor, or null when none has. */
    static String editorPackage() {
        if (field() == null) return null;
        EditorInfo e = instance.getInputMethod().getCurrentInputEditorInfo();
        return e == null ? null : e.packageName;
    }

    /** Type TEXT at the cursor, as a keyboard would; false when no field has it.
     *  A space goes before it when it would run into a word. */
    static boolean type(String text) {
        InputMethod.AccessibilityInputConnection c = field();
        if (c == null) return false;
        String t = text;
        try {
            SurroundingText st = c.getSurroundingText(1, 0, 0);
            if (st != null) {
                CharSequence s = st.getText();
                int at = st.getSelectionStart();          // in the text returned
                if (at > 0 && at <= s.length() && !Character.isWhitespace(s.charAt(at - 1))) t = " " + t;
            }
        } catch (Exception e) { /* no surrounding text: as is */ }
        c.commitText(t, 1, null);
        return true;
    }

    @Override public void onAccessibilityEvent(AccessibilityEvent e) {}
    @Override public void onInterrupt() {}
}

package dev.alok.emacshome;

import android.content.Intent;
import android.inputmethodservice.InputMethodService;
import android.os.SystemClock;
import android.view.inputmethod.EditorInfo;

/**
 * Not a keyboard: the keyboard's microphone key.  Keyboards like CleverKeys
 * switch to "the voice input method" when that key is pressed; this is it.
 * It shows nothing, hands straight back to the keyboard, and has the island
 * listen; the words are typed where the cursor is (IslandAccess.type).
 */
public class VoiceIme extends InputMethodService {
    private long last;

    @Override
    public void onStartInput(EditorInfo attribute, boolean restarting) {
        super.onStartInput(attribute, restarting);
        long now = SystemClock.uptimeMillis();
        if (restarting || now - last < 1500) return;
        last = now;
        startForegroundService(new Intent(this, FloatService.class).putExtra("action", "voice-keyboard"));
        switchToPreviousInputMethod();
    }

    @Override public boolean onEvaluateInputViewShown() { return false; }
}

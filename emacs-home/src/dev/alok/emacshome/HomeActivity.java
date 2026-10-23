package dev.alok.emacshome;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

/** The Home button.  Nothing to show: Emacs is the home screen. */
public class HomeActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Intent emacs = getPackageManager().getLaunchIntentForPackage(Emacs.PACKAGE);
        if (emacs != null) startActivity(emacs);
        final Context app = getApplicationContext();
        new Thread(() -> {
            Emacs.eval(app, "(emacs-home-on-home)");
            Catalog.write(app);
        }).start();
        finish();
    }
}

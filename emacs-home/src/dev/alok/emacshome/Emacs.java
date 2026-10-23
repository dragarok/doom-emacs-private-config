package dev.alok.emacshome;

import android.content.Context;
import android.util.Log;
import java.util.concurrent.TimeUnit;

/** Talks to the running Emacs through its own bundled emacsclient. */
final class Emacs {
    static final String PACKAGE = "org.gnu.emacs";

    static void eval(Context c, String form) {
        try {
            String client = c.getPackageManager().getApplicationInfo(PACKAGE, 0)
                    .nativeLibraryDir + "/libemacsclient.so";
            // Emacs's server-socket-dir: its cache dir + emacs<uid>, and we share its uid.
            String socket = "/data/data/" + PACKAGE + "/cache/emacs"
                    + android.os.Process.myUid() + "/server";
            Process p = new ProcessBuilder(client, "-s", socket, "--eval", form)
                    .redirectErrorStream(true).start();
            if (!p.waitFor(10, TimeUnit.SECONDS)) p.destroy();
        } catch (Exception e) {
            Log.w("EmacsHome", "eval " + form, e);
        }
    }
}

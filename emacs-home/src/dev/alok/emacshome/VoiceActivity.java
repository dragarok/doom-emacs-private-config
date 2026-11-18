package dev.alok.emacshome;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.util.Log;
import android.widget.Toast;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Listen once, through the voice app (FUTO's, offline), and hand the words
 * to Emacs.  Started by the toolbar's Voice button (Emacs writes voice-ask,
 * FloatService sees it) or a long press on the clock island.  Not exported:
 * no link or other app can open the microphone through us.
 *
 * The words go in voice-heard.tsv (EPOCH TAB SOURCE TAB TEXT), never into
 * the Lisp we send: Emacs is only told (voice-from-app), which reads the
 * file and picks an action from its own list.  It answers front when it
 * needs to be seen (a question, a pick list), else quiet.
 */
public class VoiceActivity extends Activity {
    static final File HEARD = new File(Catalog.DIR, "voice-heard.tsv");
    private static final int LISTEN = 1;
    private String source = "app";

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        String s = getIntent().getStringExtra("source");
        if (s != null) source = s.replaceAll("[^a-z-]", "");
        if (saved != null) return;   // recreated mid-listen: the result still comes
        Intent listen = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                          RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        String pkg = recognizer(listen);
        if (pkg != null) listen.setPackage(pkg);
        try {
            startActivityForResult(listen, LISTEN);
        } catch (ActivityNotFoundException e) {
            Toast.makeText(this, "No voice input app", Toast.LENGTH_LONG).show();
            finish();
        }
    }

    /** The FUTO voice app when installed, else whatever handles the intent. */
    private String recognizer(Intent listen) {
        List<ResolveInfo> all = getPackageManager().queryIntentActivities(listen, 0);
        for (ResolveInfo r : all)
            if (r.activityInfo.packageName.startsWith("org.futo.voiceinput"))
                return r.activityInfo.packageName;
        return null;
    }

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        String text = null;
        if (request == LISTEN && result == RESULT_OK && data != null) {
            ArrayList<String> heard = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            if (heard != null && !heard.isEmpty()) text = heard.get(0);
        }
        finish();
        if (text == null || text.trim().isEmpty()) return;
        final String line = (System.currentTimeMillis() / 1000) + "\t" + source + "\t"
                + text.replaceAll("[\\t\\r\\n]+", " ").trim() + "\n";
        final Context app = getApplicationContext();
        new Thread(() -> deliver(app, line)).start();
    }

    /** Write what was heard and tell Emacs; start Emacs if it isn't up.
     *  Also the island's Yes and No, as if said (FloatService.answer).
     *  LINE is EPOCH TAB SOURCE TAB TEXT, then the engine's other readings,
     *  a tab before each.  Returns Emacs's reply: front (it brought itself
     *  forward), type (type the words where the cursor is), quiet, or null. */
    static String deliver(Context c, String line) {
        try (FileOutputStream f = new FileOutputStream(HEARD, false)) {
            f.write(line.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            Log.w("EmacsHome", "voice-heard", e);
            return null;
        }
        String reply = Emacs.evalReply(c, "(voice-from-app)");
        for (int i = 0; reply == null && i < 15; i++) {
            if (i == 0) front(c);
            try { Thread.sleep(1000); } catch (InterruptedException e) { return null; }
            reply = Emacs.evalReply(c, "(voice-from-app)");
        }
        if (reply != null && reply.contains("front")) front(c);
        return reply;
    }

    private static void front(Context c) {
        Intent emacs = c.getPackageManager().getLaunchIntentForPackage(Emacs.PACKAGE);
        if (emacs != null) c.startActivity(emacs.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }
}

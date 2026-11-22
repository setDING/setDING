package app.setding

import android.content.Intent
import android.os.Build
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** The folder of the automatic backup (ADR-0054). */
    private var backupFolder: BackupFolderChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    /**
     * Keeps the Flutter view focused, so the first key of a Bluetooth page
     * turner reaches Flutter (ADR-0007, issue #663).
     *
     * After a touch, Android is in touch mode. A navigation key (arrows,
     * Page Up/Down, Space, Enter) makes it leave touch mode, and when no view
     * has the focus then, Android gives it to the Flutter view and consumes
     * the key: the first press only showed the system's focus frame around
     * the whole screen. With the Flutter view already focused, Android keeps
     * that focus and passes the key on.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        val view = findViewById<View>(FLUTTER_VIEW_ID) ?: return
        view.isFocusable = true
        view.isFocusableInTouchMode = true
        // Flutter draws its own focus indicators; the system frame around the
        // whole screen means nothing to the user. The themes in styles.xml
        // disable it from the start; this also covers views created later.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.defaultFocusHighlightEnabled = false
        }
        if (!view.hasFocus()) view.requestFocus()
    }
}

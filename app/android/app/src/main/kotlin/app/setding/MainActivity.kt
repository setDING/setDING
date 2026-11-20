package app.setding

import android.os.Build
import android.view.View
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
        // whole screen means nothing to the user.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.defaultFocusHighlightEnabled = false
        }
        if (!view.hasFocus()) view.requestFocus()
    }
}

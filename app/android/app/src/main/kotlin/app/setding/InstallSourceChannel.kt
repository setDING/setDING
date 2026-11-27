package app.setding

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Which app installed setDING (ADR-0067): `installer` answers the package
 * name of the installing store, e.g. `com.android.vending` for Google Play,
 * or null (Obtainium, adb, a file manager). The update hint (ADR-0036)
 * points Play installs to Google Play.
 */
class InstallSourceChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    init {
        MethodChannel(messenger, "app.setding/install_source")
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installer" -> result.success(installer())
            else -> result.notImplemented()
        }
    }

    private fun installer(): String? = try {
        val pm = context.packageManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(context.packageName)
        }
    } catch (e: Exception) {
        null
    }
}

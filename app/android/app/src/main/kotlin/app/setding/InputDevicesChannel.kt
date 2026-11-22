package app.setding

import android.content.Context
import android.hardware.input.InputManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The keyboards of the device for pairing the page turner (ADR-0057): the
 * connected external keyboards (`devices`), and on the event channel the
 * device of every key pressed down (`key`) and connects and disconnects
 * (`changed`). It only observes: keys reach Flutter unchanged.
 */
class InputDevicesChannel(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    InputManager.InputDeviceListener {
    private val inputManager =
        context.getSystemService(Context.INPUT_SERVICE) as InputManager
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "app.setding/input_devices")
            .setMethodCallHandler(this)
        EventChannel(messenger, "app.setding/input_devices/events")
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "devices" -> result.success(
                InputDevice.getDeviceIds().toList()
                    .mapNotNull { InputDevice.getDevice(it) }
                    .filter(::isExternalKeyboard)
                    .map(::describe),
            )
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        inputManager.registerInputDeviceListener(this, main)
    }

    override fun onCancel(arguments: Any?) {
        inputManager.unregisterInputDeviceListener(this)
        sink = null
    }

    /** From [MainActivity.dispatchKeyEvent], before Flutter sees the key. */
    fun onKey(event: KeyEvent) {
        val sink = sink ?: return
        if (event.action != KeyEvent.ACTION_DOWN || event.repeatCount > 0) return
        val device = event.device ?: return
        if (!isExternalKeyboard(device)) return
        sink.success(mapOf("type" to "key", "device" to describe(device)))
    }

    override fun onInputDeviceAdded(deviceId: Int) = changed()

    override fun onInputDeviceRemoved(deviceId: Int) = changed()

    override fun onInputDeviceChanged(deviceId: Int) = changed()

    private fun changed() {
        sink?.success(mapOf("type" to "changed"))
    }

    private fun describe(device: InputDevice): Map<String, Any> = mapOf(
        "name" to device.name,
        "vendorId" to device.vendorId,
        "productId" to device.productId,
    )

    /**
     * A keyboard that is not virtual (the on-screen keyboard) and, where
     * Android tells (10+), not built in (volume keys, a cover keyboard).
     */
    private fun isExternalKeyboard(device: InputDevice): Boolean {
        if (device.isVirtual) return false
        if (device.sources and InputDevice.SOURCE_KEYBOARD != InputDevice.SOURCE_KEYBOARD) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) return device.isExternal
        return true
    }
}

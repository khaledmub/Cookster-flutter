package com.cookster.cooksterapp

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Single-shot render telemetry for feed reels — slot-scoped by [playerHandle].
 * Stall timers run on the main [Handler]; no polling stream.
 */
class CooksterReelRenderPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val CONTROL_CHANNEL = "com.cookster.cooksterapp/reel_render_control"
        const val EVENT_CHANNEL = "com.cookster.cooksterapp/reel_render"
        private const val TAG = "CooksterReelRender"
        private const val STALL_MS_A = 250L
        private const val TIMEOUT_MS = 280L
    }

    private var controlChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private data class SlotWatch(
        val slotIndex: Int,
        val playerHandle: Long,
        val firstFrameFired: AtomicBoolean = AtomicBoolean(false),
        val stallFired: AtomicBoolean = AtomicBoolean(false),
        var stallRunnableA: Runnable? = null,
        var timeoutRunnable: Runnable? = null,
    )

    private val slots = ConcurrentHashMap<Long, SlotWatch>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controlChannel =
            MethodChannel(binding.binaryMessenger, CONTROL_CHANNEL).also {
                it.setMethodCallHandler(this)
            }
        eventChannel =
            EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also {
                it.setStreamHandler(this)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controlChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        slots.values.forEach { cancelTimers(it) }
        slots.clear()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "registerSlot" -> {
                val slotIndex = call.argument<Int>("slotIndex") ?: 0
                val handle = call.argument<Number>("playerHandle")?.toLong() ?: 0L
                if (handle != 0L) {
                    slots[handle] = SlotWatch(slotIndex, handle)
                }
                result.success(null)
            }
            "unregisterSlot" -> {
                val handle = call.argument<Number>("playerHandle")?.toLong() ?: 0L
                slots.remove(handle)?.let { cancelTimers(it) }
                result.success(null)
            }
            "surfaceRevealed" -> {
                val handle = call.argument<Number>("playerHandle")?.toLong() ?: 0L
                val watch = slots[handle]
                if (watch != null) {
                    scheduleStallTimers(watch)
                }
                result.success(null)
            }
            "notifySurfaceCleanup" -> {
                val handle = call.argument<Number>("playerHandle")?.toLong() ?: 0L
                emitStall(slots[handle], "b")
                result.success(null)
            }
            "notifyFirstFrame" -> {
                val handle = call.argument<Number>("playerHandle")?.toLong() ?: 0L
                val watch = slots[handle]
                if (watch != null) {
                    emitFirstFrame(watch)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleStallTimers(watch: SlotWatch) {
        cancelTimers(watch)
        watch.stallRunnableA = Runnable {
            if (!watch.firstFrameFired.get() && watch.stallFired.compareAndSet(false, true)) {
                emitPayload(
                    type = "stall",
                    signature = "a",
                    watch = watch,
                )
            }
        }
        watch.timeoutRunnable = Runnable {
            if (!watch.firstFrameFired.get() && watch.stallFired.compareAndSet(false, true)) {
                emitPayload(
                    type = "stall",
                    signature = "timeout",
                    watch = watch,
                )
            }
        }
        handler.postDelayed(watch.stallRunnableA!!, STALL_MS_A)
        handler.postDelayed(watch.timeoutRunnable!!, TIMEOUT_MS)
    }

    private fun emitFirstFrame(watch: SlotWatch) {
        if (!watch.firstFrameFired.compareAndSet(false, true)) {
            return
        }
        cancelTimers(watch)
        emitPayload(type = "firstFrame", signature = null, watch = watch)
    }

    private fun emitStall(watch: SlotWatch?, signature: String) {
        if (watch == null) {
            return
        }
        if (!watch.firstFrameFired.get() && watch.stallFired.compareAndSet(false, true)) {
            cancelTimers(watch)
            emitPayload(type = "stall", signature = signature, watch = watch)
        }
    }

    private fun cancelTimers(watch: SlotWatch) {
        watch.stallRunnableA?.let { handler.removeCallbacks(it) }
        watch.timeoutRunnable?.let { handler.removeCallbacks(it) }
        watch.stallRunnableA = null
        watch.timeoutRunnable = null
    }

    private fun emitPayload(type: String, signature: String?, watch: SlotWatch) {
        val payload = HashMap<String, Any>()
        payload["type"] = type
        payload["slotIndex"] = watch.slotIndex
        payload["playerHandle"] = watch.playerHandle
        payload["tsMs"] = System.currentTimeMillis()
        if (signature != null) {
            payload["signature"] = signature
        }
        val sig = signature ?: "-"
        Log.i(
            TAG,
            "emit type=$type sig=$sig slot=${watch.slotIndex} handle=${watch.playerHandle}",
        )
        handler.post { eventSink?.success(payload) }
    }
}

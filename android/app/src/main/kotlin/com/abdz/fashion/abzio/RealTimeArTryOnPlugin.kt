package com.abdz.fashion.abzio

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.FrameLayout
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.util.UUID

class RealTimeArTryOnPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, "abzora/realtime_ar_try_on")
    private val eventChannel = EventChannel(messenger, "abzora/realtime_ar_try_on/events")
    private var eventSink: EventChannel.EventSink? = null
    private var lastConfig: Map<String, Any?> = emptyMap()
    private val activeViews = LinkedHashSet<RealTimeArTryOnView>()

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun registerViews(registry: FlutterPlugin.PlatformViewRegistry) {
        registry.registerViewFactory(
            "abzora/native_ar_try_on_view",
            RealTimeArTryOnViewFactory(context) { view ->
                activeViews.add(view)
                if (lastConfig.isNotEmpty()) {
                    view.applyConfig(lastConfig)
                }
            }
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize", "updateGarment" -> {
                @Suppress("UNCHECKED_CAST")
                lastConfig = call.arguments<Map<String, Any?>>() ?: emptyMap()
                activeViews.forEach { it.applyConfig(lastConfig) }
                emitRenderEvent("configured")
                result.success(null)
            }
            "updatePoseFrame" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments<Map<String, Any?>>() ?: emptyMap()
                activeViews.forEach { it.updatePose(args) }
                emitRenderEvent("pose_updated")
                result.success(null)
            }
            "setCameraFacing" -> {
                emitRenderEvent("camera_switched")
                result.success(null)
            }
            "capturePreview" -> {
                val previewPath = "${context.cacheDir.absolutePath}\\ar_preview_${UUID.randomUUID()}.jpg"
                emitRenderEvent("capture_requested")
                result.success(previewPath)
            }
            "dispose" -> {
                lastConfig = emptyMap()
                activeViews.forEach { it.reset() }
                emitRenderEvent("disposed")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emitRenderEvent(state: String) {
        eventSink?.success(
            mapOf(
                "state" to state,
                "renderer" to "android_native_hybrid",
                "occlusionEnabled" to (lastConfig["enableOcclusion"] as? Boolean ?: false),
                "arCoreSupported" to isArCoreSupported(),
                "timestampMs" to System.currentTimeMillis()
            )
        )
    }

    private fun isArCoreSupported(): Boolean {
        return try {
            ArCoreApk.getInstance().checkAvailability(context).isSupported
        } catch (_: Throwable) {
            false
        }
    }
}

private class RealTimeArTryOnViewFactory(
    private val context: Context,
    private val onCreated: (RealTimeArTryOnView) -> Unit
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {
        @Suppress("UNCHECKED_CAST")
        return RealTimeArTryOnView(context, args as? Map<String, Any?> ?: emptyMap()).also(onCreated)
    }
}

private class RealTimeArTryOnView(
    context: Context,
    private val params: Map<String, Any?>
) : PlatformView {
    private val rootView = FrameLayout(context).apply {
        setBackgroundColor(Color.TRANSPARENT)
        clipChildren = false
        clipToPadding = false
    }
    private val renderer = HybridArGarmentRenderer(context, rootView)

    init {
        applyConfig(params)
    }

    override fun getView(): View = rootView

    override fun dispose() {
        renderer.dispose()
    }

    fun applyConfig(config: Map<String, Any?>) {
        renderer.applyConfig(config)
    }

    fun updatePose(args: Map<String, Any?>) {
        renderer.updatePose(args)
    }

    fun reset() {
        renderer.reset()
    }
}

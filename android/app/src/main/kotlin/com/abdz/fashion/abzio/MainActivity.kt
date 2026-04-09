package com.abdz.fashion.abzio

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode = RenderMode.texture

    private lateinit var mediaPipePoseBridge: MediaPipePoseBridge
    private lateinit var realTimeArTryOnPlugin: RealTimeArTryOnPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaPipePoseBridge = MediaPipePoseBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        realTimeArTryOnPlugin = RealTimeArTryOnPlugin(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        realTimeArTryOnPlugin.registerViews(flutterEngine.platformViewsController.registry)
    }

    override fun onDestroy() {
        if (::mediaPipePoseBridge.isInitialized) {
            mediaPipePoseBridge.dispose()
        }
        super.onDestroy()
    }
}

package com.abdz.fashion.abzio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Path
import java.io.File
import java.io.FileOutputStream
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.webkit.WebView
import android.webkit.WebSettings
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

internal class HybridArGarmentRenderer(
    context: Context,
    private val rootView: FrameLayout
) {
    private val executor = Executors.newSingleThreadExecutor()
    private val garmentView = OccludingGarmentImageView(context).apply {
      scaleType = ImageView.ScaleType.FIT_CENTER
      alpha = 0f
    }
    private val glbView = WebView(context).apply {
      setBackgroundColor(Color.TRANSPARENT)
      alpha = 0f
      settings.apply {
        javaScriptEnabled = true
        cacheMode = WebSettings.LOAD_DEFAULT
        domStorageEnabled = true
        mediaPlaybackRequiresUserGesture = false
      }
    }
    private var garmentBitmap: Bitmap? = null
    private var glbMode = false

    init {
      // Flutter owns the camera preview so camera switching stays consistent.
      // This native view is intentionally garment/compositing-only.
      rootView.addView(
        garmentView,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.WRAP_CONTENT,
          ViewGroup.LayoutParams.WRAP_CONTENT
        )
      )
      rootView.addView(
        glbView,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.WRAP_CONTENT,
          ViewGroup.LayoutParams.WRAP_CONTENT
        )
      )
    }

    fun applyConfig(config: Map<String, Any?>) {
      val overlayAssetUrl =
        config["transparentAssetUrl"]?.toString()?.takeIf { it.isNotBlank() }
          ?: config["overlayAssetUrl"]?.toString()?.takeIf { it.isNotBlank() }
          ?: config["model3dUrl"]?.toString()?.takeIf { it.isNotBlank() }
          ?: return
      val model3dUrl = config["model3dUrl"]?.toString()?.trim().orEmpty()
      if (model3dUrl.endsWith(".glb", ignoreCase = true) || model3dUrl.endsWith(".gltf", ignoreCase = true)) {
        glbMode = true
        garmentView.alpha = 0f
        loadGlbModel(model3dUrl)
      } else {
        glbMode = false
        glbView.alpha = 0f
        loadOverlayBitmap(overlayAssetUrl)
      }
    }

    fun updatePose(args: Map<String, Any?>) {
      val viewportWidth = (args["viewportWidth"] as? Number)?.toFloat() ?: rootView.width.toFloat()
      val viewportHeight = (args["viewportHeight"] as? Number)?.toFloat() ?: rootView.height.toFloat()
      @Suppress("UNCHECKED_CAST")
      val poseFrame = args["poseFrame"] as? Map<String, Any?> ?: return
      if (viewportWidth <= 0f || viewportHeight <= 0f) {
        return
      }
      val bodyDetected = args["bodyDetected"] as? Boolean ?: true
      val segmentationConfidence =
        (poseFrame["segmentationConfidence"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.5f
      val renderQuality =
        (poseFrame["renderQuality"] as? Number)?.toFloat()?.coerceIn(0.35f, 1f) ?: 0.8f
      val occlusionEnabled = poseFrame["occlusionEnabled"] as? Boolean ?: false
      val garmentAlignment = mapOfAny(poseFrame["garmentAlignment"])
      val garmentDeformation = mapOfAny(poseFrame["garmentDeformation"])
      val arCompositing = mapOfAny(poseFrame["arCompositing"])
      if (!bodyDetected) {
        if (glbMode) {
          glbView.animate().alpha(0.28f).setDuration(120).start()
        } else {
          garmentView.animate().alpha(0.32f).setDuration(120).start()
        }
        return
      }

      val leftShoulder = posePoint(poseFrame["leftShoulder"])
      val rightShoulder = posePoint(poseFrame["rightShoulder"])
      val leftHip = posePoint(poseFrame["leftHip"])
      val rightHip = posePoint(poseFrame["rightHip"])
      if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
        return
      }

      val shoulderMidX = (leftShoulder.first + rightShoulder.first) / 2f
      val shoulderMidY = (leftShoulder.second + rightShoulder.second) / 2f
      val hipMidX = (leftHip.first + rightHip.first) / 2f
      val hipMidY = (leftHip.second + rightHip.second) / 2f
      val shoulderDistance = distance(leftShoulder, rightShoulder)
      val torsoDistance = distance(shoulderMidX to shoulderMidY, hipMidX to hipMidY)
      val alignmentScales = mapOfAny(garmentAlignment?.get("scales"))
      val deformationTorso = mapOfAny(garmentDeformation?.get("torso"))
      val shoulderScale = numberOf(alignmentScales?.get("shoulder"), 1f).coerceIn(0.78f, 1.28f)
      val chestScale = numberOf(alignmentScales?.get("chest"), 1f).coerceIn(0.8f, 1.26f)
      val torsoScale = numberOf(alignmentScales?.get("torso"), 1f).coerceIn(0.78f, 1.3f)
      val waistScale = numberOf(alignmentScales?.get("waist"), 1f).coerceIn(0.76f, 1.26f)
      val hipScale = numberOf(alignmentScales?.get("hip"), 1f).coerceIn(0.78f, 1.28f)
      val torsoScaleX = numberOf(deformationTorso?.get("scaleX"), 1f).coerceIn(0.82f, 1.2f)
      val torsoScaleY = numberOf(deformationTorso?.get("scaleY"), 1f).coerceIn(0.82f, 1.2f)
      val widthScale = ((shoulderScale * 0.45f) + (chestScale * 0.35f) + (torsoScaleX * 0.2f))
      val heightScale =
        ((torsoScale * 0.35f) + (waistScale * 0.25f) + (hipScale * 0.2f) + (torsoScaleY * 0.2f))
      val width = (min(viewportWidth * 0.92f, max(viewportWidth * 0.18f, shoulderDistance * 1.25f)) * widthScale)
      val height = (min(viewportHeight * 0.9f, max(viewportHeight * 0.18f, torsoDistance * 1.58f)) * heightScale)
      val rotation = Math.toDegrees(
        atan2(
          (rightShoulder.second - leftShoulder.second).toDouble(),
          (rightShoulder.first - leftShoulder.first).toDouble()
        )
      ).toFloat()
      val anchors = mapOfAny(garmentAlignment?.get("anchors"))
      val centerAnchor = posePoint(anchors?.get("center"))
      val centerX = centerAnchor?.first ?: shoulderMidX
      val centerY = (centerAnchor?.second ?: shoulderMidY) + (height * 0.12f)
      val layeringConfidence = numberOf(arCompositing?.get("layeringConfidence"), 0.5f).coerceIn(0f, 1f)
      val overlapBlend = numberOf(arCompositing?.get("overlapBlend"), 0.55f).coerceIn(0.2f, 0.96f)
      val shadowOpacity = numberOf(arCompositing?.get("shadowOpacity"), 0.14f).coerceIn(0.08f, 0.3f)
      val contactShadowOpacity = numberOf(arCompositing?.get("contactShadowOpacity"), 0.18f).coerceIn(0.1f, 0.36f)
      val shadowSoftness = numberOf(arCompositing?.get("shadowSoftness"), 0.5f).coerceIn(0.36f, 0.86f)
      val depthSeparation = numberOf(arCompositing?.get("depthSeparation"), 0.3f).coerceIn(0.18f, 0.62f)

      rootView.post {
        val target = if (glbMode) glbView else garmentView
        val layoutParams = target.layoutParams as FrameLayout.LayoutParams
        layoutParams.width = width.toInt()
        layoutParams.height = height.toInt()
        target.layoutParams = layoutParams
        target.x = centerX - (width / 2f)
        target.y = centerY - (height / 2f)
        target.rotation = rotation
        target.alpha =
          ((0.56f + (segmentationConfidence * 0.2f) + (layeringConfidence * 0.2f)) * renderQuality)
            .coerceIn(0.18f, 1f)
        target.translationZ = depthSeparation * 12f
        if (!glbMode) {
          garmentView.updateOcclusion(
            enabled = occlusionEnabled,
            leftShoulder = leftShoulder,
            rightShoulder = rightShoulder,
            leftHip = leftHip,
            rightHip = rightHip,
            viewX = garmentView.x,
            viewY = garmentView.y,
            overlapBlend = overlapBlend,
            shadowOpacity = shadowOpacity,
            contactShadowOpacity = contactShadowOpacity,
            shadowSoftness = shadowSoftness
          )
        }
      }
    }

    fun reset() {
      rootView.post {
        garmentView.alpha = 0f
        glbView.alpha = 0f
      }
    }

    fun pause() {
      // Camera preview is owned by Flutter.
    }

    fun resume() {
      // Camera preview is owned by Flutter.
    }

    fun setCameraFacing(front: Boolean) {
      // Camera preview is owned by Flutter.
    }

    fun dispose() {
      executor.shutdownNow()
      garmentBitmap?.recycle()
      glbView.stopLoading()
      glbView.destroy()
      rootView.removeAllViews()
    }

    fun capturePreview(path: String): Boolean {
      return try {
        if (rootView.width <= 0 || rootView.height <= 0) {
          return false
        }
        val bitmap = Bitmap.createBitmap(rootView.width, rootView.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        rootView.draw(canvas)
        val file = File(path)
        file.parentFile?.mkdirs()
        FileOutputStream(file).use { out ->
          bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
          out.flush()
        }
        bitmap.recycle()
        true
      } catch (_: Throwable) {
        false
      }
    }

    private fun loadOverlayBitmap(url: String) {
      if (url.endsWith(".glb", ignoreCase = true) || url.endsWith(".gltf", ignoreCase = true)) {
        rootView.post {
          garmentView.setImageDrawable(null)
          garmentView.setBackgroundColor(Color.argb(40, 206, 176, 106))
          garmentView.alpha = 0.55f
        }
        return
      }
      executor.execute {
        try {
          URL(url).openStream().use { stream ->
            val decoded = BitmapFactory.decodeStream(stream) ?: return@use
            val bitmap = if (decoded.config == Bitmap.Config.ARGB_8888) {
              decoded
            } else {
              decoded.copy(Bitmap.Config.ARGB_8888, false)
            }
            rootView.post {
              garmentBitmap?.recycle()
              garmentBitmap = bitmap
              garmentView.setBackgroundColor(Color.TRANSPARENT)
              garmentView.setImageBitmap(bitmap)
            }
          }
        } catch (_: Throwable) {
          rootView.post {
            garmentView.setImageDrawable(null)
            garmentView.setBackgroundColor(Color.argb(38, 255, 255, 255))
            garmentView.alpha = max(garmentView.alpha, 0.35f)
          }
        }
      }
    }

    private fun loadGlbModel(modelUrl: String) {
      val html = """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <script type="module" src="https://unpkg.com/@google/model-viewer/dist/model-viewer.min.js"></script>
            <style>
              html, body { margin:0; padding:0; background:transparent; overflow:hidden; }
              model-viewer { width:100vw; height:100vh; background:transparent; }
            </style>
          </head>
          <body>
            <model-viewer src="$modelUrl" ar ar-modes="webxr scene-viewer" camera-controls auto-rotate shadow-intensity="0.6" exposure="1"></model-viewer>
          </body>
        </html>
      """.trimIndent()
      rootView.post {
        glbView.loadDataWithBaseURL("https://abzora.app/", html, "text/html", "utf-8", null)
        glbView.alpha = 0.58f
      }
    }

    private fun posePoint(raw: Any?): Pair<Float, Float>? {
      val point = raw as? Map<*, *> ?: return null
      val x = (point["x"] as? Number)?.toFloat() ?: return null
      val y = (point["y"] as? Number)?.toFloat() ?: return null
      return x to y
    }

    private fun distance(start: Pair<Float, Float>, end: Pair<Float, Float>): Float {
      val dx = end.first - start.first
      val dy = end.second - start.second
      return sqrt((dx * dx) + (dy * dy))
    }

    private fun mapOfAny(raw: Any?): Map<String, Any?>? {
      @Suppress("UNCHECKED_CAST")
      return raw as? Map<String, Any?>
    }

    private fun numberOf(raw: Any?, fallback: Float): Float {
      return (raw as? Number)?.toFloat() ?: fallback
    }
}

private class OccludingGarmentImageView(context: Context) : ImageView(context) {
  private val clipPath = Path()
  private val shadowPaint = android.graphics.Paint().apply {
    style = android.graphics.Paint.Style.FILL
    isAntiAlias = true
  }
  private var overlapBlend = 0.55f
  private var shadowOpacity = 0.14f
  private var contactShadowOpacity = 0.18f
  private var shadowSoftness = 0.5f
  private var hasClip = false

  fun updateOcclusion(
    enabled: Boolean,
    leftShoulder: Pair<Float, Float>,
    rightShoulder: Pair<Float, Float>,
    leftHip: Pair<Float, Float>,
    rightHip: Pair<Float, Float>,
    viewX: Float,
    viewY: Float,
    overlapBlend: Float,
    shadowOpacity: Float,
    contactShadowOpacity: Float,
    shadowSoftness: Float
  ) {
    hasClip = enabled
    this.overlapBlend = overlapBlend.coerceIn(0.2f, 0.96f)
    this.shadowOpacity = shadowOpacity.coerceIn(0.08f, 0.3f)
    this.contactShadowOpacity = contactShadowOpacity.coerceIn(0.1f, 0.36f)
    this.shadowSoftness = shadowSoftness.coerceIn(0.36f, 0.86f)
    clipPath.reset()
    if (enabled) {
      val shoulderPad = width * (0.06f + ((1f - this.overlapBlend) * 0.04f))
      val hipPad = width * (0.05f + ((1f - this.overlapBlend) * 0.03f))
      clipPath.moveTo(leftShoulder.first - viewX - shoulderPad, leftShoulder.second - viewY)
      clipPath.lineTo(rightShoulder.first - viewX + shoulderPad, rightShoulder.second - viewY)
      clipPath.lineTo(rightHip.first - viewX + hipPad, rightHip.second - viewY + (height * 0.12f))
      clipPath.lineTo(leftHip.first - viewX - hipPad, leftHip.second - viewY + (height * 0.12f))
      clipPath.close()
    }
    invalidate()
  }

  override fun onDraw(canvas: Canvas) {
    val shadowAlpha = ((shadowOpacity * 255f).toInt()).coerceIn(0, 255)
    shadowPaint.color = Color.argb(shadowAlpha, 18, 18, 20)
    shadowPaint.maskFilter =
      android.graphics.BlurMaskFilter((22f * shadowSoftness).coerceAtLeast(8f), android.graphics.BlurMaskFilter.Blur.NORMAL)
    canvas.drawOval(
      width * 0.18f,
      height * 0.12f,
      width * 0.82f,
      height * 0.96f,
      shadowPaint
    )
    shadowPaint.maskFilter = null
    shadowPaint.color =
      Color.argb(((contactShadowOpacity * 255f).toInt()).coerceIn(0, 255), 12, 12, 14)
    canvas.drawRect(width * 0.24f, height * 0.32f, width * 0.76f, height * 0.84f, shadowPaint)

    if (!hasClip || clipPath.isEmpty) {
      super.onDraw(canvas)
      return
    }
    val checkpoint = canvas.save()
    canvas.clipPath(clipPath)
    super.onDraw(canvas)
    canvas.restoreToCount(checkpoint)
  }
}

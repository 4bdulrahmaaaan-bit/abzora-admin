package com.abdz.fashion.abzio

import android.content.Context
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Path
import android.util.Base64
import java.io.File
import java.io.FileOutputStream
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.webkit.WebView
import android.webkit.WebSettings
import android.webkit.WebChromeClient
import android.webkit.WebViewClient
import android.util.Log
import java.net.URL
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

internal class HybridArGarmentRenderer(
    context: Context,
    private val rootView: FrameLayout
) {
    private val executor = Executors.newSingleThreadExecutor()
    private val depthShadowView = BodyAwareGarmentShadowView(context).apply {
      alpha = 0f
    }
    private val garmentView = OccludingGarmentImageView(context).apply {
      scaleType = ImageView.ScaleType.FIT_CENTER
      alpha = 0f
    }
    private val glbView = GarmentModelWebView(context).apply {
      setBackgroundColor(Color.TRANSPARENT)
      alpha = 0f
      webViewClient = object : WebViewClient() {
        override fun onPageFinished(view: WebView?, url: String?) {
          super.onPageFinished(view, url)
          Log.d("ABZORA_GLB", "page finished: $url")
        }

        override fun onReceivedError(
          view: WebView?,
          request: android.webkit.WebResourceRequest?,
          error: android.webkit.WebResourceError?
        ) {
          super.onReceivedError(view, request, error)
          Log.e("ABZORA_GLB", "web error: ${error?.errorCode} ${error?.description}")
        }
      }
      webChromeClient = object : WebChromeClient() {
        override fun onConsoleMessage(consoleMessage: android.webkit.ConsoleMessage): Boolean {
          Log.d(
            "ABZORA_GLB",
            "console: ${consoleMessage.message()} @${consoleMessage.lineNumber()} ${consoleMessage.sourceId()}"
          )
          return true
        }
      }
      settings.apply {
        javaScriptEnabled = true
        cacheMode = WebSettings.LOAD_DEFAULT
        domStorageEnabled = true
        mediaPlaybackRequiresUserGesture = false
        loadWithOverviewMode = true
        useWideViewPort = true
        allowFileAccess = true
        allowContentAccess = true
        allowFileAccessFromFileURLs = true
        allowUniversalAccessFromFileURLs = true
        mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
      }
    }
    private var garmentBitmap: Bitmap? = null
    private var glbMode = false
    private var editorOffsetX = 0f
    private var editorOffsetY = 0f
    private var editorScale = 1f
    private var editorRotationRadians = 0f
    private var garmentShoulderAnchorSpan = 0.34f
    private var lastGarmentX = Float.NaN
    private var lastGarmentY = Float.NaN
    private var lastGarmentWidth = Float.NaN
    private var lastGarmentHeight = Float.NaN
    private var lastGarmentRotation = Float.NaN
    private var lastGarmentScaleX = Float.NaN
    private var lastGarmentScaleY = Float.NaN

    init {
      // Flutter owns the camera preview so camera switching stays consistent.
      // This native view is intentionally garment/compositing-only.
      rootView.addView(
        depthShadowView,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.WRAP_CONTENT,
          ViewGroup.LayoutParams.WRAP_CONTENT
        )
      )
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
          ViewGroup.LayoutParams.MATCH_PARENT,
          ViewGroup.LayoutParams.MATCH_PARENT
        )
      )
    }

    fun applyConfig(config: Map<String, Any?>) {
      applyFitEditorConfig(config)
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
        rootView.post { placeDefaultGarment(glbView, 0.68f) }
      } else {
        glbMode = false
        glbView.alpha = 0f
        loadOverlayBitmap(overlayAssetUrl)
        rootView.post { placeDefaultGarment(garmentView, 0.48f) }
      }
    }

    fun updatePose(args: Map<String, Any?>) {
      val viewportWidth = rootView.width.toFloat()
      val viewportHeight = rootView.height.toFloat()
      @Suppress("UNCHECKED_CAST")
      val poseFrame = args["poseFrame"] as? Map<String, Any?> ?: return
      if (viewportWidth <= 0f || viewportHeight <= 0f) {
        return
      }
      val bodyDetected = args["bodyDetected"] as? Boolean ?: true
      val segmentationConfidence =
        (poseFrame["segmentationConfidence"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.5f
      val edgeSmoothing =
        (poseFrame["edgeSmoothing"] as? Number)?.toFloat()?.coerceIn(0.18f, 0.82f) ?: 0.5f
      val edgeStability =
        (poseFrame["edgeStability"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.6f
      val maskAlpha =
        (poseFrame["maskAlpha"] as? Number)?.toFloat()?.coerceIn(0.28f, 0.9f) ?: 0.7f
      val armOverlapConfidence =
        (poseFrame["armOverlapConfidence"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.55f
      val motionQuality =
        (poseFrame["motionQuality"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.72f
      val torsoMaskConfidence =
        (poseFrame["torsoMaskConfidence"] as? Number)?.toFloat()?.coerceIn(0f, 1f) ?: 0.6f
      val renderQuality =
        (poseFrame["renderQuality"] as? Number)?.toFloat()?.coerceIn(0.35f, 1f) ?: 0.8f
      val occlusionEnabled = poseFrame["occlusionEnabled"] as? Boolean ?: false
      val garmentAlignment = mapOfAny(poseFrame["garmentAlignment"])
      val garmentDeformation = mapOfAny(poseFrame["garmentDeformation"])
      val arCompositing = mapOfAny(poseFrame["arCompositing"])
      if (!bodyDetected) {
        rootView.post {
          placeDefaultGarment(if (glbMode) glbView else garmentView, if (glbMode) 0.46f else 0.38f)
        }
        if (glbMode) {
          glbView.animate().alpha(0.28f).setDuration(120).start()
        } else {
          garmentView.animate().alpha(0.32f).setDuration(120).start()
        }
        return
      }

      val leftShoulder = posePoint(poseFrame["leftShoulder"], viewportWidth, viewportHeight)
      val rightShoulder = posePoint(poseFrame["rightShoulder"], viewportWidth, viewportHeight)
      val leftElbow = posePoint(poseFrame["leftElbow"], viewportWidth, viewportHeight)
      val rightElbow = posePoint(poseFrame["rightElbow"], viewportWidth, viewportHeight)
      val leftWrist = posePoint(poseFrame["leftWrist"], viewportWidth, viewportHeight)
      val rightWrist = posePoint(poseFrame["rightWrist"], viewportWidth, viewportHeight)
      val leftHip = posePoint(poseFrame["leftHip"], viewportWidth, viewportHeight)
      val rightHip = posePoint(poseFrame["rightHip"], viewportWidth, viewportHeight)
      if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
        rootView.post {
          placeDefaultGarment(if (glbMode) glbView else garmentView, if (glbMode) 0.52f else 0.42f)
        }
        return
      }

      val shoulderMidX = (leftShoulder.first + rightShoulder.first) / 2f
      val shoulderMidY = (leftShoulder.second + rightShoulder.second) / 2f
      val hipMidX = (leftHip.first + rightHip.first) / 2f
      val hipMidY = (leftHip.second + rightHip.second) / 2f
      val shoulderDistance = distance(leftShoulder, rightShoulder)
      val torsoDistance = distance(shoulderMidX to shoulderMidY, hipMidX to hipMidY)
      val wristSpan = if (leftWrist != null && rightWrist != null) {
        distance(leftWrist, rightWrist)
      } else {
        0f
      }
      val armReachLeft = if (leftWrist != null) distance(leftShoulder, leftWrist) else 0f
      val armReachRight = if (rightWrist != null) distance(rightShoulder, rightWrist) else 0f
      val armReach = max(armReachLeft, armReachRight)
      val alignmentScales = mapOfAny(garmentAlignment?.get("scales"))
      val deformationTorso = mapOfAny(garmentDeformation?.get("torso"))
      val deformationRegions = mapOfAny(garmentDeformation?.get("regions"))
      val shoulderScale = numberOf(alignmentScales?.get("shoulder"), 1f).coerceIn(0.78f, 1.28f)
      val chestScale = numberOf(alignmentScales?.get("chest"), 1f).coerceIn(0.8f, 1.26f)
      val torsoScale = numberOf(alignmentScales?.get("torso"), 1f).coerceIn(0.78f, 1.3f)
      val waistScale = numberOf(alignmentScales?.get("waist"), 1f).coerceIn(0.76f, 1.26f)
      val hipScale = numberOf(alignmentScales?.get("hip"), 1f).coerceIn(0.78f, 1.28f)
      val torsoScaleX = numberOf(deformationTorso?.get("scaleX"), 1f).coerceIn(0.82f, 1.2f)
      val torsoScaleY = numberOf(deformationTorso?.get("scaleY"), 1f).coerceIn(0.82f, 1.2f)
      val shoulderTension = numberOf(deformationRegions?.get("shoulderTension"), 1f).coerceIn(0.76f, 1.24f)
      val chestInflation = numberOf(deformationRegions?.get("chestInflation"), 1f).coerceIn(0.76f, 1.24f)
      val waistTaper = numberOf(deformationRegions?.get("waistTaper"), 1f).coerceIn(0.70f, 1.18f)
      val waistTaperFactor = numberOf(garmentAlignment?.get("waistTaperFactor"), 0.88f).coerceIn(0.68f, 1.08f)
      val widthScale = ((shoulderScale * 0.46f) + (shoulderTension * 0.18f) + (chestScale * 0.22f) + (chestInflation * 0.14f))
      val heightScale =
        ((torsoScale * 0.38f) + (waistScale * 0.18f) + (hipScale * 0.12f) + (torsoScaleY * 0.32f))
      val silhouetteWidthScale = (widthScale * (0.92f + ((waistTaperFactor - 0.86f) * 0.18f))).coerceIn(0.86f, 1.28f)
      val garmentWidthMultiplier = if (glbMode) 4.20f else 3.55f
      val garmentHeightMultiplier = if (glbMode) 3.60f else 2.42f
      val minWidthFactor = if (glbMode) 0.65f else 0.52f
      val minHeightFactor = if (glbMode) 0.85f else 0.40f
      val anchorMatchedWidth = if (glbMode) {
        shoulderDistance * garmentWidthMultiplier
      } else {
        (shoulderDistance / garmentShoulderAnchorSpan) * 0.98f
      }
      val armWidthMultiplier = if (glbMode) 2.20f else 1.92f
      val rawWidth = max(
        max(shoulderDistance * garmentWidthMultiplier, anchorMatchedWidth),
        max(wristSpan * armWidthMultiplier, shoulderDistance * 2.18f)
      )
      val width = (
        max(viewportWidth * minWidthFactor, rawWidth) *
          silhouetteWidthScale *
          if (glbMode) 1f else editorScale
      ) * if (glbMode) 1.02f else 1.18f
      val finalWidth = width.coerceAtMost(viewportWidth * 1.34f)
      val bitmapAspect = if (glbMode) {
        1.42f
      } else {
        garmentBitmap?.let { bitmap ->
          if (bitmap.width <= 0) 1.32f else bitmap.height.toFloat() / bitmap.width.toFloat()
        } ?: 1.32f
      }.coerceIn(0.82f, 2.15f)
      val torsoDrivenHeight = torsoDistance * garmentHeightMultiplier
      val sleeveDrivenHeight = if (armReach > 0f) armReach * if (glbMode) 1.22f else 1.34f else 0f
      val aspectDrivenHeight = if (glbMode) torsoDrivenHeight else width * bitmapAspect
      val rawHeight = max(max(torsoDrivenHeight, sleeveDrivenHeight), aspectDrivenHeight)
      val height = (
        max(viewportHeight * minHeightFactor, rawHeight) * heightScale
      ) * if (glbMode) 1.02f else 1.16f
      val finalHeight = height.coerceAtMost(viewportHeight * if (glbMode) 1.04f else 1.20f)
      val rotation = Math.toDegrees(
        atan2(
          (rightShoulder.second - leftShoulder.second).toDouble(),
          (rightShoulder.first - leftShoulder.first).toDouble()
        )
      ).toFloat()
      val anchors = mapOfAny(garmentAlignment?.get("anchors"))
      val centerAnchor = posePoint(anchors?.get("center"), viewportWidth, viewportHeight)
      val chestAnchor = posePoint(anchors?.get("chest"), viewportWidth, viewportHeight)
      val waistAnchor = posePoint(anchors?.get("waist"), viewportWidth, viewportHeight)
      val centerX = (centerAnchor?.first ?: shoulderMidX) + (viewportWidth * editorOffsetX)
      val torsoCenterY = shoulderMidY + ((hipMidY - shoulderMidY) * 0.42f)
      val chestY = chestAnchor?.second ?: (shoulderMidY + ((hipMidY - shoulderMidY) * 0.30f))
      val waistY = waistAnchor?.second ?: (shoulderMidY + ((hipMidY - shoulderMidY) * 0.68f))
      val centerYBase = if (glbMode) {
        ((chestY * 0.76f) + (waistY * 0.24f)) - (finalHeight * 0.01f)
      } else {
        ((chestY * 0.78f) + (waistY * 0.22f)) - (finalHeight * 0.07f)
      }
      val centerY = centerYBase + (viewportHeight * editorOffsetY)
      val shoulderSlope = numberOf(garmentAlignment?.get("shoulderSlopeRadians"), 0f).coerceIn(-0.45f, 0.45f)
      val layeringConfidence = numberOf(arCompositing?.get("layeringConfidence"), 0.5f).coerceIn(0f, 1f)
      val overlapBlend = numberOf(arCompositing?.get("overlapBlend"), 0.55f).coerceIn(0.2f, 0.96f)
      val shadowOpacity = numberOf(arCompositing?.get("shadowOpacity"), 0.14f).coerceIn(0.08f, 0.3f)
      val contactShadowOpacity = numberOf(arCompositing?.get("contactShadowOpacity"), 0.18f).coerceIn(0.1f, 0.36f)
      val shadowSoftness = numberOf(arCompositing?.get("shadowSoftness"), 0.5f).coerceIn(0.36f, 0.86f)
      val depthSeparation = numberOf(arCompositing?.get("depthSeparation"), 0.3f).coerceIn(0.18f, 0.62f)
      val torsoDepthLift = numberOf(arCompositing?.get("torsoDepthLift"), 0.08f).coerceIn(0.02f, 0.22f)
      val chestDepthLift = numberOf(arCompositing?.get("chestDepthLift"), 0.1f).coerceIn(0.03f, 0.28f)

      rootView.post {
        val target = if (glbMode) glbView else garmentView
        val layoutParams = target.layoutParams as FrameLayout.LayoutParams
        val motionBias = ((segmentationConfidence * 0.26f) + (edgeStability * 0.16f) + (renderQuality * 0.12f)).coerceIn(0.22f, 0.48f)
        val motionSpread = (((1f - motionQuality).coerceIn(0f, 1f) * 0.10f) +
          ((1f - segmentationConfidence).coerceIn(0f, 1f) * 0.06f)).coerceIn(0f, 0.16f)
        val sleeveRelaxation = if (glbMode) 0.02f else 0.05f
        val positionFollow = if (glbMode) {
          (motionBias * 0.92f).coerceIn(0.22f, 0.58f)
        } else {
          (motionBias * 1.12f + motionSpread * 0.22f).coerceIn(0.30f, 0.72f)
        }
        val sizeFollow = if (glbMode) {
          (motionBias * 0.72f).coerceIn(0.18f, 0.42f)
        } else {
          (motionBias * 0.88f + motionSpread * 0.14f).coerceIn(0.22f, 0.52f)
        }
        val rotationFollow = if (glbMode) 0.22f else 0.28f
        val scaleFollow = if (glbMode) 0.20f else 0.26f

        val targetWidth = finalWidth * (1f + motionSpread + sleeveRelaxation)
        val targetHeight = finalHeight * (1f + (motionSpread * 0.72f) + sleeveRelaxation)
        layoutParams.gravity = android.view.Gravity.TOP or android.view.Gravity.START
        val smoothedWidth = smoothTo(lastGarmentWidth, targetWidth, sizeFollow)
        val smoothedHeight = smoothTo(lastGarmentHeight, targetHeight, sizeFollow)
        layoutParams.width = smoothedWidth.toInt().coerceAtLeast(1)
        layoutParams.height = smoothedHeight.toInt().coerceAtLeast(1)
        target.layoutParams = layoutParams
        val desiredX = centerX - (smoothedWidth / 2f)
        val desiredY = centerY - (smoothedHeight / 2f)
        target.x = smoothTo(lastGarmentX, desiredX, positionFollow)
        target.y = smoothTo(lastGarmentY, desiredY, positionFollow)
        if (glbMode) {
          depthShadowView.alpha = 0f
        } else {
          updateDepthShadow(
            x = target.x,
            y = target.y,
            width = smoothedWidth,
            height = smoothedHeight,
            rotation = rotation,
            shadowOpacity = shadowOpacity,
            contactShadowOpacity = contactShadowOpacity,
            shadowSoftness = shadowSoftness,
            depthSeparation = depthSeparation,
            torsoDepthLift = torsoDepthLift,
            chestDepthLift = chestDepthLift,
            renderQuality = renderQuality,
            edgeStability = edgeStability,
            torsoMaskConfidence = torsoMaskConfidence,
            shoulderSlope = shoulderSlope,
            waistTaper = waistTaper
          )
        }
        val desiredRotation = (rotation * 0.72f) +
          Math.toDegrees(shoulderSlope.toDouble()).toFloat() * 0.28f +
          if (glbMode) 0f else Math.toDegrees(editorRotationRadians.toDouble()).toFloat()
        target.rotation = smoothTo(lastGarmentRotation, desiredRotation, rotationFollow)
        val desiredScaleX = (1.04f + ((waistTaper - 1f) * 0.18f) + (motionSpread * 0.10f)).coerceIn(0.94f, 1.18f)
        val desiredScaleY = (1.06f + ((torsoScaleY - 1f) * 0.14f) + (motionSpread * 0.08f)).coerceIn(0.96f, 1.22f)
        target.scaleX = smoothTo(lastGarmentScaleX, desiredScaleX, scaleFollow)
        target.scaleY = smoothTo(lastGarmentScaleY, desiredScaleY, scaleFollow)
        val baseAlpha = if (glbMode) 0.78f else 0.56f
        val confidenceAlpha = if (glbMode) {
          baseAlpha + (segmentationConfidence * 0.08f) + (layeringConfidence * 0.08f) + (edgeStability * 0.06f)
        } else {
          baseAlpha + (segmentationConfidence * 0.16f) + (layeringConfidence * 0.16f) + (edgeStability * 0.08f)
        }
        target.alpha = (confidenceAlpha * renderQuality * (0.9f + (maskAlpha * 0.1f))).coerceIn(if (glbMode) 0.76f else 0.22f, 0.96f)
        target.translationZ = depthSeparation * 12f
        if (!glbMode) {
          garmentView.updateOcclusion(
            enabled = occlusionEnabled,
            leftShoulder = leftShoulder,
            rightShoulder = rightShoulder,
            leftElbow = leftElbow,
            rightElbow = rightElbow,
            leftWrist = leftWrist,
            rightWrist = rightWrist,
            leftHip = leftHip,
            rightHip = rightHip,
            viewX = garmentView.x,
            viewY = garmentView.y,
            overlapBlend = overlapBlend,
            shadowOpacity = shadowOpacity,
            contactShadowOpacity = contactShadowOpacity,
            shadowSoftness = shadowSoftness,
            edgeSmoothing = edgeSmoothing,
            edgeStability = edgeStability,
            maskAlpha = maskAlpha,
            armOverlapConfidence = armOverlapConfidence,
            torsoMaskConfidence = torsoMaskConfidence
          )
        }
        lastGarmentX = target.x
        lastGarmentY = target.y
        lastGarmentWidth = smoothedWidth
        lastGarmentHeight = smoothedHeight
        lastGarmentRotation = target.rotation
        lastGarmentScaleX = target.scaleX
        lastGarmentScaleY = target.scaleY
      }
    }

    fun reset() {
      rootView.post {
        garmentView.alpha = 0f
        glbView.alpha = 0f
      }
      lastGarmentX = Float.NaN
      lastGarmentY = Float.NaN
      lastGarmentWidth = Float.NaN
      lastGarmentHeight = Float.NaN
      lastGarmentRotation = Float.NaN
      lastGarmentScaleX = Float.NaN
      lastGarmentScaleY = Float.NaN
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

    private fun applyFitEditorConfig(config: Map<String, Any?>) {
      val garmentConfig = mapOfAny(config["garmentConfig"])
      val alignmentConfig = mapOfAny(config["alignmentConfig"])
      val editor = mapOfAny(garmentConfig?.get("editor"))
        ?: mapOfAny(alignmentConfig?.get("editor"))
      val anchors = mapOfAny(garmentConfig?.get("anchors"))
        ?: mapOfAny(alignmentConfig?.get("anchors"))
      val leftShoulder = mapOfAny(anchors?.get("left_shoulder"))
      val rightShoulder = mapOfAny(anchors?.get("right_shoulder"))
      val leftX = numberOf(leftShoulder?.get("x"), 0.33f)
      val rightX = numberOf(rightShoulder?.get("x"), 0.67f)

      editorOffsetX = numberOf(editor?.get("offsetX"), 0f).coerceIn(-0.25f, 0.25f)
      editorOffsetY = numberOf(editor?.get("offsetY"), 0f).coerceIn(-0.25f, 0.25f)
      editorScale = numberOf(editor?.get("scale"), 1f).coerceIn(0.72f, 1.48f)
      editorRotationRadians = numberOf(editor?.get("rotation"), 0f).coerceIn(-0.7f, 0.7f)
      garmentShoulderAnchorSpan = abs(rightX - leftX).coerceIn(0.24f, 0.62f)
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
            val fittedBitmap = cropTransparentBounds(bitmap)
            if (fittedBitmap !== bitmap) {
              bitmap.recycle()
            }
            rootView.post {
              garmentBitmap?.recycle()
              garmentBitmap = fittedBitmap
              garmentView.setBackgroundColor(Color.TRANSPARENT)
              garmentView.setImageBitmap(fittedBitmap)
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

    private fun cropTransparentBounds(source: Bitmap): Bitmap {
      var minX = source.width
      var minY = source.height
      var maxX = -1
      var maxY = -1

      for (y in 0 until source.height) {
        for (x in 0 until source.width) {
          if (Color.alpha(source.getPixel(x, y)) > 10) {
            if (x < minX) minX = x
            if (x > maxX) maxX = x
            if (y < minY) minY = y
            if (y > maxY) maxY = y
          }
        }
      }

      if (maxX < minX || maxY < minY) {
        return source
      }
      val cropWidth = (maxX - minX + 1).coerceAtLeast(1)
      val cropHeight = (maxY - minY + 1).coerceAtLeast(1)
      val nearlyFullWidth = cropWidth >= source.width * 0.96f
      val nearlyFullHeight = cropHeight >= source.height * 0.96f
      if (nearlyFullWidth && nearlyFullHeight) {
        return source
      }
      val padX = (source.width * 0.08f).toInt().coerceAtLeast(16)
      val padY = (source.height * 0.11f).toInt().coerceAtLeast(18)
      val left = (minX - padX).coerceAtLeast(0)
      val top = (minY - padY).coerceAtLeast(0)
      val right = (maxX + padX).coerceAtMost(source.width - 1)
      val bottom = (maxY + padY).coerceAtMost(source.height - 1)
      val paddedWidth = (right - left + 1).coerceAtLeast(1)
      val paddedHeight = (bottom - top + 1).coerceAtLeast(1)
      return Bitmap.createBitmap(source, left, top, paddedWidth, paddedHeight)
    }

    private fun loadGlbModel(modelUrl: String) {
      rootView.post {
        glbView.alpha = 0f
      }
      executor.execute {
        val cleanUrl = normalizeGlbSourceUrl(modelUrl)
        val localPath = when {
          cleanUrl.startsWith("http://", ignoreCase = true) ||
            cleanUrl.startsWith("https://", ignoreCase = true) -> {
              downloadModelToCache(cleanUrl)
                ?.removePrefix("file://")
                ?.trimStart('/')
                ?.let { "/$it" }
            }
          cleanUrl.startsWith("file://", ignoreCase = true) -> cleanUrl.removePrefix("file://")
          else -> {
            downloadModelToCache(cleanUrl)
              ?.removePrefix("file://")
              ?.trimStart('/')
              ?.let { "/$it" }
          }
        }
        val modelBytes = localPath?.let { pathOrUrl ->
          try {
            when {
              pathOrUrl.startsWith("http://", ignoreCase = true) ||
                pathOrUrl.startsWith("https://", ignoreCase = true) ->
                URL(pathOrUrl).openStream().use { it.readBytes() }
              else -> File(pathOrUrl).readBytes()
            }
          } catch (error: Throwable) {
            Log.e("ABZORA_GLB", "model read failed: ${error.message}")
            null
          }
        }
        Log.d(
          "ABZORA_GLB",
          "model source=$cleanUrl local=$localPath bytes=${modelBytes?.size ?: 0}"
        )
        val encodedPayload = modelBytes?.let { bytes ->
          Base64.encodeToString(bytes, Base64.NO_WRAP)
        }.orEmpty()
        val mimeType = if (cleanUrl.endsWith(".gltf", ignoreCase = true)) {
          "model/gltf+json"
        } else {
          "model/gltf-binary"
        }
        val html = """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <style>
              html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                background: transparent;
                overflow: hidden;
              }
              #stage {
                position: absolute;
                inset: 0;
                overflow: hidden;
                background: transparent;
              }
              model-viewer {
                width: 100%;
                height: 100%;
                background: transparent;
                --poster-color: transparent;
                --progress-bar-color: transparent;
                --progress-mask: transparent;
                pointer-events: none;
                opacity: 0.96;
              }
            </style>
          </head>
          <body>
            <div id="stage">
            <model-viewer
                camera-orbit="0deg 90deg 2.5m"
                field-of-view="45deg"
                shadow-intensity="0.16"
                exposure="1.2"
                interaction-prompt="none"
                disable-tap
                disable-zoom
                disable-pan
                autoplay
                loading="eager"
                crossorigin="anonymous">
              </model-viewer>
              <script>
                const viewer = document.querySelector('model-viewer');
                const modelBase64 = '$encodedPayload';
                const modelMimeType = '$mimeType';
                const directSourceUrl = '${cleanUrl.replace("'", "\\'")}';
                let objectUrl = '';
                const attachModel = () => {
                  if (!viewer) {
                    return;
                  }
                  if (!modelBase64) {
                    viewer.src = directSourceUrl;
                    console.log('model-viewer src attached via direct url');
                    return;
                  }
                  try {
                    const binary = atob(modelBase64);
                    const bytes = new Uint8Array(binary.length);
                    for (let i = 0; i < binary.length; i++) {
                      bytes[i] = binary.charCodeAt(i);
                    }
                    const blob = new Blob([bytes], { type: modelMimeType });
                    objectUrl = URL.createObjectURL(blob);
                    viewer.src = objectUrl;
                    console.log('model-viewer src attached via blob url');
                  } catch (error) {
                    console.error('model-viewer blob attachment error', error);
                    viewer.src = directSourceUrl;
                    console.log('model-viewer src attached via direct url fallback');
                  }
                };
                const loadModelViewer = (src) => new Promise((resolve, reject) => {
                  const script = document.createElement('script');
                  script.type = 'module';
                  script.src = src;
                  script.onload = resolve;
                  script.onerror = reject;
                  document.head.appendChild(script);
                });
                const bootModelViewer = async () => {
                  try {
                    await loadModelViewer('model_viewer.min.js');
                  } catch (err) {
                    console.error('model-viewer local load failed', err);
                  }
                  attachModel();
                };
                if (viewer) {
                  viewer.addEventListener('load', () => console.log('model-viewer loaded'));
                  viewer.addEventListener('error', (event) => console.error('model-viewer error', event));
                  viewer.addEventListener('progress', (event) => console.log('model-viewer progress', event));
                  setTimeout(() => {
                    if (!viewer.loaded) {
                      console.warn('model-viewer still not loaded after timeout');
                    }
                  }, 8000);
                }
                window.addEventListener('error', (event) => console.error('window error', event.message));
                bootModelViewer();
              </script>
            </div>
          </body>
        </html>
      """.trimIndent()
        rootView.post {
          glbView.loadDataWithBaseURL("file:///android_asset/", html, "text/html", "utf-8", null)
          placeDefaultGarment(glbView, 0.84f)
          glbView.alpha = 0.84f
        }
      }
    }

    private fun normalizeGlbSourceUrl(modelUrl: String): String {
      val trimmed = modelUrl.trim()
      if (trimmed.isEmpty()) {
        return trimmed
      }
      val lower = trimmed.lowercase()
      if (lower.startsWith("load/") && (lower.endsWith(".glb") || lower.endsWith(".gltf"))) {
        return normalizeGlbSourceUrl("https://res.cloudinary.com/dsgi8awyo/raw/upload/$trimmed")
      }
      if (lower.startsWith("res.cloudinary.com/")) {
        return normalizeGlbSourceUrl("https://$trimmed")
      }
      val isModelFile = lower.endsWith(".glb") || lower.endsWith(".gltf")
      if (!trimmed.contains("res.cloudinary.com") || !isModelFile) {
        return trimmed
      }
      if (trimmed.contains("/raw/upload/")) {
        return trimmed
      }
      return trimmed.replace("/image/upload/", "/raw/upload/")
    }

    private fun downloadModelToCache(modelUrl: String): String? {
      return try {
        val clean = modelUrl.trim()
        if (clean.isEmpty()) {
          return null
        }
        val cacheDir = File(rootView.context.cacheDir, "abzora_models").apply { mkdirs() }
        val hashed = clean.hashCode().toUInt().toString(16)
        val extension = when {
          clean.endsWith(".gltf", ignoreCase = true) -> ".gltf"
          else -> ".glb"
        }
        val localFile = File(cacheDir, "model_$hashed$extension")
        if (!localFile.exists() || localFile.length() == 0L) {
          URL(clean).openStream().use { input ->
            FileOutputStream(localFile).use { output ->
              input.copyTo(output)
              output.flush()
            }
          }
        }
        Uri.fromFile(localFile).toString()
      } catch (error: Throwable) {
        Log.e("ABZORA_GLB", "model download failed: ${error.message}")
        null
      }
    }

    private fun placeDefaultGarment(target: android.view.View, alpha: Float) {
      val width = rootView.width
      val height = rootView.height
      if (width <= 0 || height <= 0) {
        return
      }
      val isGlbTarget = target === glbView
      val targetWidth =
        (width * if (isGlbTarget) 0.85f else 0.78f).toInt().coerceAtLeast(if (isGlbTarget) 320 else 300)
      val targetHeight =
        (height * if (isGlbTarget) 0.85f else 0.62f).toInt().coerceAtLeast(if (isGlbTarget) 480 else 380)
      val layoutParams = target.layoutParams as FrameLayout.LayoutParams
      layoutParams.width = targetWidth
      layoutParams.height = targetHeight
      target.layoutParams = layoutParams
      target.x = (width - targetWidth) / 2f
      target.y = if (isGlbTarget) height * 0.09f else height * 0.20f
      target.rotation = 0f
      target.alpha = max(target.alpha, alpha)
      target.translationZ = 10f
      if (isGlbTarget) {
        depthShadowView.alpha = 0f
        return
      }
      updateDepthShadow(
        x = target.x,
        y = target.y,
        width = targetWidth.toFloat(),
        height = targetHeight.toFloat(),
        rotation = 0f,
        shadowOpacity = 0.12f,
        contactShadowOpacity = 0.16f,
        shadowSoftness = 0.58f,
        depthSeparation = 0.34f,
        torsoDepthLift = 0.08f,
        chestDepthLift = 0.1f,
        renderQuality = alpha,
        edgeStability = 0.58f,
        torsoMaskConfidence = 0.56f,
        shoulderSlope = 0f,
        waistTaper = 1f
      )
    }

    private fun updateDepthShadow(
      x: Float,
      y: Float,
      width: Float,
      height: Float,
      rotation: Float,
      shadowOpacity: Float,
      contactShadowOpacity: Float,
      shadowSoftness: Float,
      depthSeparation: Float,
      torsoDepthLift: Float,
      chestDepthLift: Float,
      renderQuality: Float,
      edgeStability: Float,
      torsoMaskConfidence: Float,
      shoulderSlope: Float,
      waistTaper: Float
    ) {
      val layoutParams = depthShadowView.layoutParams as FrameLayout.LayoutParams
      layoutParams.width = width.toInt().coerceAtLeast(1)
      layoutParams.height = height.toInt().coerceAtLeast(1)
      depthShadowView.layoutParams = layoutParams
      depthShadowView.x = x
      depthShadowView.y = y
      depthShadowView.rotation = (rotation * 0.62f) + Math.toDegrees(shoulderSlope.toDouble()).toFloat() * 0.22f
      depthShadowView.alpha = ((0.46f + (depthSeparation * 0.38f)) * renderQuality).coerceIn(0.18f, 0.82f)
      depthShadowView.translationZ = max(0f, (depthSeparation * 12f) - 2f)
      depthShadowView.updateDepth(
        torsoOpacity = (shadowOpacity * (0.92f + torsoDepthLift)).coerceIn(0.06f, 0.30f),
        chestOpacity = (shadowOpacity * (1.04f + chestDepthLift)).coerceIn(0.08f, 0.34f),
        shoulderOpacity = (contactShadowOpacity * (0.78f + edgeStability * 0.26f)).coerceIn(0.06f, 0.28f),
        waistOpacity = (contactShadowOpacity * (0.72f + (1f - waistTaper).coerceIn(-0.2f, 0.3f))).coerceIn(0.05f, 0.26f),
        softness = shadowSoftness.coerceIn(0.42f, 0.92f),
        maskConfidence = torsoMaskConfidence.coerceIn(0f, 1f),
      )
    }

    private fun posePoint(raw: Any?, viewportWidth: Float, viewportHeight: Float): Pair<Float, Float>? {
      val map = raw as? Map<*, *> ?: return null
      val x = (map["x"] as? Number)?.toFloat() ?: return null
      val y = (map["y"] as? Number)?.toFloat() ?: return null
      val normX = if (x > 1f) x / viewportWidth else x
      val normY = if (y > 1f) y / viewportHeight else y
      return (normX.coerceIn(0f, 1f) * viewportWidth) to (normY.coerceIn(0f, 1f) * viewportHeight)
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

    private fun smoothTo(previous: Float, target: Float, factor: Float): Float {
      if (previous.isNaN()) {
        return target
      }
      return previous + ((target - previous) * factor.coerceIn(0f, 1f))
    }
}

private class BodyAwareGarmentShadowView(context: Context) : android.view.View(context) {
  private val paint = android.graphics.Paint().apply {
    isAntiAlias = true
    style = android.graphics.Paint.Style.FILL
  }
  private var torsoOpacity = 0.12f
  private var chestOpacity = 0.14f
  private var shoulderOpacity = 0.1f
  private var waistOpacity = 0.1f
  private var softness = 0.58f
  private var maskConfidence = 0.6f

  fun updateDepth(
    torsoOpacity: Float,
    chestOpacity: Float,
    shoulderOpacity: Float,
    waistOpacity: Float,
    softness: Float,
    maskConfidence: Float
  ) {
    this.torsoOpacity = torsoOpacity
    this.chestOpacity = chestOpacity
    this.shoulderOpacity = shoulderOpacity
    this.waistOpacity = waistOpacity
    this.softness = softness
    this.maskConfidence = maskConfidence
    invalidate()
  }

  override fun onDraw(canvas: Canvas) {
    val w = width.toFloat()
    val h = height.toFloat()
    if (w <= 0f || h <= 0f) return

    val blur = (18f + (softness * 28f)).coerceIn(18f, 46f)
    paint.maskFilter = android.graphics.BlurMaskFilter(blur, android.graphics.BlurMaskFilter.Blur.NORMAL)

    paint.color = alphaColor(torsoOpacity * (0.78f + maskConfidence * 0.22f), 16, 16, 18)
    canvas.drawOval(w * 0.22f, h * 0.18f, w * 0.78f, h * 0.88f, paint)

    paint.color = alphaColor(chestOpacity, 10, 10, 12)
    canvas.drawOval(w * 0.20f, h * 0.14f, w * 0.80f, h * 0.48f, paint)

    paint.color = alphaColor(shoulderOpacity, 8, 8, 10)
    canvas.drawRoundRect(
      w * 0.12f,
      h * 0.10f,
      w * 0.88f,
      h * 0.28f,
      h * 0.08f,
      h * 0.08f,
      paint
    )

    paint.color = alphaColor(waistOpacity, 12, 12, 14)
    canvas.drawOval(w * 0.26f, h * 0.58f, w * 0.74f, h * 0.88f, paint)

    paint.maskFilter = null
  }

  private fun alphaColor(opacity: Float, red: Int, green: Int, blue: Int): Int {
    val alpha = (opacity.coerceIn(0f, 0.36f) * 255f).toInt().coerceIn(0, 92)
    return Color.argb(alpha, red, green, blue)
  }
}

private class GarmentModelWebView(context: Context) : WebView(context)

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
    leftElbow: Pair<Float, Float>?,
    rightElbow: Pair<Float, Float>?,
    leftWrist: Pair<Float, Float>?,
    rightWrist: Pair<Float, Float>?,
    leftHip: Pair<Float, Float>,
    rightHip: Pair<Float, Float>,
    viewX: Float,
    viewY: Float,
    overlapBlend: Float,
    shadowOpacity: Float,
    contactShadowOpacity: Float,
    shadowSoftness: Float,
    edgeSmoothing: Float,
    edgeStability: Float,
    maskAlpha: Float,
    armOverlapConfidence: Float,
    torsoMaskConfidence: Float
  ) {
    hasClip = enabled
    val edgeBlend = ((edgeSmoothing * 0.48f) + (edgeStability * 0.34f) + (maskAlpha * 0.18f)).coerceIn(0.22f, 0.88f)
    val overlapConfidence = ((armOverlapConfidence * 0.58f) + (torsoMaskConfidence * 0.42f)).coerceIn(0.0f, 1.0f)
    this.overlapBlend = ((overlapBlend * 0.66f) + (overlapConfidence * 0.34f)).coerceIn(0.28f, 0.9f)
    this.shadowOpacity = (shadowOpacity * (0.82f + (torsoMaskConfidence * 0.24f))).coerceIn(0.06f, 0.28f)
    this.contactShadowOpacity = (contactShadowOpacity * (0.78f + (overlapConfidence * 0.28f))).coerceIn(0.08f, 0.32f)
    this.shadowSoftness = (shadowSoftness + (edgeBlend * 0.16f)).coerceIn(0.42f, 0.92f)
    clipPath.reset()
    if (enabled) {
      val shoulderPad = width * (0.045f + ((1f - this.overlapBlend) * 0.035f) + (edgeBlend * 0.025f))
      val hipPad = width * (0.04f + ((1f - this.overlapBlend) * 0.025f) + (edgeBlend * 0.02f))
      val shoulderFeather = height * (0.025f + (edgeBlend * 0.035f))
      val waistFeather = height * (0.08f + (edgeBlend * 0.045f))
      val sleevePad = width * (0.07f + ((1f - this.overlapBlend) * 0.04f) + (edgeBlend * 0.03f))
      val sleeveLift = height * (0.04f + (edgeBlend * 0.03f))
      val leftTop = leftShoulder.first - viewX - shoulderPad to leftShoulder.second - viewY + shoulderFeather
      val rightTop = rightShoulder.first - viewX + shoulderPad to rightShoulder.second - viewY + shoulderFeather
      val rightBottom = rightHip.first - viewX + hipPad to rightHip.second - viewY + waistFeather
      val leftBottom = leftHip.first - viewX - hipPad to leftHip.second - viewY + waistFeather
      val leftSleeveMid = leftElbow?.let {
        it.first - viewX - sleevePad to it.second - viewY + sleeveLift
      } ?: (leftShoulder.first - viewX - sleevePad to leftShoulder.second - viewY + (height * 0.18f))
      val leftSleeveEnd = leftWrist?.let {
        it.first - viewX - sleevePad * 1.18f to it.second - viewY + sleeveLift * 1.24f
      } ?: (leftShoulder.first - viewX - sleevePad * 1.24f to leftBottom.second + (height * 0.24f))
      val rightSleeveMid = rightElbow?.let {
        it.first - viewX + sleevePad to it.second - viewY + sleeveLift
      } ?: (rightShoulder.first - viewX + sleevePad to rightShoulder.second - viewY + (height * 0.18f))
      val rightSleeveEnd = rightWrist?.let {
        it.first - viewX + sleevePad * 1.18f to it.second - viewY + sleeveLift * 1.24f
      } ?: (rightShoulder.first - viewX + sleevePad * 1.24f to rightBottom.second + (height * 0.24f))
      clipPath.moveTo(leftTop.first, leftTop.second)
      clipPath.cubicTo(
        leftTop.first,
        leftTop.second - shoulderFeather,
        leftSleeveMid.first,
        leftSleeveMid.second - (height * 0.04f),
        leftSleeveMid.first,
        leftSleeveMid.second
      )
      clipPath.cubicTo(
        leftSleeveMid.first,
        leftSleeveMid.second + (height * 0.03f),
        leftSleeveEnd.first,
        leftSleeveEnd.second - (height * 0.02f),
        leftSleeveEnd.first,
        leftSleeveEnd.second
      )
      clipPath.lineTo(leftBottom.first, leftBottom.second)
      clipPath.quadTo(width * 0.5f, height * (0.9f + (edgeBlend * 0.02f)), rightBottom.first, rightBottom.second)
      clipPath.lineTo(rightSleeveEnd.first, rightSleeveEnd.second)
      clipPath.cubicTo(
        rightSleeveEnd.first,
        rightSleeveEnd.second - (height * 0.02f),
        rightSleeveMid.first,
        rightSleeveMid.second + (height * 0.03f),
        rightSleeveMid.first,
        rightSleeveMid.second
      )
      clipPath.cubicTo(
        rightSleeveMid.first,
        rightSleeveMid.second - (height * 0.04f),
        rightTop.first,
        rightTop.second - shoulderFeather,
        rightTop.first,
        rightTop.second
      )
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

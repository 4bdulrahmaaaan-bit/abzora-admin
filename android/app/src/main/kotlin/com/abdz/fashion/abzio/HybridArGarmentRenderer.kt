package com.abdz.fashion.abzio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
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
    private val garmentView = ImageView(context).apply {
      scaleType = ImageView.ScaleType.FIT_CENTER
      alpha = 0f
    }
    private var garmentBitmap: Bitmap? = null

    init {
      rootView.addView(
        garmentView,
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
          ?: return
      loadOverlayBitmap(overlayAssetUrl)
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
      if (!bodyDetected) {
        garmentView.animate().alpha(0.32f).setDuration(120).start()
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
      val width = min(viewportWidth * 0.92f, max(viewportWidth * 0.18f, shoulderDistance * 1.25f))
      val height = min(viewportHeight * 0.9f, max(viewportHeight * 0.18f, torsoDistance * 1.58f))
      val rotation = Math.toDegrees(
        atan2(
          (rightShoulder.second - leftShoulder.second).toDouble(),
          (rightShoulder.first - leftShoulder.first).toDouble()
        )
      ).toFloat()
      val centerX = shoulderMidX
      val centerY = shoulderMidY + (height * 0.12f)

      rootView.post {
        val layoutParams = garmentView.layoutParams as FrameLayout.LayoutParams
        layoutParams.width = width.toInt()
        layoutParams.height = height.toInt()
        garmentView.layoutParams = layoutParams
        garmentView.x = centerX - (width / 2f)
        garmentView.y = centerY - (height / 2f)
        garmentView.rotation = rotation
        garmentView.alpha = 0.94f
      }
    }

    fun reset() {
      rootView.post { garmentView.alpha = 0f }
    }

    fun dispose() {
      executor.shutdownNow()
      garmentBitmap?.recycle()
      rootView.removeAllViews()
    }

    private fun loadOverlayBitmap(url: String) {
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
              garmentView.setImageBitmap(bitmap)
            }
          }
        } catch (_: Throwable) {
        }
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
}

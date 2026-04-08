package com.abdz.fashion.abzio

import android.content.Context
import android.graphics.BitmapFactory
import android.os.SystemClock
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MediaPipePoseBridge(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "abzora/mediapipe_pose")
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var poseLandmarker: PoseLandmarker? = null
    private var poseCallbackEnabled: Boolean = true

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<*, *>
                val modelAssetPath = args?.get("modelAssetPath")?.toString()
                    ?: "assets/ml/pose_landmarker_lite.task"
                executor.execute {
                    try {
                        ensureDetector(modelAssetPath)
                        postSuccess(result, true)
                    } catch (error: Throwable) {
                        postSuccess(result, false)
                    }
                }
            }
            "processFrame" -> {
                val args = call.arguments as? Map<*, *> ?: run {
                    result.error("invalid_args", "Missing frame arguments", null)
                    return
                }
                executor.execute {
                    try {
                        val detector = ensureDetector()
                        val bytes = args["jpegBytes"] as? ByteArray
                            ?: throw IllegalArgumentException("jpegBytes missing")
                        val width = (args["width"] as? Number)?.toInt() ?: 0
                        val height = (args["height"] as? Number)?.toInt() ?: 0
                        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: throw IllegalStateException("Could not decode JPEG frame")
                        val mpImage = BitmapImageBuilder(bitmap).build()
                        val timestampMs = (args["timestampMs"] as? Number)?.toLong()
                            ?: SystemClock.uptimeMillis()
                        val output = detector.detectForVideo(mpImage, timestampMs)
                        val payload = serializeLandmarks(output, width, height)
                        if (poseCallbackEnabled) {
                            emitPoseToFlutter(payload)
                        }
                        postSuccess(result, payload)
                    } catch (error: Throwable) {
                        postError(result, "mediapipe_process_failed", error.message ?: "Pose processing failed")
                    }
                }
            }
            "processImagePath" -> {
                val args = call.arguments as? Map<*, *> ?: run {
                    result.error("invalid_args", "Missing image path arguments", null)
                    return
                }
                executor.execute {
                    try {
                        val detector = ensureDetector()
                        val path = args["path"]?.toString() ?: ""
                        if (path.isBlank()) {
                            throw IllegalArgumentException("path missing")
                        }
                        val bitmap = BitmapFactory.decodeFile(path)
                            ?: throw IllegalStateException("Could not decode file at $path")
                        val mpImage = BitmapImageBuilder(bitmap).build()
                        val output = detector.detect(mpImage)
                        val payload = serializeLandmarks(output, bitmap.width, bitmap.height)
                        if (poseCallbackEnabled) {
                            emitPoseToFlutter(payload)
                        }
                        postSuccess(result, payload)
                    } catch (error: Throwable) {
                        postError(result, "mediapipe_image_failed", error.message ?: "Image pose processing failed")
                    }
                }
            }
            "setPoseCallbackEnabled" -> {
                val args = call.arguments as? Map<*, *>
                poseCallbackEnabled = (args?.get("enabled") as? Boolean) ?: false
                result.success(true)
            }
            "dispose" -> {
                dispose()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureDetector(modelAssetPath: String = "assets/ml/pose_landmarker_lite.task"): PoseLandmarker {
        poseLandmarker?.let { return it }
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath(modelAssetPath)
                    .build()
            )
            .setRunningMode(RunningMode.VIDEO)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .build()
        val detector = PoseLandmarker.createFromOptions(context, options)
        poseLandmarker = detector
        return detector
    }

    private fun serializeLandmarks(
        output: PoseLandmarkerResult,
        frameWidth: Int,
        frameHeight: Int
    ): List<Map<String, Any>> {
        val firstPose = output.landmarks().firstOrNull() ?: return emptyList()
        val width = if (frameWidth <= 0) 1 else frameWidth
        val height = if (frameHeight <= 0) 1 else frameHeight
        val labels = listOf(
            "nose",
            "left_eye_inner",
            "left_eye",
            "left_eye_outer",
            "right_eye_inner",
            "right_eye",
            "right_eye_outer",
            "left_ear",
            "right_ear",
            "mouth_left",
            "mouth_right",
            "left_shoulder",
            "right_shoulder",
            "left_elbow",
            "right_elbow",
            "left_wrist",
            "right_wrist",
            "left_pinky",
            "right_pinky",
            "left_index",
            "right_index",
            "left_thumb",
            "right_thumb",
            "left_hip",
            "right_hip",
            "left_knee",
            "right_knee",
            "left_ankle",
            "right_ankle",
            "left_heel",
            "right_heel",
            "left_foot_index",
            "right_foot_index"
        )
        return firstPose.mapIndexed { index, landmark ->
            val visibility: Float = try {
                landmark.visibility().orElse(0f)
            } catch (_: Throwable) {
                0f
            }
            mapOf(
                "type" to (labels.getOrNull(index) ?: "unknown_$index"),
                // Return pixel space so existing Flutter measurement math remains stable.
                "x" to (landmark.x() * width.toDouble()),
                "y" to (landmark.y() * height.toDouble()),
                "z" to landmark.z().toDouble(),
                "visibility" to visibility.toDouble()
            )
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        poseLandmarker?.close()
        poseLandmarker = null
        poseCallbackEnabled = false
        executor.shutdown()
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        android.os.Handler(context.mainLooper).post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        android.os.Handler(context.mainLooper).post { result.error(code, message, null) }
    }

    private fun emitPoseToFlutter(payload: List<Map<String, Any>>) {
        android.os.Handler(context.mainLooper).post {
            channel.invokeMethod("onPose", payload)
        }
    }
}

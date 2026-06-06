package com.abdz.fashion.abzio

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
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
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class MediaPipePoseBridge(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "abzora/mediapipe_pose")
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var poseLandmarker: PoseLandmarker? = null
    private var poseCallbackEnabled: Boolean = true
    private var processedFrames: Long = 0
    private var failedFrames: Long = 0
    private var lastLatencyMs: Long = 0
    private var avgLatencyMs: Double = 0.0

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val args = call.arguments as? Map<*, *>
                val modelAssetPath = args?.get("modelAssetPath")?.toString()
                    ?: "ml/pose_landmarker_lite.task"
                executor.execute {
                    try {
                        ensureDetector(modelAssetPath)
                        Log.d("ABZORA_POSE", "MediaPipe initialized with $modelAssetPath")
                        postSuccess(result, true)
                    } catch (error: Throwable) {
                        Log.e("ABZORA_POSE", "MediaPipe initialize failed: ${error.message}")
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
                    val started = SystemClock.elapsedRealtime()
                    try {
                        val detector = ensureDetector()
                        val bytes = args["jpegBytes"] as? ByteArray
                            ?: throw IllegalArgumentException("jpegBytes missing")
                        val rotation = (args["rotation"] as? Number)?.toInt() ?: 0
                        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            ?: throw IllegalStateException("Could not decode JPEG frame")
                        val bitmap = rotateBitmap(decoded, rotation)
                        val mpImage = BitmapImageBuilder(bitmap).build()
                        val timestampMs = (args["timestampMs"] as? Number)?.toLong()
                            ?: SystemClock.uptimeMillis()
                        val output = detector.detectForVideo(mpImage, timestampMs)
                        val payload = serializeLandmarks(output)
                        val latency = SystemClock.elapsedRealtime() - started
                        processedFrames += 1
                        lastLatencyMs = latency
                        avgLatencyMs =
                            if (processedFrames <= 1) latency.toDouble()
                            else (avgLatencyMs * 0.85) + (latency * 0.15)
                        if (poseCallbackEnabled) {
                            emitPoseToFlutter(payload)
                        }
                        postSuccess(result, payload)
                    } catch (error: Throwable) {
                        failedFrames += 1
                        Log.e("ABZORA_POSE", "processFrame failed: ${error.message}")
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
                    val started = SystemClock.elapsedRealtime()
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
                        val payload = serializeLandmarks(output)
                        val latency = SystemClock.elapsedRealtime() - started
                        processedFrames += 1
                        lastLatencyMs = latency
                        avgLatencyMs =
                            if (processedFrames <= 1) latency.toDouble()
                            else (avgLatencyMs * 0.85) + (latency * 0.15)
                        if (poseCallbackEnabled) {
                            emitPoseToFlutter(payload)
                        }
                        postSuccess(result, payload)
                    } catch (error: Throwable) {
                        failedFrames += 1
                        Log.e("ABZORA_POSE", "processImagePath failed: ${error.message}")
                        postError(result, "mediapipe_image_failed", error.message ?: "Image pose processing failed")
                    }
                }
            }
            "getDiagnostics" -> {
                val total = processedFrames + failedFrames
                val errorRate = if (total <= 0) 0.0 else failedFrames.toDouble() / total.toDouble()
                result.success(
                    mapOf(
                        "processedFrames" to processedFrames,
                        "failedFrames" to failedFrames,
                        "errorRate" to errorRate,
                        "lastLatencyMs" to lastLatencyMs,
                        "avgLatencyMs" to avgLatencyMs,
                        "callbackEnabled" to poseCallbackEnabled
                    )
                )
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

    private fun ensureDetector(modelAssetPath: String = "ml/pose_landmarker_lite.task"): PoseLandmarker {
        poseLandmarker?.let { return it }
        val normalizedAssetPath = modelAssetPath
            .replace("flutter_assets/assets/", "")
            .replace("assets/", "")
            .trimStart('/')
        val candidates = listOf(
            normalizedAssetPath,
            modelAssetPath,
            "ml/pose_landmarker_lite.task",
            "pose_landmarker_lite.task"
        ).distinct()
        var lastError: Throwable? = null
        for (candidate in candidates) {
            try {
                val modelFile = resolveModelFile(candidate)
                val detector = if (modelFile != null) {
                    val baseOptions = buildBaseOptions(modelFile)
                    val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                        .setBaseOptions(baseOptions)
                        .setRunningMode(RunningMode.VIDEO)
                        .setNumPoses(1)
                        .setMinPoseDetectionConfidence(0.35f)
                        .setMinPosePresenceConfidence(0.35f)
                        .setMinTrackingConfidence(0.35f)
                        .build()
                    PoseLandmarker.createFromOptions(context, options)
                } else {
                    PoseLandmarker.createFromFile(context, candidate)
                }
                poseLandmarker = detector
                Log.d("ABZORA_POSE", "Pose detector ready: ${modelFile?.absolutePath ?: candidate}")
                return detector
            } catch (error: Throwable) {
                lastError = error
                Log.e("ABZORA_POSE", "Pose detector candidate failed $candidate: ${error.message}")
            }
        }
        throw lastError ?: IllegalStateException("Pose detector could not be created")
    }

    private fun buildBaseOptions(modelFile: File): BaseOptions {
        val buffer = FileInputStream(modelFile).channel.use { channel ->
            channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size())
        }
        val builder = BaseOptions.builder()
        val methods = listOf("setModelAssetBuffer", "setModelBuffer")
        for (methodName in methods) {
            val method = builder.javaClass.methods.firstOrNull { candidate ->
                candidate.name == methodName && candidate.parameterTypes.size == 1
            }
            if (method != null) {
                try {
                    method.invoke(builder, buffer)
                    return builder.build()
                } catch (_: Throwable) {
                    // Try next setter or fallback below.
                }
            }
        }
        return builder
            .setModelAssetPath(modelFile.absolutePath)
            .build()
    }

    private fun resolveModelFile(assetPath: String): File? {
        val fileCandidates = listOf(
            File(assetPath),
            File(context.cacheDir, assetPath),
            File(context.cacheDir, "abzora_pose_models/${assetPath.replace('/', '_')}")
        )
        for (file in fileCandidates) {
            if (file.exists() && file.length() > 0) {
                return file
            }
        }
        val assetCandidates = listOf(
            assetPath,
            "ml/pose_landmarker_lite.task",
            "pose_landmarker_lite.task"
        ).distinct()
        for (candidate in assetCandidates) {
            try {
                val cached = File(context.cacheDir, "abzora_pose_models/${candidate.replace('/', '_')}")
                cached.parentFile?.mkdirs()
                context.assets.open(candidate).use { input ->
                    FileOutputStream(cached).use { output ->
                        input.copyTo(output)
                    }
                }
                if (cached.exists() && cached.length() > 0) {
                    Log.d("ABZORA_POSE", "Pose model resolved from asset $candidate -> ${cached.absolutePath}")
                    return cached
                }
            } catch (_: Throwable) {
                // Try next candidate.
            }
        }
        return null
    }

    private fun serializeLandmarks(
        output: PoseLandmarkerResult
    ): List<Map<String, Any>> {
        val firstPose = output.landmarks().firstOrNull() ?: return emptyList()
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
                landmark.visibility().orElse(1f)
            } catch (_: Throwable) {
                1f
            }
            mapOf(
                "type" to (labels.getOrNull(index) ?: "unknown_$index"),
                "x" to landmark.x().toDouble(),
                "y" to landmark.y().toDouble(),
                "z" to landmark.z().toDouble(),
                "visibility" to visibility.toDouble()
            )
        }
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        val normalized = ((rotationDegrees % 360) + 360) % 360
        if (normalized == 0) {
            return bitmap
        }
        val matrix = Matrix().apply { postRotate(normalized.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
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

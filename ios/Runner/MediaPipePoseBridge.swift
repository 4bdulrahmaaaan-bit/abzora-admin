import AVFoundation
import Flutter
import Foundation
import UIKit

#if canImport(MediaPipeTasksVision)
import MediaPipeTasksVision
#endif

final class MediaPipePoseBridge: NSObject, FlutterPlugin, AVCaptureVideoDataOutputSampleBufferDelegate {
  private static let channelName = "abzora/mediapipe_pose"

  private var channel: FlutterMethodChannel?
  private let captureSession = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let processingQueue = DispatchQueue(label: "abzora.mediapipe.pose.processing")
  private var frameCounter = 0
  private var streamEnabled = false
  private var callbackEnabled = false
  private var modelAssetPath = "assets/ml/pose_landmarker_lite.task"

  #if canImport(MediaPipeTasksVision)
  private var poseLandmarker: PoseLandmarker?
  #endif

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = MediaPipePoseBridge()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      if let incomingModelPath = args["modelAssetPath"] as? String, !incomingModelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        modelAssetPath = incomingModelPath
      }
      result(initializePose())

    case "processFrame":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Missing frame arguments", details: nil))
        return
      }
      processFrameArgs(args, result: result)

    case "processImagePath":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "invalid_args", message: "Missing image path", details: nil))
        return
      }
      processImagePath(path, result: result)

    case "setPoseCallbackEnabled":
      let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
      callbackEnabled = enabled
      if enabled {
        startCameraStreamIfNeeded()
      } else {
        stopCameraStream()
      }
      result(true)

    case "dispose":
      disposeResources()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializePose() -> Bool {
    #if canImport(MediaPipeTasksVision)
    do {
      let options = PoseLandmarkerOptions()
      options.baseOptions = BaseOptions(modelAssetPath: modelAssetPath)
      options.runningMode = .video
      options.numPoses = 1
      options.minPoseDetectionConfidence = 0.5
      options.minPosePresenceConfidence = 0.5
      options.minTrackingConfidence = 0.5
      poseLandmarker = try PoseLandmarker(options: options)
      return true
    } catch {
      return false
    }
    #else
    return false
    #endif
  }

  private func processFrameArgs(_ args: [String: Any], result: @escaping FlutterResult) {
    #if canImport(MediaPipeTasksVision)
    guard let poseLandmarker else {
      result(FlutterError(code: "mediapipe_not_initialized", message: "Initialize MediaPipe first", details: nil))
      return
    }
    guard let jpegBytes = args["jpegBytes"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "invalid_frame", message: "jpegBytes is required", details: nil))
      return
    }
    processingQueue.async {
      let data = jpegBytes.data
      guard let image = UIImage(data: data),
            let mpImage = try? MPImage(uiImage: image) else {
        DispatchQueue.main.async {
          result([])
        }
        return
      }
      let ts = (args["timestampMs"] as? NSNumber)?.intValue ?? Int(Date().timeIntervalSince1970 * 1000)
      let output = try? poseLandmarker.detect(videoFrame: mpImage, timestampInMilliseconds: ts)
      let payload = self.serialize(result: output)
      if self.callbackEnabled {
        self.emitToFlutter(payload)
      }
      DispatchQueue.main.async {
        result(payload)
      }
    }
    #else
    result(
      FlutterError(
        code: "mediapipe_ios_not_linked",
        message: "MediaPipeTasksVision is not linked on iOS. Run pod install.",
        details: nil
      )
    )
    #endif
  }

  private func processImagePath(_ path: String, result: @escaping FlutterResult) {
    #if canImport(MediaPipeTasksVision)
    guard let poseLandmarker else {
      result(FlutterError(code: "mediapipe_not_initialized", message: "Initialize MediaPipe first", details: nil))
      return
    }
    processingQueue.async {
      guard let image = UIImage(contentsOfFile: path),
            let mpImage = try? MPImage(uiImage: image) else {
        DispatchQueue.main.async {
          result([])
        }
        return
      }
      let output = try? poseLandmarker.detect(image: mpImage)
      let payload = self.serialize(result: output)
      if self.callbackEnabled {
        self.emitToFlutter(payload)
      }
      DispatchQueue.main.async {
        result(payload)
      }
    }
    #else
    result(
      FlutterError(
        code: "mediapipe_ios_not_linked",
        message: "MediaPipeTasksVision is not linked on iOS. Run pod install.",
        details: nil
      )
    )
    #endif
  }

  private func startCameraStreamIfNeeded() {
    guard !streamEnabled else {
      return
    }
    captureSession.beginConfiguration()
    captureSession.sessionPreset = .vga640x480

    if let existingInput = captureSession.inputs.first {
      captureSession.removeInput(existingInput)
    }

    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device),
          captureSession.canAddInput(input) else {
      captureSession.commitConfiguration()
      return
    }
    captureSession.addInput(input)

    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]

    if captureSession.canAddOutput(videoOutput) {
      if !captureSession.outputs.contains(videoOutput) {
        captureSession.addOutput(videoOutput)
      }
    }
    captureSession.commitConfiguration()

    streamEnabled = true
    processingQueue.async {
      self.captureSession.startRunning()
    }
  }

  private func stopCameraStream() {
    guard streamEnabled else {
      return
    }
    streamEnabled = false
    processingQueue.async {
      if self.captureSession.isRunning {
        self.captureSession.stopRunning()
      }
    }
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    #if canImport(MediaPipeTasksVision)
    guard callbackEnabled else {
      return
    }
    frameCounter += 1
    if frameCounter % 2 != 0 {
      return
    }
    guard let poseLandmarker else {
      return
    }
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    let timestamp = Int(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000)
    guard let mpImage = try? MPImage(pixelBuffer: pixelBuffer) else {
      return
    }
    let outputResult = try? poseLandmarker.detect(videoFrame: mpImage, timestampInMilliseconds: timestamp)
    let payload = serialize(result: outputResult)
    emitToFlutter(payload)
    #endif
  }

  private func emitToFlutter(_ payload: [[String: Any]]) {
    DispatchQueue.main.async {
      self.channel?.invokeMethod("onPose", arguments: payload)
    }
  }

  private func disposeResources() {
    stopCameraStream()
    videoOutput.setSampleBufferDelegate(nil, queue: nil)
    #if canImport(MediaPipeTasksVision)
    poseLandmarker = nil
    #endif
  }

  private func normalizedLabel(_ index: Int) -> String {
    let labels = [
      "nose", "left_eye_inner", "left_eye", "left_eye_outer",
      "right_eye_inner", "right_eye", "right_eye_outer", "left_ear", "right_ear",
      "mouth_left", "mouth_right", "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
      "left_wrist", "right_wrist", "left_pinky", "right_pinky", "left_index", "right_index",
      "left_thumb", "right_thumb", "left_hip", "right_hip", "left_knee", "right_knee",
      "left_ankle", "right_ankle", "left_heel", "right_heel", "left_foot_index", "right_foot_index"
    ]
    return labels.indices.contains(index) ? labels[index] : "unknown_\(index)"
  }

  #if canImport(MediaPipeTasksVision)
  private func serialize(result: PoseLandmarkerResult?) -> [[String: Any]] {
    guard let first = result?.landmarks.first else {
      return []
    }
    return first.enumerated().map { index, landmark in
      [
        "type": normalizedLabel(index),
        "x": landmark.x,
        "y": landmark.y,
        "z": landmark.z,
        "visibility": landmark.visibility ?? 0
      ]
    }
  }
  #else
  private func serialize(result: Any?) -> [[String: Any]] { [] }
  #endif
}

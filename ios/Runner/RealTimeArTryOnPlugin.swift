import Flutter
import ARKit
import SceneKit
import UIKit

final class RealTimeArTryOnPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var lastConfig: [String: Any] = [:]
  private var activeViews: [RealTimeArTryOnView] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "abzora/realtime_ar_try_on", binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "abzora/realtime_ar_try_on/events", binaryMessenger: messenger)
    super.init()
    eventChannel.setStreamHandler(self)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RealTimeArTryOnPlugin(messenger: registrar.messenger())
    registrar.register(
      RealTimeArTryOnViewFactory(messenger: registrar.messenger(), plugin: instance),
      withId: "abzora/native_ar_try_on_view"
    )
    registrar.addMethodCallDelegate(instance, channel: instance.channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize", "updateGarment":
      lastConfig = call.arguments as? [String: Any] ?? [:]
      activeViews.forEach { $0.applyConfig(lastConfig) }
      emit(state: "configured")
      result(nil)
    case "updatePoseFrame":
      let args = call.arguments as? [String: Any] ?? [:]
      activeViews.forEach { $0.updatePose(args) }
      emit(state: "pose_updated")
      result(nil)
    case "setCameraFacing":
      emit(state: "camera_switched")
      result(nil)
    case "capturePreview":
      let filename = "ar_preview_\(UUID().uuidString).jpg"
      let previewPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)
      emit(state: "capture_requested")
      if let view = activeViews.first, view.capturePreview(to: previewPath) {
        emitCaptureComplete(path: previewPath)
        result(previewPath)
      } else {
        emitRenderError(code: "capture_failed", message: "Unable to capture AR preview frame.")
        result(nil)
      }
    case "pause":
      activeViews.forEach { $0.pause() }
      emit(state: "paused")
      result(nil)
    case "resume":
      activeViews.forEach { $0.resume() }
      emit(state: "resumed")
      result(nil)
    case "dispose":
      lastConfig = [:]
      activeViews.forEach { $0.reset() }
      emit(state: "disposed")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func emit(state: String) {
    eventSink?([
      "state": state,
      "renderer": "ios_native_hybrid",
      "arkitSupported": ARConfiguration.isSupported,
      "occlusionEnabled": (lastConfig["enableOcclusion"] as? Bool) ?? false,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000)
    ])
  }

  private func emitCaptureComplete(path: String) {
    eventSink?([
      "type": "capture_complete",
      "path": path,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000)
    ])
  }

  private func emitRenderError(code: String, message: String) {
    eventSink?([
      "type": "renderer_error",
      "code": code,
      "message": message,
      "timestampMs": Int(Date().timeIntervalSince1970 * 1000)
    ])
  }

  func attach(view: RealTimeArTryOnView) {
    activeViews.append(view)
    if !lastConfig.isEmpty {
      view.applyConfig(lastConfig)
    }
  }
}

final class RealTimeArTryOnViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let plugin: RealTimeArTryOnPlugin

  init(messenger: FlutterBinaryMessenger, plugin: RealTimeArTryOnPlugin) {
    self.messenger = messenger
    self.plugin = plugin
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let view = RealTimeArTryOnView(frame: frame, viewId: viewId, args: args as? [String: Any] ?? [:])
    plugin.attach(view: view)
    return view
  }
}

final class RealTimeArTryOnView: NSObject, FlutterPlatformView {
  private let rootView: ARSCNView
  private let garmentNode = SCNNode()
  private let placeholderNode = SCNNode()
  private let contactShadowNode = SCNNode()

  init(frame: CGRect, viewId: Int64, args: [String: Any]) {
    rootView = ARSCNView(frame: frame)
    rootView.backgroundColor = UIColor.clear
    rootView.automaticallyUpdatesLighting = true
    super.init()
    configureScene()
    applyConfig(args)
    startSessionIfSupported()
  }

  func view() -> UIView {
    rootView
  }

  func applyConfig(_ config: [String: Any]) {
    let overlayAssetUrl =
      (config["transparentAssetUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? (config["transparentAssetUrl"] as? String ?? "")
      : (config["overlayAssetUrl"] as? String ?? "")

    guard !overlayAssetUrl.isEmpty else { return }

    guard let url = URL(string: overlayAssetUrl) else { return }
    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard
        let self,
        let data,
        let image = UIImage(data: data)
      else { return }
      DispatchQueue.main.async {
        self.garmentNode.geometry?.firstMaterial?.diffuse.contents = image
        self.garmentNode.opacity = 0.96
      }
    }.resume()
  }

  func updatePose(_ args: [String: Any]) {
    guard
      let poseFrame = args["poseFrame"] as? [String: Any],
      let leftShoulder = point(from: poseFrame["leftShoulder"]),
      let rightShoulder = point(from: poseFrame["rightShoulder"]),
      let leftHip = point(from: poseFrame["leftHip"]),
      let rightHip = point(from: poseFrame["rightHip"])
    else { return }

    let bodyDetected = args["bodyDetected"] as? Bool ?? true
    guard bodyDetected else {
      DispatchQueue.main.async {
        self.garmentNode.opacity = 0.24
      }
      return
    }
    let segmentationConfidence =
      max(
        0.0,
        min(
          1.0,
          (poseFrame["segmentationConfidence"] as? Double) ??
            ((args["segmentationConfidence"] as? Double) ?? 0.5)
        )
      )
    let renderQuality =
      max(
        0.35,
        min(
          1.0,
          (poseFrame["renderQuality"] as? Double) ??
            ((args["renderQuality"] as? Double) ?? 0.8)
        )
      )
    let occlusionEnabled =
      (poseFrame["occlusionEnabled"] as? Bool) ?? ((args["occlusionEnabled"] as? Bool) ?? false)
    let garmentAlignment = poseFrame["garmentAlignment"] as? [String: Any]
    let garmentDeformation = poseFrame["garmentDeformation"] as? [String: Any]
    let arCompositing = poseFrame["arCompositing"] as? [String: Any]

    let shoulderMid = CGPoint(
      x: (leftShoulder.x + rightShoulder.x) / 2.0,
      y: (leftShoulder.y + rightShoulder.y) / 2.0
    )
    let hipMid = CGPoint(
      x: (leftHip.x + rightHip.x) / 2.0,
      y: (leftHip.y + rightHip.y) / 2.0
    )
    let shoulderDistance = hypot(rightShoulder.x - leftShoulder.x, rightShoulder.y - leftShoulder.y)
    let torsoDistance = hypot(hipMid.x - shoulderMid.x, hipMid.y - shoulderMid.y)
    let rotation = atan2(rightShoulder.y - leftShoulder.y, rightShoulder.x - leftShoulder.x)
    let scales = garmentAlignment?["scales"] as? [String: Any]
    let shoulderScale = number(from: scales?["shoulder"], fallback: 1.0, min: 0.78, max: 1.28)
    let chestScale = number(from: scales?["chest"], fallback: 1.0, min: 0.8, max: 1.26)
    let torsoScale = number(from: scales?["torso"], fallback: 1.0, min: 0.78, max: 1.3)
    let waistScale = number(from: scales?["waist"], fallback: 1.0, min: 0.76, max: 1.26)
    let hipScale = number(from: scales?["hip"], fallback: 1.0, min: 0.78, max: 1.28)
    let torsoMap = garmentDeformation?["torso"] as? [String: Any]
    let torsoScaleX = number(from: torsoMap?["scaleX"], fallback: 1.0, min: 0.82, max: 1.2)
    let torsoScaleY = number(from: torsoMap?["scaleY"], fallback: 1.0, min: 0.82, max: 1.2)
    let widthScale = (shoulderScale * 0.45) + (chestScale * 0.35) + (torsoScaleX * 0.2)
    let heightScale = (torsoScale * 0.35) + (waistScale * 0.25) + (hipScale * 0.2) + (torsoScaleY * 0.2)
    let anchors = garmentAlignment?["anchors"] as? [String: Any]
    let centerAnchor = point(from: anchors?["center"])
    let alignmentCenter = CGPoint(x: centerAnchor?.x ?? shoulderMid.x, y: centerAnchor?.y ?? shoulderMid.y)
    let shadowOpacity = number(from: arCompositing?["shadowOpacity"], fallback: 0.14, min: 0.08, max: 0.3)
    let contactShadowOpacity = number(from: arCompositing?["contactShadowOpacity"], fallback: 0.18, min: 0.1, max: 0.36)
    let shadowSoftness = number(from: arCompositing?["shadowSoftness"], fallback: 0.5, min: 0.36, max: 0.86)
    let depthSeparation = number(from: arCompositing?["depthSeparation"], fallback: 0.3, min: 0.18, max: 0.62)
    let layeringConfidence = number(from: arCompositing?["layeringConfidence"], fallback: 0.5, min: 0, max: 1)

    DispatchQueue.main.async {
      self.garmentNode.scale = SCNVector3(
        Float(max(0.18, min(1.4, shoulderDistance * 2.1 * widthScale))),
        Float(max(0.22, min(1.8, torsoDistance * 3.1 * heightScale))),
        1
      )
      self.garmentNode.eulerAngles.z = -Float(rotation)
      self.garmentNode.position = SCNVector3(
        Float((alignmentCenter.x - 0.5) * 1.2),
        Float((0.5 - alignmentCenter.y) * 1.6 - 0.08),
        -1.2 + Float(depthSeparation * 0.05)
      )
      let alpha = (0.56 + (segmentationConfidence * 0.2) + (layeringConfidence * 0.2)) * renderQuality
      self.garmentNode.opacity = CGFloat(max(0.15, min(1.0, alpha)))
      self.garmentNode.renderingOrder = occlusionEnabled ? 4 : 1
      self.placeholderNode.opacity = occlusionEnabled ? 0.02 : 0.08
      self.garmentNode.geometry?.firstMaterial?.shininess = CGFloat(0.12 + (layeringConfidence * 0.22))
      self.garmentNode.geometry?.firstMaterial?.lightingModel = .physicallyBased
      self.contactShadowNode.opacity = CGFloat((shadowOpacity * 0.7) + (contactShadowOpacity * 0.3))
      self.contactShadowNode.scale = SCNVector3(
        Float(0.96 + (widthScale * 0.08)),
        Float(0.9 + (heightScale * 0.06)),
        1
      )
      self.contactShadowNode.position = SCNVector3(
        self.garmentNode.position.x,
        self.garmentNode.position.y - 0.05,
        self.garmentNode.position.z - 0.04
      )
      self.contactShadowNode.geometry?.firstMaterial?.transparency =
        CGFloat(max(0.08, min(0.38, shadowOpacity + (shadowSoftness * 0.08))))
    }
  }

  func reset() {
    DispatchQueue.main.async {
      self.garmentNode.opacity = 0
    }
  }

  func pause() {
    rootView.session.pause()
  }

  func resume() {
    startSessionIfSupported()
  }

  private func configureScene() {
    rootView.scene = SCNScene()
    rootView.scene?.background.contents = UIColor.clear

    let plane = SCNPlane(width: 0.52, height: 0.72)
    plane.cornerRadius = 0.02
    plane.firstMaterial?.isDoubleSided = true
    plane.firstMaterial?.lightingModel = .physicallyBased
    plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.12)
    plane.firstMaterial?.transparencyMode = .rgbZero
    garmentNode.geometry = plane
    garmentNode.opacity = 0
    rootView.scene?.rootNode.addChildNode(garmentNode)

    let placeholder = SCNPlane(width: 0.56, height: 0.78)
    placeholder.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.04)
    placeholder.firstMaterial?.isDoubleSided = true
    placeholderNode.geometry = placeholder
    placeholderNode.position = SCNVector3(0, -0.04, -1.25)
    rootView.scene?.rootNode.addChildNode(placeholderNode)

    let contactShadow = SCNPlane(width: 0.58, height: 0.78)
    contactShadow.cornerRadius = 0.03
    contactShadow.firstMaterial?.diffuse.contents = UIColor.black.withAlphaComponent(0.2)
    contactShadow.firstMaterial?.isDoubleSided = true
    contactShadow.firstMaterial?.lightingModel = .constant
    contactShadow.firstMaterial?.transparency = 0.18
    contactShadowNode.geometry = contactShadow
    contactShadowNode.position = SCNVector3(0, -0.08, -1.24)
    contactShadowNode.opacity = 0.16
    rootView.scene?.rootNode.addChildNode(contactShadowNode)
  }

  private func startSessionIfSupported() {
    guard ARBodyTrackingConfiguration.isSupported || ARWorldTrackingConfiguration.isSupported else {
      return
    }

    if ARBodyTrackingConfiguration.isSupported {
      let configuration = ARBodyTrackingConfiguration()
      configuration.isAutoFocusEnabled = true
      rootView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
      return
    }

    let configuration = ARWorldTrackingConfiguration()
    configuration.isLightEstimationEnabled = true
    rootView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
  }

  private func point(from raw: Any?) -> CGPoint? {
    guard
      let dict = raw as? [String: Any],
      let x = dict["x"] as? Double,
      let y = dict["y"] as? Double
    else { return nil }
    return CGPoint(x: x, y: y)
  }

  private func number(from raw: Any?, fallback: Double, min: Double, max: Double) -> Double {
    let value = (raw as? NSNumber)?.doubleValue ?? fallback
    return Swift.max(min, Swift.min(max, value))
  }

  func capturePreview(to path: String) -> Bool {
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: rootView.bounds.size, format: format)
    let image = renderer.image { _ in
      rootView.drawHierarchy(in: rootView.bounds, afterScreenUpdates: true)
    }
    guard let data = image.jpegData(compressionQuality: 0.92) else {
      return false
    }
    do {
      try data.write(to: URL(fileURLWithPath: path), options: .atomic)
      return true
    } catch {
      return false
    }
  }
}

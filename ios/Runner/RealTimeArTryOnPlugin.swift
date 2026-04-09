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
      result(previewPath)
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

    DispatchQueue.main.async {
      self.garmentNode.scale = SCNVector3(
        Float(max(0.18, min(1.4, shoulderDistance * 2.1))),
        Float(max(0.22, min(1.8, torsoDistance * 3.1))),
        1
      )
      self.garmentNode.eulerAngles.z = -Float(rotation)
      self.garmentNode.position = SCNVector3(
        Float((shoulderMid.x - 0.5) * 1.2),
        Float((0.5 - shoulderMid.y) * 1.6 - 0.08),
        -1.2
      )
      self.garmentNode.opacity = 0.96
    }
  }

  func reset() {
    DispatchQueue.main.async {
      self.garmentNode.opacity = 0
    }
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
}

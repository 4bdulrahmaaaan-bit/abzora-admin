import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    showNativeSplashOverlay()
  }

  private func showNativeSplashOverlay() {
    guard let window = self.window else {
      return
    }

    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor.black
    overlay.translatesAutoresizingMaskIntoConstraints = false

    let imageName = Bundle.main.object(forInfoDictionaryKey: "LaunchImageName") as? String ?? "LaunchImage"
    let logoView = UIImageView(image: UIImage(named: imageName))
    logoView.contentMode = .scaleAspectFit
    logoView.alpha = 0
    logoView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
    logoView.translatesAutoresizingMaskIntoConstraints = false

    window.addSubview(overlay)
    overlay.addSubview(logoView)

    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
      overlay.topAnchor.constraint(equalTo: window.topAnchor),
      overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
      logoView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      logoView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      logoView.widthAnchor.constraint(equalToConstant: 168),
      logoView.heightAnchor.constraint(equalToConstant: 168)
    ])

    UIView.animate(
      withDuration: 0.32,
      delay: 0,
      options: [.curveEaseOut],
      animations: {
        logoView.alpha = 1
        logoView.transform = .identity
      },
      completion: { _ in
        UIView.animate(
          withDuration: 0.28,
          delay: 0.42,
          options: [.curveEaseOut],
          animations: {
            logoView.transform = CGAffineTransform(scaleX: 1.01, y: 1.01)
            overlay.alpha = 0
          },
          completion: { _ in
            overlay.removeFromSuperview()
          }
        )
      }
    )
  }
}

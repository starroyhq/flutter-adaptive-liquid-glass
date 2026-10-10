import Flutter
import UIKit

/// Keeps every native platform view in the Flutter window on the app theme.
/// This uses only public UIKit APIs; system mode always clears both overrides.
public final class FlutterAdaptiveLiquidGlassPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var appearance: UIUserInterfaceStyle = .unspecified
  private var activationObserver: NSObjectProtocol?

  private init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    activationObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.applyAppearance()
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      AdaptiveLiquidGlassStatusFactory(messenger: registrar.messenger()),
      withId: "flutter_adaptive_liquid_glass/status"
    )
    let channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/appearance", binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(FlutterAdaptiveLiquidGlassPlugin(registrar: registrar), channel: channel)
    registrar.register(AdaptiveLiquidGlassCapsuleFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/capsule")
    registrar.register(AdaptiveLiquidGlassValueControlFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/value-control")
    registrar.register(AdaptiveLiquidGlassPickerFactory(messenger: registrar.messenger(), kind: .date), withId: "flutter_adaptive_liquid_glass/date_picker")
    registrar.register(AdaptiveLiquidGlassPickerFactory(messenger: registrar.messenger(), kind: .color), withId: "flutter_adaptive_liquid_glass/color_picker")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setAppearance" else {
      result(FlutterMethodNotImplemented)
      return
    }
    switch call.arguments as? String {
    case "system": appearance = .unspecified
    case "light": appearance = .light
    case "dark": appearance = .dark
    default:
      result(FlutterError(code: "invalid_appearance", message: "Unknown appearance mode", details: nil))
      return
    }
    applyAppearance()
    result(nil)
  }

  private func applyAppearance() {
    // Resolve lazily: implicit engines may register before attaching their VC.
    guard let controller = registrar.viewController else { return }
    controller.overrideUserInterfaceStyle = appearance
    controller.viewIfLoaded?.window?.overrideUserInterfaceStyle = appearance
  }

  deinit {
    if let activationObserver {
      NotificationCenter.default.removeObserver(activationObserver)
    }
  }
}

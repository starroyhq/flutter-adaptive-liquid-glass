import Flutter
import UIKit

/// Keeps every native platform view in the Flutter window on the app theme,
/// and hides the package's native views beneath Flutter popups.
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
    // One instance answers both channels; `handle` dispatches by method name.
    let plugin = FlutterAdaptiveLiquidGlassPlugin(registrar: registrar)
    for name in ["flutter_adaptive_liquid_glass/appearance", "flutter_adaptive_liquid_glass/lifecycle"] {
      registrar.addMethodCallDelegate(
        plugin, channel: FlutterMethodChannel(name: name, binaryMessenger: registrar.messenger()))
    }
    registrar.register(AdaptiveLiquidGlassCapsuleFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/capsule")
    registrar.register(AdaptiveLiquidGlassSurfaceFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/surface")
    registrar.register(AdaptiveLiquidGlassNavigationBarFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/navigation-bar")
    registrar.register(AdaptiveLiquidGlassValueControlFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/value-control")
    registrar.register(AdaptiveLiquidGlassPickerFactory(messenger: registrar.messenger(), kind: .date), withId: "flutter_adaptive_liquid_glass/date_picker")
    registrar.register(AdaptiveLiquidGlassPickerFactory(messenger: registrar.messenger(), kind: .color), withId: "flutter_adaptive_liquid_glass/color_picker")
    // The tab bar's controller is a child of the view controller known now.
    registrar.register(
      AdaptiveLiquidGlassTabBarFactory(
        messenger: registrar.messenger(), hostViewController: registrar.viewController),
      withId: "flutter_adaptive_liquid_glass/tab-bar")
    registrar.register(AdaptiveLiquidGlassSegmentedControlFactory(messenger: registrar.messenger()), withId: "flutter_adaptive_liquid_glass/segmented-control")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setAppearance":
      setAppearance(call.arguments as? String, result: result)
    case "suppressGlassEffects":
      // Dart counts nested popups and sends only the first and the last.
      NotificationCenter.default.post(name: AdaptiveLiquidGlassSuppression.suppressAll, object: nil)
      result(nil)
    case "unsuppressGlassEffects":
      NotificationCenter.default.post(name: AdaptiveLiquidGlassSuppression.unsuppressAll, object: nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setAppearance(_ mode: String?, result: FlutterResult) {
    switch mode {
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

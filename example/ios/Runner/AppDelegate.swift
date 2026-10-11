import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Example-only driver: exercise the public AX activation entry point.
    // This does not synthesize touch events or invoke the color-change callback.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GlassExampleAccessibility") else { return }
    let channel = FlutterMethodChannel(name: "glass_example/accessibility", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "activateColor", let label = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      func findWell(_ view: UIView) -> UIColorWell? {
        if let well = view as? UIColorWell, well.accessibilityLabel == label { return well }
        for child in view.subviews {
          if let found = findWell(child) { return found }
        }
        return nil
      }
      guard let view = registrar.viewController?.view,
            let well = findWell(view) else {
        result(FlutterError(code: "missing_color_well", message: "The labeled native color well is not mounted.", details: nil))
        return
      }
      result(well.accessibilityActivate())
    }
  }
}

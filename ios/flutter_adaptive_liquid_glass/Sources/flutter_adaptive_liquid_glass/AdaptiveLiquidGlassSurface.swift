import Flutter
import UIKit

final class AdaptiveLiquidGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassSurface(frame: frame, identifier: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger, suppression: suppression)
  }
}

/// The glass material behind a `LiquidGlassSurface`: a plain UIKit
/// `UIVisualEffectView` and an optional fill behind it, both clipped to one
/// rounded shape. Flutter owns every child, so this view never takes input.
///
/// It deliberately avoids SwiftUI hosting. A hosted glass shape lays itself out
/// inside the window's safe area, reading the insets when its platform view
/// lays out. A sheet is created below the screen and slides up, so the shape
/// could stay short by the home-indicator inset, or be missing until something
/// resized it. Plain UIKit sizes the material from the view's own bounds.
private final class AdaptiveLiquidGlassSurface: NSObject, FlutterPlatformView {
  private let root = AdaptiveGlassSurfaceRoot()
  private let fill = UIView()
  private let effectView: UIVisualEffectView
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var suppressionObserver: UUID?
  private let popupOwner: Bool

  init(frame: CGRect, identifier: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    self.suppression = suppression
    popupOwner = arguments["popupOwner"] as? Bool ?? false
    effectView = UIVisualEffectView(effect: nil)
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/surface/\(identifier)", binaryMessenger: messenger)
    super.init()
    root.frame = frame
    root.isUserInteractionEnabled = false
    for shaped in [root, fill, effectView] as [UIView] {
      shaped.clipsToBounds = true
      shaped.layer.cornerCurve = .continuous
    }
    root.addSubview(fill)
    root.addSubview(effectView)
    root.layoutChildren = { [weak self] bounds in
      self?.fill.frame = bounds
      self?.effectView.frame = bounds
    }
    configure(arguments)
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    updateVisibility()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "configure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let config = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_surface_configuration",
                            message: "Expected a surface configuration.", details: nil))
        return
      }
      self.configure(config)
      result(nil)
    }
  }

  func view() -> UIView { root }

  /// Applies a complete configuration. Updates never recreate the view.
  private func configure(_ config: [String: Any]) {
    // The material carries the corner radius itself, as the shared capsule's
    // does, so its rim follows the rounded shape instead of a clipped rectangle.
    let radius = max(0, CGFloat((config["radius"] as? NSNumber)?.doubleValue ?? 24))
    for shaped in [root, fill, effectView] as [UIView] { shaped.layer.cornerRadius = radius }
    root.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    fill.backgroundColor = Self.color(config["backgroundColor"]) ?? .clear
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.tintColor = Self.color(config["tint"])
      effectView.effect = glass
    } else {
      // The Dart adapter never requests this platform view before iOS 26.
      effectView.effect = UIBlurEffect(style: .systemMaterial)
    }
  }

  private func updateVisibility() {
    // A surface inside the popup must not be hidden by its own popup. Route
    // coverage itself is applied from Dart, which stops painting the view.
    let hidden = suppression.active && !popupOwner
    root.isHidden = hidden
    root.accessibilityElementsHidden = true
  }

  deinit {
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

/// Keeps the fill and the material exactly as large as the platform view, on
/// every frame Flutter positions it.
private final class AdaptiveGlassSurfaceRoot: UIView {
  var layoutChildren: ((CGRect) -> Void)?
  override func layoutSubviews() {
    super.layoutSubviews()
    layoutChildren?(bounds)
  }
}

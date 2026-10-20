// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import Flutter
import UIKit

final class AdaptiveLiquidGlassSegmentedControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassSegmentedControl(frame: frame, id: viewId,
      arguments: args as? [String: Any] ?? [:], messenger: messenger,
      suppression: suppression)
  }
}

/// A system `UISegmentedControl` as wide as the platform view, centred
/// vertically at its own height. Only user changes are reported; Flutter
/// updates segments, selection, enabled state and tint in place.
private final class AdaptiveLiquidGlassSegmentedControl: NSObject, FlutterPlatformView {
  private let container: UIView
  private let control = UISegmentedControl()
  private let channel: FlutterMethodChannel
  private var fade: AdaptiveLiquidGlassFade?

  init(frame: CGRect, id: Int64, arguments: [String: Any],
       messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    container = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/segmented-control/\(id)", binaryMessenger: messenger)
    super.init()
    container.backgroundColor = .clear
    control.translatesAutoresizingMaskIntoConstraints = false
    setLabels(arguments["labels"] as? [String] ?? [])
    select((arguments["selectedIndex"] as? NSNumber)?.intValue ?? 0, animated: false)
    control.isEnabled = arguments["enabled"] as? Bool ?? true
    // The system draws the selected segment itself; the tint is kept for
    // whatever UIKit derives from it.
    control.tintColor = Self.color(arguments["color"])
    control.addTarget(self, action: #selector(valueChanged), for: .valueChanged)
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    fade = AdaptiveLiquidGlassFade(
      view: container, suppression: suppression,
      routeSuppressed: arguments["suppressed"] as? Bool ?? false,
      popupOwner: arguments["popupOwner"] as? Bool ?? false)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let arguments = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "updateSegments":
        self.setLabels(arguments["labels"] as? [String] ?? [])
      case "setSelectedIndex":
        if let index = (arguments["index"] as? NSNumber)?.intValue {
          self.select(index, animated: arguments["animated"] as? Bool ?? true)
        }
      case "setEnabled":
        if let enabled = arguments["enabled"] as? Bool { self.control.isEnabled = enabled }
      case "setColor":
        self.control.tintColor = Self.color(arguments["color"])
      case "setSuppressed":
        self.fade?.setRoute(suppressed: arguments["suppressed"] as? Bool ?? false,
                            popupOwner: arguments["popupOwner"] as? Bool ?? false)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  func view() -> UIView { container }

  /// Retitles existing segments in place, keeping the selection where it is
  /// still valid, and adds or removes segments at the end.
  private func setLabels(_ labels: [String]) {
    let selected = control.selectedSegmentIndex
    while control.numberOfSegments > labels.count {
      control.removeSegment(at: control.numberOfSegments - 1, animated: false)
    }
    for (index, label) in labels.enumerated() {
      if index < control.numberOfSegments {
        control.setTitle(label, forSegmentAt: index)
      } else {
        control.insertSegment(withTitle: label, at: index, animated: false)
      }
    }
    if selected != UISegmentedControl.noSegment, !labels.isEmpty {
      control.selectedSegmentIndex = min(selected, labels.count - 1)
    }
  }

  private func select(_ index: Int, animated: Bool) {
    guard index >= 0, index < control.numberOfSegments else { return }
    if animated {
      UIView.animate(withDuration: 0.2) { self.control.selectedSegmentIndex = index }
    } else {
      control.selectedSegmentIndex = index
    }
  }

  @objc private func valueChanged() {
    channel.invokeMethod("valueChanged", arguments: control.selectedSegmentIndex)
  }

  deinit { channel.setMethodCallHandler(nil) }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                   green: CGFloat((argb >> 8) & 255) / 255,
                   blue: CGFloat(argb & 255) / 255,
                   alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

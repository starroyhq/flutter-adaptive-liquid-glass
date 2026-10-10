import Flutter
import UIKit

enum AdaptiveLiquidGlassPickerKind { case date, color }

final class AdaptiveLiquidGlassPickerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let kind: AdaptiveLiquidGlassPickerKind
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger, kind: AdaptiveLiquidGlassPickerKind) {
    self.messenger = messenger
    self.kind = kind
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassPicker(
      frame: frame, identifier: viewId, kind: kind,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger, suppression: suppression
    )
  }
}

/// UIKit controls are retained through all configuration changes. A complete
/// configuration replaces the old state, including nullable colors and bounds.
private final class AdaptiveLiquidGlassPicker: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let control: UIControl
  private let kind: AdaptiveLiquidGlassPickerKind
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var observer: UUID?
  private var popupOwner = false
  private var routeSuppressed = false
  private var configuring = false
  private var revision = 0

  init(frame: CGRect, identifier: Int64, kind: AdaptiveLiquidGlassPickerKind,
       arguments: [String: Any], messenger: FlutterBinaryMessenger,
       suppression: AdaptiveLiquidGlassSuppression) {
    self.kind = kind
    self.suppression = suppression
    control = kind == .date ? UIDatePicker() : UIColorWell()
    let name = kind == .date ? "date" : "color"
    channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/\(name)_picker/\(identifier)",
      binaryMessenger: messenger
    )
    super.init()
    container.frame = frame
    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      control.topAnchor.constraint(equalTo: container.topAnchor),
      control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    observer = suppression.observe { [weak self] in self?.updateVisibility() }
    if let error = configure(arguments) {
      // Invalid initial parameters cannot accidentally expose an enabled picker
      // containing an unrelated default value.
      control.isEnabled = false
      assertionFailure(error.message ?? "Invalid picker configuration")
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "setConfiguration":
        guard let config = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_configuration", message: "Expected a picker configuration.", details: nil))
          return
        }
        result(self.configure(config))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  /// All fallible decoding happens before UIKit mutation. Nulls are assigned
  /// explicitly so clearing a bound/tint/locale works as well as setting it.
  private func configure(_ config: [String: Any]) -> FlutterError? {
    guard let number = config["value"] as? NSNumber,
          number.doubleValue.isFinite else {
      return invalid("A finite value is required.")
    }
    var dateMode: UIDatePicker.Mode = .dateAndTime
    var dateStyle: UIDatePickerStyle = .compact
    var minimum: Date?
    var maximum: Date?
    var interval = 1
    if kind == .date {
      switch config["mode"] as? String {
      case "date": dateMode = .date
      case "time": dateMode = .time
      case "dateAndTime": dateMode = .dateAndTime
      default: return invalid("Invalid date mode.")
      }
      switch config["style"] as? String {
      case "compact": dateStyle = .compact
      case "inline": dateStyle = .inline
      case "wheels": dateStyle = .wheels
      default: return invalid("Invalid date style.")
      }
      interval = (config["minuteInterval"] as? NSNumber)?.intValue ?? 1
      guard [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30].contains(interval) else {
        return invalid("Invalid minute interval.")
      }
      for key in ["minimumDate", "maximumDate"] {
        if let bound = config[key], !(bound is NSNull) {
          guard let value = bound as? NSNumber, value.doubleValue.isFinite else {
            return invalid("Invalid date bound.")
          }
        }
      }
      minimum = Self.date(config["minimumDate"])
      maximum = Self.date(config["maximumDate"])
      if let minimum, let maximum, minimum > maximum {
        return invalid("Minimum date exceeds maximum date.")
      }
    }

    configuring = true
    defer { configuring = false }
    let incomingRevision = (config["revision"] as? NSNumber)?.intValue ?? 0
    let valueIsEcho = config["valueIsEcho"] as? Bool == true && incomingRevision == revision
    revision = incomingRevision
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    container.semanticContentAttribute = config["rtl"] as? Bool == true ? .forceRightToLeft : .forceLeftToRight
    control.semanticContentAttribute = container.semanticContentAttribute
    control.tintColor = Self.color(config["tint"])
    control.accessibilityLabel = config["semanticLabel"] as? String
    control.isEnabled = config["enabled"] as? Bool ?? false
    popupOwner = config["popupOwner"] as? Bool ?? false
    routeSuppressed = config["suppressed"] as? Bool ?? false

    if let date = control as? UIDatePicker {
      let locale = (config["locale"] as? String).map(Locale.init(identifier:))
      // Avoid reassigning native picker properties on every accepted value.
      // Even setting the same selectedColor/date can interrupt a system drag.
      if date.locale != locale { date.locale = locale }
      if date.timeZone != .current { date.timeZone = .current }
      if date.datePickerMode != dateMode { date.datePickerMode = dateMode }
      if date.preferredDatePickerStyle != dateStyle { date.preferredDatePickerStyle = dateStyle }
      if date.minuteInterval != interval { date.minuteInterval = interval }
      if date.minimumDate != minimum || date.maximumDate != maximum {
        date.minimumDate = nil
        date.maximumDate = nil
        date.minimumDate = minimum
        date.maximumDate = maximum
      }
      if !valueIsEcho {
        date.setDate(Date(timeIntervalSince1970: number.doubleValue / 1000), animated: false)
      }
    } else if let well = control as? UIColorWell {
      let supportsAlpha = config["supportsAlpha"] as? Bool ?? true
      if well.supportsAlpha != supportsAlpha { well.supportsAlpha = supportsAlpha }
      let title = config["title"] as? String
      if well.title != title { well.title = title }
      if !valueIsEcho {
        let color = Self.color(number) ?? .clear
        well.selectedColor = supportsAlpha ? color : color.withAlphaComponent(1)
      }
    }
    updateVisibility()
    return nil
  }

  @objc private func changed() {
    guard !configuring, control.isEnabled, !container.isHidden else { return }
    let value: Any
    if let date = control as? UIDatePicker {
      value = Int64((date.date.timeIntervalSince1970 * 1000).rounded())
    } else if let well = control as? UIColorWell, let color = well.selectedColor {
      value = Self.argb(well.supportsAlpha ? color : color.withAlphaComponent(1))
    } else { return }
    channel.invokeMethod("changed", arguments: ["value": value, "revision": revision])
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
  }

  private func invalid(_ message: String) -> FlutterError {
    FlutterError(code: "invalid_configuration", message: message, details: nil)
  }

  private static func date(_ value: Any?) -> Date? {
    guard let number = value as? NSNumber else { return nil }
    return Date(timeIntervalSince1970: number.doubleValue / 1000)
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                   green: CGFloat((argb >> 8) & 255) / 255,
                   blue: CGFloat(argb & 255) / 255,
                   alpha: CGFloat((argb >> 24) & 255) / 255)
  }

  private static func argb(_ color: UIColor) -> UInt32 {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let converted = color.cgColor.converted(to: space, intent: .defaultIntent, options: nil)
    let color = converted.map(UIColor.init(cgColor:)) ?? color
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func byte(_ value: CGFloat) -> UInt32 {
      UInt32((max(0, min(1, value)) * 255).rounded())
    }
    return (byte(alpha) << 24) | (byte(red) << 16) | (byte(green) << 8) | byte(blue)
  }

  deinit {
    channel.setMethodCallHandler(nil)
    control.removeTarget(self, action: #selector(changed), for: .valueChanged)
    if let observer { suppression.remove(observer) }
  }
}

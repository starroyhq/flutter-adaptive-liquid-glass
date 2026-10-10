import Flutter
import UIKit

/// Track the provider's aggregate notifications from plugin registration onward,
/// so a platform view created beneath an existing popup starts hidden as well.
final class AdaptiveLiquidGlassSuppression {
  private(set) var active = false
  private var observers: [NSObjectProtocol] = []
  private var listeners: [UUID: () -> Void] = [:]

  init() {
    for (name, value) in [("LiquidGlassSuppressAll", true), ("LiquidGlassUnsuppressAll", false)] {
      observers.append(NotificationCenter.default.addObserver(
        forName: Notification.Name(name), object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.active = value
        for update in self.listeners.values { update() }
      })
    }
  }
  func observe(_ update: @escaping () -> Void) -> UUID {
    let token = UUID()
    listeners[token] = update
    return token
  }
  func remove(_ token: UUID) { listeners.removeValue(forKey: token) }
  deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

final class AdaptiveLiquidGlassCapsuleFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassCapsule(frame: frame, identifier: viewId, arguments: args as? [String: Any] ?? [:], messenger: messenger, suppression: suppression)
  }
}

/// A single glass material surrounds a row of plain, native UIKit buttons.
/// UILabel/UIButton own title layout; there is no SwiftUI hosting/compression
/// bridge and no individual child glass surface to turn a group into circles.
private final class AdaptiveLiquidGlassCapsule: NSObject, FlutterPlatformView {
  private let container: UIVisualEffectView
  private let stack = UIStackView()
  private let channel: FlutterMethodChannel
  private var buttons: [UIButton] = []
  private let grouped: Bool
  private let suppression: AdaptiveLiquidGlassSuppression
  private let popupOwner: Bool
  private var routeSuppressed: Bool
  private var suppressionObserver: UUID?

  init(frame: CGRect, identifier: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    grouped = arguments["grouped"] as? Bool ?? false
    self.suppression = suppression
    popupOwner = arguments["popupOwner"] as? Bool ?? false
    routeSuppressed = arguments["suppressed"] as? Bool ?? false
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      glass.tintColor = Self.color(arguments["tint"])
      container = UIVisualEffectView(effect: glass)
    } else {
      // The Dart adapter never requests this platform view before iOS 26.
      container = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/capsule/\(identifier)", binaryMessenger: messenger)
    super.init()
    container.frame = frame
    container.layer.cornerRadius = 24
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    container.overrideUserInterfaceStyle = arguments["dark"] as? Bool == true ? .dark : .light
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    updateVisibility()
    stack.axis = .horizontal
    stack.alignment = .fill
    stack.distribution = .fill
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false
    container.contentView.addSubview(stack)
    let inset: CGFloat = grouped ? 4 : 0
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: inset),
      stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -inset),
      stack.topAnchor.constraint(equalTo: container.contentView.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
    ])

    let fontSize = (arguments["fontSize"] as? NSNumber)?.doubleValue ?? 17
    let foreground = Self.color(arguments["foreground"]) ?? .label
    for item in arguments["items"] as? [[String: Any]] ?? [] {
      guard let id = item["id"] as? String else { continue }
      let title = item["title"] as? String
      var config = UIButton.Configuration.plain()
      config.baseForegroundColor = foreground
      config.background.backgroundColor = .clear
      config.imagePadding = 8
      config.imagePlacement = .leading
      config.titleLineBreakMode = .byClipping
      config.contentInsets = title == nil
        ? .zero : NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
      if let title {
        var attributes = AttributeContainer()
        attributes.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: attributes)
      }
      if let symbol = item["symbol"] as? String {
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
      } else if let png = item["png"] as? FlutterStandardTypedData,
                let image = UIImage(data: png.data) {
        let ratio = min(22 / image.size.width, 22 / image.size.height)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        config.image = UIGraphicsImageRenderer(size: size).image { _ in
          image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
      }
      let button = UIButton(configuration: config)
      button.isEnabled = item["enabled"] as? Bool ?? false
      button.accessibilityLabel = item["label"] as? String
      button.accessibilityIdentifier = id
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.adjustsFontSizeToFitWidth = false
      button.setContentCompressionResistancePriority(.required, for: .horizontal)
      button.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      button.addAction(UIAction { [weak self] _ in
        self?.channel.invokeMethod("pressed", arguments: id)
      }, for: .touchUpInside)
      buttons.append(button)
      stack.addArrangedSubview(button)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "intrinsicSize":
        // Measure UIButton's content, never the constrained platform view.
        let width = self.buttons.reduce(self.grouped ? CGFloat(8) : CGFloat(0)) {
          $0 + max(48, $1.intrinsicContentSize.width)
        }
        result(["width": ceil(width), "height": 48])
      case "setSuppressed":
        self.routeSuppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
        self.updateVisibility()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func updateVisibility() {
    // Controls inside the popup must not be hidden by their own popup. A nested
    // popup makes that owner's route non-current, and route suppression wins.
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
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

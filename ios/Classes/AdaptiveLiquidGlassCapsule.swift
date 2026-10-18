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
  private let container: AdaptiveGlassCapsuleContainer
  private let stack = UIStackView()
  private let channel: FlutterMethodChannel
  private var buttons: [AdaptiveGlassCapsuleButton] = []
  private let grouped: Bool
  private let suppression: AdaptiveLiquidGlassSuppression
  private let popupOwner: Bool
  private var routeSuppressed: Bool
  private var suppressionObserver: UUID?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var applicationActive = UIApplication.shared.applicationState == .active
  private var interactionEnabled = true
  private var interactionEpoch = 0
  private var sequence = 0

  init(frame: CGRect, identifier: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    grouped = arguments["grouped"] as? Bool ?? false
    self.suppression = suppression
    popupOwner = arguments["popupOwner"] as? Bool ?? false
    routeSuppressed = arguments["suppressed"] as? Bool ?? false
    interactionEnabled = arguments["interactionEnabled"] as? Bool ?? true
    interactionEpoch = arguments["epoch"] as? Int ?? 0
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      glass.tintColor = Self.color(arguments["tint"])
      container = AdaptiveGlassCapsuleContainer(effect: glass)
    } else {
      // The Dart adapter never requests this platform view before iOS 26.
      container = AdaptiveGlassCapsuleContainer(effect: UIBlurEffect(style: .systemMaterial))
    }
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/capsule/\(identifier)", binaryMessenger: messenger)
    super.init()
    container.frame = frame
    container.layer.cornerRadius = 24
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    container.overrideUserInterfaceStyle = arguments["dark"] as? Bool == true ? .dark : .light
    container.onWindowChanged = { [weak self] in self?.updateVisibility() }
    for (name, active) in [(UIApplication.willResignActiveNotification, false),
                           (UIApplication.didBecomeActiveNotification, true)] {
      lifecycleObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.applicationActive = active
        self?.updateVisibility()
      })
    }
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
      // A capsule narrower than its title ends it with an ellipsis instead of
      // cutting glyphs; the accessibility label keeps the whole text.
      config.titleLineBreakMode = .byTruncatingTail
      config.contentInsets = title == nil
        ? .zero : NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
      if let title {
        var attributes = AttributeContainer()
        attributes.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        var text = AttributedString(title, attributes: attributes)
        if let detail = item["detail"] as? String {
          // A quieter run on the same line, such as a state or current choice.
          var quiet = AttributeContainer()
          quiet.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
          quiet.foregroundColor = foreground.withAlphaComponent(foreground.cgColor.alpha * 0.6)
          text += AttributedString(" " + detail, attributes: quiet)
        }
        config.attributedTitle = text
      }
      let requestedIconSize = (item["iconSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
      let iconSize = requestedIconSize ?? 22
      let iconColor = Self.color(item["iconColor"])
      if let symbol = item["symbol"] as? String {
        // A symbol's point size is a font size, so a 22-point symbol is far
        // larger than a 22-point Material icon. Beside a title the symbol takes
        // the title's font, as UIKit's own buttons do; alone, or at a requested
        // size, it takes the font size whose glyph matches that icon size.
        let symbolConfiguration = requestedIconSize == nil && title != nil
          ? UIImage.SymbolConfiguration(
              font: UIFont.systemFont(ofSize: fontSize, weight: .semibold), scale: .medium)
          : UIImage.SymbolConfiguration(
              pointSize: iconSize * Self.symbolScale, weight: .regular, scale: .medium)
        let image = UIImage(systemName: symbol, withConfiguration: symbolConfiguration)
        config.preferredSymbolConfigurationForImage = symbolConfiguration
        config.image = iconColor.flatMap { image?.withTintColor($0, renderingMode: .alwaysOriginal) } ?? image
      } else if let png = item["png"] as? FlutterStandardTypedData,
                let image = UIImage(data: png.data) {
        let ratio = min(iconSize / image.size.width, iconSize / image.size.height)
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let drawn = UIGraphicsImageRenderer(size: size).image { _ in
          image.draw(in: CGRect(origin: .zero, size: size))
        }
        config.image = iconColor.map { drawn.withTintColor($0, renderingMode: .alwaysOriginal) }
          ?? drawn.withRenderingMode(.alwaysTemplate)
      }
      if item["menuIndicator"] as? Bool == true {
        // The platform's own pop-up affordance for a button that opens a menu.
        config.indicator = .popup
      }
      let button = AdaptiveGlassCapsuleButton(configuration: config)
      button.actionId = id
      button.tapEnabled = item["tapEnabled"] as? Bool ?? (item["enabled"] as? Bool ?? false)
      button.longPressEnabled = item["longPressEnabled"] as? Bool ?? false
      button.isEnabled = button.tapEnabled || button.longPressEnabled
      button.accessibilityLabel = item["label"] as? String
      button.accessibilityIdentifier = id
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.adjustsFontSizeToFitWidth = false
      button.setContentCompressionResistancePriority(.required, for: .horizontal)
      button.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      button.addTarget(self, action: #selector(touchDown(_:)), for: .touchDown)
      button.addTarget(self, action: #selector(pressed(_:event:)), for: .touchUpInside)
      button.onAccessibilityActivate = { [weak self, weak button] longPress in
        guard let self, let button else { return false }
        return self.activate(button, longPress: longPress)
      }
      if button.longPressEnabled {
        let recognizer = AdaptiveGlassCapsuleLongPress(target: self, action: #selector(longPressed(_:)))
        // UIKit is the sole owner of the business gesture. Flutter's recognizer
        // only wins its arena team and releases this touch sequence to UIKit.
        recognizer.cancelsTouchesInView = true
        button.addGestureRecognizer(recognizer)
        button.longPressRecognizer = recognizer
        button.accessibilityCustomActions = [UIAccessibilityCustomAction(
          name: item["longPressLabel"] as? String ?? item["label"] as? String ?? "",
          actionHandler: { [weak self, weak button] _ in
            guard let self, let button else { return false }
            return self.activate(button, longPress: true)
          }
        )]
      }
      buttons.append(button)
      stack.addArrangedSubview(button)
    }
    updateVisibility()
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
        let state = call.arguments as? [String: Any] ?? [:]
        let epoch = state["epoch"] as? Int ?? self.interactionEpoch
        if epoch != self.interactionEpoch { self.cancelInteractions() }
        self.interactionEpoch = epoch
        self.routeSuppressed = state["suppressed"] as? Bool ?? false
        self.interactionEnabled = state["interactionEnabled"] as? Bool ?? true
        self.updateVisibility()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  @objc private func touchDown(_ button: AdaptiveGlassCapsuleButton) {
    button.longPressConsumed = false
    button.pressCancelled = false
  }

  @objc private func pressed(_ button: AdaptiveGlassCapsuleButton, event: UIEvent?) {
    // Long press cancels UIButton tracking. Keep the latch through touch-up too,
    // protecting against a queued touchUpInside from the same sequence.
    if event != nil && (button.longPressConsumed || button.pressCancelled) { return }
    _ = activate(button, longPress: false)
  }

  @objc private func longPressed(_ recognizer: UILongPressGestureRecognizer) {
    guard recognizer.state == .began,
          let button = recognizer.view as? AdaptiveGlassCapsuleButton,
          !button.longPressConsumed, !button.pressCancelled else { return }
    button.longPressConsumed = true
    button.cancelTracking(with: nil)
    _ = activate(button, longPress: true)
  }

  private func activate(_ button: AdaptiveGlassCapsuleButton, longPress: Bool) -> Bool {
    guard !container.isHidden, container.window != nil,
          interactionEnabled, applicationActive, button.isEnabled,
          longPress ? button.longPressEnabled : button.tapEnabled else { return false }
    sequence += 1
    channel.invokeMethod(longPress ? "longPressed" : "pressed", arguments: [
      "id": button.actionId, "epoch": interactionEpoch, "sequence": sequence,
    ])
    return true
  }

  private func cancelInteractions() {
    for button in buttons {
      button.pressCancelled = true
      button.cancelTracking(with: nil)
      button.longPressRecognizer?.isEnabled = false
    }
  }

  private func updateVisibility() {
    // Controls inside the popup must not be hidden by their own popup. A nested
    // popup makes that owner's route non-current, and route suppression wins.
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    let canInteract = !hidden && interactionEnabled && applicationActive && container.window != nil
    if !canInteract { cancelInteractions() }
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    for button in buttons {
      button.isEnabled = canInteract && (button.tapEnabled || button.longPressEnabled)
      button.longPressRecognizer?.isEnabled = canInteract && button.longPressEnabled
    }
  }

  deinit {
    container.onWindowChanged = nil
    cancelInteractions()
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
  }

  /// The point size of an SF Symbol whose glyph is about as large as a
  /// Material icon of one point.
  static let symbolScale: CGFloat = 0.75

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

private final class AdaptiveGlassCapsuleContainer: UIVisualEffectView {
  var onWindowChanged: (() -> Void)?
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChanged?()
  }
}

private final class AdaptiveGlassCapsuleButton: UIButton {
  var actionId = ""
  var tapEnabled = false
  var longPressEnabled = false
  var longPressConsumed = false
  var pressCancelled = false
  var longPressRecognizer: UILongPressGestureRecognizer?
  var onAccessibilityActivate: ((Bool) -> Bool)?

  override func accessibilityActivate() -> Bool {
    onAccessibilityActivate?(!tapEnabled && longPressEnabled) ?? false
  }
}

private final class AdaptiveGlassCapsuleLongPress: UILongPressGestureRecognizer {
  private var trackedTouch: UITouch?

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    if trackedTouch == nil, let touch = touches.first {
      trackedTouch = touch
      // This is only per-sequence bookkeeping, never a business callback. Raw
      // recognizer touches arrive before Flutter releases UIButton tracking.
      let button = view as? AdaptiveGlassCapsuleButton
      button?.longPressConsumed = false
      button?.pressCancelled = false
    }
    super.touchesBegan(touches, with: event)
  }

  override func reset() {
    trackedTouch = nil
    // Keep the consumed latch until a genuinely new pointer sequence begins.
    super.reset()
  }
}

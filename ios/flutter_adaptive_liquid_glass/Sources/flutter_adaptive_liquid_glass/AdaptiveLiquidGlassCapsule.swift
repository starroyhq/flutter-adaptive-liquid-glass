// The standalone icon's bitmap trimming is adapted from native_liquid_glass
// 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import Flutter
import UIKit

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
  /// A lone icon-only button without a long press. It keeps the look of the
  /// SwiftUI glass button that drew it before: a semibold symbol or a trimmed
  /// bitmap, constant colors in every state, the window's appearance, and a
  /// fade instead of hiding.
  private let standalone: Bool
  private var fade: AdaptiveLiquidGlassFade?
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
    standalone = arguments["standaloneIcon"] as? Bool ?? false
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
    if standalone {
      fade = AdaptiveLiquidGlassFade(view: container, suppression: suppression,
                                     routeSuppressed: routeSuppressed, popupOwner: popupOwner)
    } else {
      container.overrideUserInterfaceStyle = arguments["dark"] as? Bool == true ? .dark : .light
    }
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
        // size, it takes the font size whose glyph matches that icon size. A
        // standalone icon keeps the semibold weight it was drawn with before.
        let symbolConfiguration = standalone
          ? UIImage.SymbolConfiguration(
              pointSize: iconSize * Self.symbolScale, weight: .semibold, scale: .medium)
          : requestedIconSize == nil && title != nil
          ? UIImage.SymbolConfiguration(
              font: UIFont.systemFont(ofSize: fontSize, weight: .semibold), scale: .medium)
          : UIImage.SymbolConfiguration(
              pointSize: iconSize * Self.symbolScale, weight: .regular, scale: .medium)
        var image = UIImage(systemName: symbol, withConfiguration: symbolConfiguration)
        config.preferredSymbolConfigurationForImage = symbolConfiguration
        if standalone, let symbolImage = image {
          // UIKit centres a symbol's typographic box, which leaves the ink of
          // a glyph such as a trash can off centre; the SwiftUI button this
          // replaces centred the ink.
          image = Self.centringInk(of: symbolImage, in: 48).withRenderingMode(.alwaysTemplate)
        }
        config.image = iconColor.flatMap { image?.withTintColor($0, renderingMode: .alwaysOriginal) } ?? image
      } else if standalone, let png = item["png"] as? FlutterStandardTypedData,
                let image = UIImage(data: png.data) {
        // The glyph arrives centred in a padded square: trim the padding and
        // fit the glyph into an icon-sized square.
        let drawn = Self.fit(Self.trimmingTransparentEdges(of: image), in: iconSize)
        config.image = iconColor.map { drawn.withTintColor($0, renderingMode: .alwaysOriginal) }
          ?? drawn.withRenderingMode(.alwaysTemplate)
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
      if standalone {
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in foreground }
      }
      let button = AdaptiveGlassCapsuleButton(configuration: config)
      if standalone {
        // Highlighted and disabled states keep the configuration as it is,
        // as the SwiftUI button style that returned its label unchanged did.
        let fixed = config
        button.configurationUpdateHandler = { button in button.configuration = fixed }
      }
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

  /// Hidden by its own route, or by a popup it does not belong to. Controls
  /// inside the popup must not be hidden by their own popup. A nested popup
  /// makes that owner's route non-current, and route suppression wins.
  private var suppressed: Bool { routeSuppressed || (suppression.active && !popupOwner) }

  private func activate(_ button: AdaptiveGlassCapsuleButton, longPress: Bool) -> Bool {
    // A standalone icon fades rather than hides, so its state is checked.
    guard standalone ? !suppressed : !container.isHidden, container.window != nil,
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
    let hidden = suppressed
    let canInteract = !hidden && interactionEnabled && applicationActive && container.window != nil
    if !canInteract { cancelInteractions() }
    if let fade {
      fade.setRoute(suppressed: routeSuppressed, popupOwner: popupOwner)
    } else {
      container.isHidden = hidden
    }
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

  /// Draws [image] aspect-fit and centred in a square of [side] points.
  private static func fit(_ image: UIImage, in side: CGFloat) -> UIImage {
    guard image.size.width > 0, image.size.height > 0 else { return image }
    let scale = min(side / image.size.width, side / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: side, height: side), format: UIGraphicsImageRendererFormat.preferred())
    return renderer.image { context in
      context.cgContext.interpolationQuality = .high
      image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2,
                            width: size.width, height: size.height))
    }
  }

  /// Draws a symbol into a square of [side] points with its ink centred, on
  /// whole device pixels and rounding half a pixel right and down.
  private static func centringInk(of symbol: UIImage, in side: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat.preferred()
    // An 8-bit bitmap, so that its alpha can be read; only alpha is used.
    format.preferredRange = .standard
    let scale = format.scale
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
    let origin = CGPoint(x: ((side - symbol.size.width) / 2 * scale).rounded(.down) / scale,
                         y: ((side - symbol.size.height) / 2 * scale).rounded(.down) / scale)
    let drawn = renderer.image { _ in symbol.draw(at: origin) }
    // Ink is where the glyph covers at least half a pixel.
    guard let cgImage = drawn.cgImage, let ink = opaqueBounds(of: cgImage, threshold: 128) else {
      return symbol
    }
    let pixels = side * scale
    let dx = ((pixels - ink.width) / 2).rounded(.up) - ink.minX
    let dy = ((pixels - ink.height) / 2).rounded(.up) - ink.minY
    let centred = renderer.image { _ in
      symbol.draw(at: CGPoint(x: origin.x + dx / scale, y: origin.y + dy / scale))
    }
    return symbol.flipsForRightToLeftLayoutDirection
      ? centred.imageFlippedForRightToLeftLayoutDirection() : centred
  }

  /// The pixel rectangle of a bitmap whose alpha is at least [threshold].
  private static func opaqueBounds(of cgImage: CGImage, threshold: UInt8) -> CGRect? {
    guard cgImage.width > 0, cgImage.height > 0, cgImage.bitsPerComponent == 8,
          let alphaIndex = alphaByteIndex(cgImage),
          cgImage.bitsPerPixel / 8 >= 4,
          let data = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else { return nil }
    let width = cgImage.width, height = cgImage.height
    let bytesPerPixel = cgImage.bitsPerPixel / 8, bytesPerRow = cgImage.bytesPerRow
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
      for x in 0..<width where bytes[y * bytesPerRow + x * bytesPerPixel + alphaIndex] >= threshold {
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
      }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
  }

  /// Crops fully transparent rows and columns from every edge of a bitmap.
  private static func trimmingTransparentEdges(of image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage,
          let bounds = opaqueBounds(of: cgImage, threshold: 1) else { return image }
    if bounds.width == CGFloat(cgImage.width), bounds.height == CGFloat(cgImage.height) { return image }
    guard let cropped = cgImage.cropping(to: bounds) else { return image }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
  }

  /// The byte holding alpha within a pixel; a little-endian 32-bit bitmap,
  /// as UIKit renderers create, stores its components in reverse.
  private static func alphaByteIndex(_ image: CGImage) -> Int? {
    let reversed = image.byteOrderInfo == .order32Little
    switch image.alphaInfo {
    case .premultipliedFirst, .first, .noneSkipFirst: return reversed ? 3 : 0
    case .premultipliedLast, .last, .noneSkipLast: return reversed ? 0 : 3
    default: return nil
    }
  }

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

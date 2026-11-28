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

/// A standalone UIButton supplies its own glass. Grouped buttons still share
/// one glass backdrop, with a plain configuration on each item.
private final class AdaptiveLiquidGlassCapsule: NSObject, FlutterPlatformView {
  private let container: AdaptiveGlassCapsuleContainer
  private let groupEffect: UIVisualEffectView?
  private let stack = UIStackView()
  private let channel: FlutterMethodChannel
  private var buttons: [AdaptiveGlassCapsuleButton] = []
  /// What each button shows apart from its colors, prepared once.
  private var contents: [AdaptiveGlassCapsuleContent] = []
  private let grouped: Bool
  /// Preserve the icon-only button's glyph layout and route fade.
  private let standalone: Bool
  private let customMenuTrigger: Bool
  /// Flutter's text direction, which orders the buttons and places each
  /// image beside its title, independently of the device language.
  private let rightToLeft: Bool
  private let fontSize: CGFloat
  /// The colors as Dart last sent them; an update redraws a button only when
  /// they change.
  private var foregroundValue: NSNumber?
  private var tintValue: NSNumber?
  private var prominent: Bool
  private var loading: Bool
  private var iconColorValues: [NSNumber?] = []
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
    customMenuTrigger = arguments["customMenuTrigger"] as? Bool ?? false
    rightToLeft = arguments["rtl"] as? Bool == true
    fontSize = CGFloat((arguments["fontSize"] as? NSNumber)?.doubleValue ?? 17)
    foregroundValue = arguments["foreground"] as? NSNumber
    tintValue = arguments["tint"] as? NSNumber
    prominent = arguments["prominent"] as? Bool ?? false
    loading = arguments["loading"] as? Bool ?? false
    self.suppression = suppression
    popupOwner = arguments["popupOwner"] as? Bool ?? false
    routeSuppressed = arguments["suppressed"] as? Bool ?? false
    interactionEnabled = arguments["interactionEnabled"] as? Bool ?? true
    interactionEpoch = arguments["epoch"] as? Int ?? 0
    container = AdaptiveGlassCapsuleContainer(frame: frame)
    groupEffect = grouped ? UIVisualEffectView(effect: Self.groupMaterial(tintValue)) : nil
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/capsule/\(identifier)", binaryMessenger: messenger)
    super.init()
    if let groupEffect {
      groupEffect.frame = container.bounds
      groupEffect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      groupEffect.layer.cornerRadius = 24
      groupEffect.layer.cornerCurve = .continuous
      groupEffect.clipsToBounds = true
      container.addSubview(groupEffect)
    }
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
    let direction: UISemanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = direction
    let contentView = groupEffect?.contentView ?? container
    contentView.semanticContentAttribute = direction
    if #available(iOS 17.0, *) {
      // Buttons resolve a symbol with a right-to-left variant, such as
      // arrow.backward, in this direction too.
      container.traitOverrides.layoutDirection = rightToLeft ? .rightToLeft : .leftToRight
    }
    stack.semanticContentAttribute = direction
    stack.axis = .horizontal
    stack.alignment = .fill
    stack.distribution = .fill
    stack.spacing = 0
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(stack)
    let inset: CGFloat = grouped ? 4 : 0
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
      stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
      stack.topAnchor.constraint(equalTo: contentView.topAnchor),
      stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])

    let foreground = Self.color(arguments["foreground"]) ?? .label
    for item in arguments["items"] as? [[String: Any]] ?? [] {
      guard let id = item["id"] as? String else { continue }
      let content = makeContent(item)
      let iconColorValue = item["iconColor"] as? NSNumber
      let (configuration, prominentForeground) = makeConfigurations(content, foreground: foreground,
                                                                   iconColor: Self.color(iconColorValue))
      let button: AdaptiveGlassCapsuleButton
      if !grouped, arguments["menuEnabled"] is Bool {
        let menuButton = AdaptiveGlassMenuButton(configuration: configuration)
        menuButton.onMenuResult = { [weak self, weak menuButton] revision, itemID in
          guard let self, let menuButton else { return }
          self.sendMenuResult(menuButton, revision: revision, itemID: itemID)
        }
        menuButton.applyMenu(arguments)
        button = menuButton
      } else {
        button = AdaptiveGlassCapsuleButton(configuration: configuration)
      }
      contents.append(content)
      iconColorValues.append(iconColorValue)
      button.semanticContentAttribute = direction
      button.setProminentForeground(prominentForeground,
                                    iconLoadingColor: standalone && loading ? foreground : nil)
      button.actionId = id
      button.tapEnabled = item["tapEnabled"] as? Bool ?? (item["enabled"] as? Bool ?? false)
      button.longPressEnabled = item["longPressEnabled"] as? Bool ?? false
      button.isEnabled = button.tapEnabled || button.longPressEnabled
      button.accessibilityLabel = item["label"] as? String
      button.accessibilityIdentifier = id
      button.titleLabel?.numberOfLines = 1
      button.titleLabel?.adjustsFontSizeToFitWidth = false
      button.setContentCompressionResistancePriority(.required, for: .horizontal)
      if !customMenuTrigger {
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      }
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
      case "update":
        // Each action's enabled state and the colors, applied to this view
        // item by item; the actions themselves are unchanged.
        let state = call.arguments as? [String: Any] ?? [:]
        let epoch = state["epoch"] as? Int ?? self.interactionEpoch
        if epoch != self.interactionEpoch { self.cancelInteractions() }
        self.interactionEpoch = epoch
        self.applyUpdate(state)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  /// What an item shows apart from its colors: its title, and its symbol or
  /// glyph bitmap drawn at the icon size.
  private func makeContent(_ item: [String: Any]) -> AdaptiveGlassCapsuleContent {
    let title = item["title"] as? String
    let requestedIconSize = (item["iconSize"] as? NSNumber).map { CGFloat($0.doubleValue) }
    let iconSize = requestedIconSize ?? 22
    var symbolConfiguration: UIImage.SymbolConfiguration?
    var image: UIImage?
    if let symbol = item["symbol"] as? String {
      // A symbol's point size is a font size, so a 22-point symbol is far
      // larger than a 22-point Material icon. Beside a title the symbol takes
      // the title's font, as UIKit's own buttons do; alone, or at a requested
      // size, it takes the font size whose glyph matches that icon size. A
      // standalone icon keeps the semibold weight it was drawn with before.
      let configuration = standalone
        ? UIImage.SymbolConfiguration(
            pointSize: iconSize * Self.symbolScale, weight: .semibold, scale: .medium)
        : requestedIconSize == nil && title != nil
        ? UIImage.SymbolConfiguration(
            font: UIFont.systemFont(ofSize: fontSize, weight: .semibold), scale: .medium)
        : UIImage.SymbolConfiguration(
            pointSize: iconSize * Self.symbolScale, weight: .regular, scale: .medium)
      symbolConfiguration = configuration
      // A semantic symbol such as arrow.backward or chevron.forward has a
      // variant for each layout direction, chosen by this trait rather than
      // by the semantic content attribute. Explicit and symmetric symbols,
      // such as arrow.left or star, are the same in both.
      let layoutDirection = UITraitCollection(
        layoutDirection: rightToLeft ? .rightToLeft : .leftToRight)
      image = UIImage(systemName: symbol,
                      withConfiguration: configuration.withTraitCollection(layoutDirection))
      if standalone, let symbolImage = image {
        // UIKit centres a symbol's typographic box, which leaves the ink of
        // a glyph such as a trash can off centre; the SwiftUI button this
        // replaces centred the ink.
        image = Self.centringInk(of: symbolImage, in: 48, rightToLeft: rightToLeft)
          .withRenderingMode(.alwaysTemplate)
      }
    } else if standalone, let png = item["png"] as? FlutterStandardTypedData,
              let bitmap = UIImage(data: png.data) {
      // The glyph arrives centred in a padded square: trim the padding and
      // fit the glyph into an icon-sized square.
      image = Self.fit(Self.trimmingTransparentEdges(of: bitmap), in: iconSize)
    } else if let png = item["png"] as? FlutterStandardTypedData,
              let bitmap = UIImage(data: png.data) {
      let ratio = min(iconSize / bitmap.size.width, iconSize / bitmap.size.height)
      let size = CGSize(width: bitmap.size.width * ratio, height: bitmap.size.height * ratio)
      image = UIGraphicsImageRenderer(size: size).image { _ in
        bitmap.draw(in: CGRect(origin: .zero, size: size))
      }
    }
    if symbolConfiguration == nil, item["mirror"] as? Bool == true, let drawn = image {
      // Flutter draws every glyph left to right; one that follows the text
      // direction, such as a back arrow, is mirrored here.
      image = Self.mirrored(drawn)
    }
    return AdaptiveGlassCapsuleContent(
      title: title, detail: item["detail"] as? String,
      symbolConfiguration: symbolConfiguration, image: image,
      menuIndicator: item["menuIndicator"] as? Bool == true)
  }

  private func makeConfigurations(_ content: AdaptiveGlassCapsuleContent, foreground: UIColor,
                                  iconColor: UIColor?) -> (UIButton.Configuration, UIButton.Configuration?) {
    if customMenuTrigger {
      var config = UIButton.Configuration.plain()
      config.background.backgroundColor = .clear
      config.background.backgroundColorTransformer = UIConfigurationColorTransformer { _ in .clear }
      config.baseForegroundColor = .clear
      config.contentInsets = .zero
      return (config, nil)
    }
    var config = UIButton.Configuration.plain()
    config.background.backgroundColor = .clear
    var prominentForeground: UIButton.Configuration?
    if !grouped, #available(iOS 26.0, *) {
      config = prominent ? .prominentGlass() : .glass()
      config.baseBackgroundColor = Self.color(tintValue)
      config.showsActivityIndicator = loading && !prominent
      if prominent {
        // UIKit's glass vibrancy can recolor the foreground even after the
        // configuration resolves its colors. Keep the native button for the
        // glass, layout, and interaction, and draw the same content above it.
        var plain = UIButton.Configuration.plain()
        plain.background.backgroundColor = .clear
        plain.showsActivityIndicator = loading && !standalone
        prominentForeground = makeConfiguration(content, in: plain, foreground: foreground,
                                                iconColor: iconColor, fixedForeground: true)
      }
    }
    let usesOverlay = prominentForeground != nil
    let button = makeConfiguration(content, in: config, foreground: usesOverlay ? .clear : foreground,
                                   iconColor: usesOverlay ? nil : iconColor, fixedForeground: usesOverlay)
    return (button, prominentForeground)
  }

  /// The same title and image metrics are used for both configurations.
  private func makeConfiguration(_ content: AdaptiveGlassCapsuleContent, in configuration: UIButton.Configuration,
                                 foreground: UIColor, iconColor: UIColor?,
                                 fixedForeground: Bool) -> UIButton.Configuration {
    var config = configuration
    config.baseForegroundColor = foreground
    if fixedForeground {
      config.imageColorTransformer = UIConfigurationColorTransformer { _ in iconColor ?? foreground }
      let foregroundTransformer = UIConfigurationColorTransformer { _ in foreground }
      config.activityIndicatorColorTransformer = foregroundTransformer
      config.indicatorColorTransformer = foregroundTransformer
    }
    config.imagePadding = 8
    config.imagePlacement = .leading
    // A capsule narrower than its title ends it with an ellipsis instead of
    // cutting glyphs; the accessibility label keeps the whole text.
    config.titleLineBreakMode = .byTruncatingTail
    config.contentInsets = content.title == nil
      ? .zero : NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    if let title = content.title {
      var attributes = AttributeContainer()
      attributes.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
      if fixedForeground { attributes.foregroundColor = foreground }
      var text = AttributedString(title, attributes: attributes)
      if let detail = content.detail {
        // A quieter run on the same line, such as a state or current choice.
        var quiet = AttributeContainer()
        quiet.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        quiet.foregroundColor = foreground.withAlphaComponent(foreground.cgColor.alpha * 0.6)
        text += AttributedString(" " + detail, attributes: quiet)
      }
      config.attributedTitle = text
    }
    if let symbolConfiguration = content.symbolConfiguration {
      let image = fixedForeground ? content.image?.withRenderingMode(.alwaysTemplate) : content.image
      config.preferredSymbolConfigurationForImage = symbolConfiguration
      config.image = iconColor.flatMap { image?.withTintColor($0, renderingMode: .alwaysOriginal) } ?? image
    } else if let drawn = content.image {
      config.image = iconColor.map { drawn.withTintColor($0, renderingMode: .alwaysOriginal) }
        ?? drawn.withRenderingMode(.alwaysTemplate)
    }
    if content.menuIndicator {
      // The platform's own pop-up affordance for a button that opens a menu.
      config.indicator = .popup
    }
    return config
  }

  /// Updates the mounted button and lets UIKit resolve its current state.
  private func applyUpdate(_ state: [String: Any]) {
    let tintValue = state["tint"] as? NSNumber
    let foregroundValue = state["foreground"] as? NSNumber
    let prominent = state["prominent"] as? Bool ?? self.prominent
    let loading = state["loading"] as? Bool ?? self.loading
    let tintChanged = tintValue != self.tintValue
    let configurationChanged = foregroundValue != self.foregroundValue
      || (!grouped && (tintChanged || prominent != self.prominent || loading != self.loading))
    if tintChanged { groupEffect?.effect = Self.groupMaterial(tintValue) }
    self.tintValue = tintValue
    self.foregroundValue = foregroundValue
    self.prominent = prominent
    self.loading = loading
    let foreground = Self.color(foregroundValue) ?? .label
    let items = state["items"] as? [[String: Any]] ?? []
    for (index, button) in buttons.enumerated() where index < items.count {
      let item = items[index]
      (button as? AdaptiveGlassMenuButton)?.applyMenu(state)
      // A long press is structural: its recognizer exists from creation.
      button.tapEnabled = item["tapEnabled"] as? Bool ?? button.tapEnabled
      let iconColorValue = item["iconColor"] as? NSNumber
      guard configurationChanged || iconColorValue != iconColorValues[index] else { continue }
      iconColorValues[index] = iconColorValue
      let (configuration, prominentForeground) = makeConfigurations(contents[index], foreground: foreground,
                                                                   iconColor: Self.color(iconColorValue))
      button.configuration = configuration
      button.setProminentForeground(prominentForeground,
                                    iconLoadingColor: standalone && loading ? foreground : nil)
    }
    updateVisibility()
  }

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
          interactionEnabled, applicationActive, !loading, button.isEnabled,
          longPress ? button.longPressEnabled : button.tapEnabled else { return false }
    sequence += 1
    channel.invokeMethod(longPress ? "longPressed" : "pressed", arguments: [
      "id": button.actionId, "epoch": interactionEpoch, "sequence": sequence,
    ])
    return true
  }

  private func sendMenuResult(_ button: AdaptiveGlassMenuButton, revision: Int, itemID: Int?) {
    guard !suppressed, container.window != nil, interactionEnabled, applicationActive,
          button.isEnabled, button.menuRevision == revision else { return }
    sequence += 1
    var arguments: [String: Any] = [
      "id": button.actionId, "epoch": interactionEpoch, "sequence": sequence, "revision": revision,
    ]
    if let itemID { arguments["itemId"] = itemID }
    channel.invokeMethod(itemID == nil ? "menuCanceled" : "menuSelected", arguments: arguments)
  }

  private func cancelInteractions() {
    for button in buttons {
      (button as? AdaptiveGlassMenuButton)?.invalidateMenu()
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
      let enabled = (button as? AdaptiveGlassMenuButton)?.canOpenMenu
        ?? (button.tapEnabled || button.longPressEnabled)
      button.isEnabled = canInteract && (button.isProminentLoading || (!loading && enabled))
      button.longPressRecognizer?.isEnabled = canInteract && !loading && button.longPressEnabled
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

  private static func groupMaterial(_ tint: NSNumber?) -> UIVisualEffect {
    guard #available(iOS 26.0, *) else { return UIBlurEffect(style: .systemMaterial) }
    let glass = UIGlassEffect(style: .regular)
    glass.isInteractive = true
    glass.tintColor = color(tint)
    return glass
  }

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

  /// Draws [image] mirrored left to right, at its own size and scale.
  private static func mirrored(_ image: UIImage) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: image.size, format: image.imageRendererFormat)
    return renderer.image { context in
      context.cgContext.translateBy(x: image.size.width, y: 0)
      context.cgContext.scaleBy(x: -1, y: 1)
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  /// Draws a symbol into a square of [side] points with its ink centred, on
  /// whole device pixels and rounding half a pixel right and down. A symbol
  /// that flips for right-to-left layouts is mirrored when [rightToLeft]; the
  /// bitmap no longer flips with the device language.
  private static func centringInk(of symbol: UIImage, in side: CGFloat,
                                  rightToLeft: Bool) -> UIImage {
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
    return rightToLeft && symbol.flipsForRightToLeftLayoutDirection ? mirrored(centred) : centred
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

/// What a capsule button shows apart from its colors.
private struct AdaptiveGlassCapsuleContent {
  let title: String?
  let detail: String?
  /// Set for an SF Symbol item, whose image is nil for an unknown name.
  let symbolConfiguration: UIImage.SymbolConfiguration?
  /// The symbol, or the glyph bitmap drawn at the icon size, uncoloured.
  let image: UIImage?
  let menuIndicator: Bool
}

private final class AdaptiveGlassCapsuleContainer: UIView {
  var onWindowChanged: (() -> Void)?
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChanged?()
  }
}

private class AdaptiveGlassCapsuleButton: UIButton {
  var actionId = ""
  var tapEnabled = false
  var longPressEnabled = false
  var longPressConsumed = false
  var pressCancelled = false
  var longPressRecognizer: UILongPressGestureRecognizer?
  var onAccessibilityActivate: ((Bool) -> Bool)?
  private var prominentForeground: UIButton?
  private var prominentIconIndicator: UIActivityIndicatorView?
  // A loading button keeps its prominent material, while input and
  // accessibility still treat it as disabled.
  var isProminentLoading: Bool {
    prominentIconIndicator != nil || prominentForeground?.configuration?.showsActivityIndicator == true
  }

  func setProminentForeground(_ configuration: UIButton.Configuration?, iconLoadingColor: UIColor?) {
    guard let configuration else {
      setProminentIconIndicator(color: nil)
      guard let prominentForeground else { return }
      prominentForeground.removeFromSuperview()
      self.prominentForeground = nil
      titleLabel?.alpha = 1
      imageView?.alpha = 1
      invalidateIntrinsicContentSize()
      return
    }
    if let prominentForeground {
      prominentForeground.configuration = configuration
    } else {
      let foreground = UIButton(configuration: configuration)
      foreground.frame = bounds
      foreground.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      foreground.semanticContentAttribute = semanticContentAttribute
      foreground.isUserInteractionEnabled = false
      foreground.isAccessibilityElement = false
      foreground.accessibilityElementsHidden = true
      foreground.titleLabel?.numberOfLines = 1
      foreground.titleLabel?.adjustsFontSizeToFitWidth = false
      addSubview(foreground)
      prominentForeground = foreground
    }
    prominentForeground?.isHidden = iconLoadingColor != nil
    setProminentIconIndicator(color: iconLoadingColor)
    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }

  private func setProminentIconIndicator(color: UIColor?) {
    guard let color else {
      prominentIconIndicator?.removeFromSuperview()
      prominentIconIndicator = nil
      return
    }
    if let prominentIconIndicator {
      prominentIconIndicator.color = color
      return
    }
    // A titleless configuration can stretch its replacement image to the
    // entire icon slot. Center the system indicator at its intrinsic size.
    let indicator = UIActivityIndicatorView(style: .medium)
    indicator.color = color
    indicator.isUserInteractionEnabled = false
    indicator.isAccessibilityElement = false
    indicator.translatesAutoresizingMaskIntoConstraints = false
    addSubview(indicator)
    NSLayoutConstraint.activate([
      indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
      indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
    indicator.startAnimating()
    prominentIconIndicator = indicator
  }

  override var intrinsicContentSize: CGSize {
    // Titled loading buttons measure the overlay. Icon buttons retain the
    // glass button's normal size, which is independent of the indicator.
    if let prominentForeground, prominentForeground.configuration?.showsActivityIndicator == true {
      return prominentForeground.intrinsicContentSize
    }
    return super.intrinsicContentSize
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if let prominentForeground {
      // Keep the native content in its layout to preserve intrinsic size.
      titleLabel?.alpha = 0
      imageView?.alpha = 0
      bringSubviewToFront(prominentForeground)
      if let prominentIconIndicator { bringSubviewToFront(prominentIconIndicator) }
    }
  }

  override var accessibilityTraits: UIAccessibilityTraits {
    get { isProminentLoading ? super.accessibilityTraits.union(.notEnabled) : super.accessibilityTraits }
    set { super.accessibilityTraits = newValue }
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    !isProminentLoading && super.beginTracking(touch, with: event)
  }

  override func accessibilityActivate() -> Bool {
    onAccessibilityActivate?(!tapEnabled && longPressEnabled) ?? false
  }

  func activateSystemAccessibility() -> Bool {
    super.accessibilityActivate()
  }
}

private final class AdaptiveGlassMenuButton: AdaptiveGlassCapsuleButton {
  private final class Presentation {
    let configuration: UIContextMenuConfiguration
    let revision: Int
    var selection: Int?

    init(configuration: UIContextMenuConfiguration, revision: Int) {
      self.configuration = configuration
      self.revision = revision
    }
  }

  private var presentation: Presentation?
  private var menuEnabled = false
  private(set) var menuRevision: Int?
  var onMenuResult: ((Int, Int?) -> Void)?
  var canOpenMenu: Bool { menuEnabled && menu != nil }

  func applyMenu(_ state: [String: Any]) {
    let enabled = state["menuEnabled"] as? Bool ?? menuEnabled
    let model = state["menu"] as? [String: Any]
    let revision = model?["revision"] as? Int
    if !enabled || revision != menuRevision { invalidateMenu() }
    menuEnabled = enabled
    guard revision != menuRevision || menu == nil else { return }
    menuRevision = revision
    guard let revision, let items = model?["items"] as? [[String: Any]], !items.isEmpty else {
      menu = nil
      return
    }
    menu = AdaptiveLiquidGlassMenu.make(items: items) { [weak self] itemID in
      guard let current = self?.presentation, current.revision == revision,
            current.selection == nil else { return }
      current.selection = itemID
    }
    showsMenuAsPrimaryAction = true
    preferredMenuElementOrder = .fixed
  }

  func invalidateMenu() {
    guard presentation != nil else { return }
    presentation = nil
    contextMenuInteraction?.dismissMenu()
  }

  override func accessibilityActivate() -> Bool {
    // Let the UIButton handle menu keyboard and accessibility activation.
    guard isEnabled, canOpenMenu else { return false }
    return activateSystemAccessibility()
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    guard isEnabled, canOpenMenu, let revision = menuRevision else { return }
    presentation = Presentation(configuration: configuration, revision: revision)
  }

  override func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    guard let current = presentation, current.configuration === configuration else { return }
    // UIKit can begin closing before running the UIAction handler. Wait for
    // the dismissal animation before deciding whether it was cancelled.
    let finish = { [weak self] in
      guard let self, self.presentation === current else { return }
      self.presentation = nil
      self.onMenuResult?(current.revision, current.selection)
    }
    if let animator {
      animator.addCompletion(finish)
    } else {
      DispatchQueue.main.async(execute: finish)
    }
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

import Flutter
import UIKit

final class AdaptiveLiquidGlassNavigationBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassNavigationBar(frame: frame, id: viewId,
      arguments: args as? [String: Any] ?? [:], messenger: messenger,
      suppression: suppression)
  }
}

/// A retained UINavigationBar owns both its system glass and standard bar
/// buttons. Business labels must be explicit, otherwise UIKit announces the
/// image's SF Symbol description instead of the action's meaning.
private final class AdaptiveLiquidGlassNavigationBar: NSObject, FlutterPlatformView {
  private let container: AdaptiveNavigationContainer
  private let bar = UINavigationBar()
  private let item = UINavigationItem()
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var suppressionObserver: UUID?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var applicationActive = UIApplication.shared.applicationState == .active
  private var routeSuppressed = false
  private var popupOwner = false
  private var interactionEnabled = true
  private var epoch = 0
  private var sequence = 0
  private var leading: [AdaptiveNavigationItem] = []
  private var actions: [AdaptiveNavigationItem] = []

  init(frame: CGRect, id: Int64, arguments: [String: Any],
       messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    container = AdaptiveNavigationContainer(frame: frame)
    channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/navigation-bar/\(id)", binaryMessenger: messenger)
    self.suppression = suppression
    super.init()
    container.backgroundColor = .clear
    bar.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(bar)
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      bar.topAnchor.constraint(equalTo: container.topAnchor),
      bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    bar.items = [item]
    // Leave UINavigationBarAppearance untouched so UIKit supplies its native
    // Liquid Glass material and bar-button grouping on supported systems.
    configure(arguments)
    container.onWindowChanged = { [weak self] in self?.updateVisibility() }
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    for (name, active) in [(UIApplication.willResignActiveNotification, false),
                           (UIApplication.didBecomeActiveNotification, true)] {
      lifecycleObservers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        self?.applicationActive = active
        self?.updateVisibility()
      })
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "configure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let props = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_navigation_configuration",
                            message: "Expected a navigation configuration.", details: nil))
        return
      }
      self.configure(props)
      result(nil)
    }
  }

  private func configure(_ props: [String: Any]) {
    epoch = props["epoch"] as? Int ?? epoch
    routeSuppressed = props["suppressed"] as? Bool ?? false
    popupOwner = props["popupOwner"] as? Bool ?? false
    interactionEnabled = props["interactionEnabled"] as? Bool ?? true
    let style: UIUserInterfaceStyle = props["dark"] as? Bool == true ? .dark : .light
    container.overrideUserInterfaceStyle = style
    bar.overrideUserInterfaceStyle = style
    let direction: UISemanticContentAttribute = props["rtl"] as? Bool == true
      ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = direction
    bar.semanticContentAttribute = direction
    bar.tintColor = Self.color(props["tintColor"])
    item.title = props["title"] as? String ?? ""
    if #available(iOS 26.0, *) { item.subtitle = props["subtitle"] as? String }
    let nextLeading = updateItems(leading, from: props["leading"] as? [[String: Any]] ?? [])
    let nextActions = updateItems(actions, from: props["actions"] as? [[String: Any]] ?? [])
    // Keep existing UIBarButtonItems when only labels, symbols or colors change,
    // preserving their accessibility focus and UIKit interaction state.
    if !sameItems(leading, nextLeading) { item.leftBarButtonItems = nextLeading }
    if !sameItems(actions, nextActions) { item.rightBarButtonItems = nextActions }
    leading = nextLeading
    actions = nextActions
    updateVisibility()
  }

  private func updateItems(_ previous: [AdaptiveNavigationItem],
                           from props: [[String: Any]]) -> [AdaptiveNavigationItem] {
    var remaining = previous
    return props.compactMap { props in
      guard let id = props["id"] as? String, let label = props["label"] as? String else { return nil }
      let button: AdaptiveNavigationItem
      if let index = remaining.firstIndex(where: { $0.actionId == id }) {
        button = remaining.remove(at: index)
      } else {
        button = AdaptiveNavigationItem(title: nil, style: .plain,
                                        target: self, action: #selector(pressed(_:)))
        button.actionId = id
      }
      if let symbol = props["sfSymbol"] as? String {
        button.title = nil
        button.image = UIImage(systemName: symbol)
      } else {
        button.image = nil
        button.title = label
      }
      button.accessibilityIdentifier = id
      button.accessibilityLabel = label
      button.configuredEnabled = props["enabled"] as? Bool ?? true
      // UIKit's glass bar-button glyphs do not always inherit the bar tint.
      button.tintColor = bar.tintColor
      return button
    }
  }

  private func sameItems(_ lhs: [AdaptiveNavigationItem], _ rhs: [AdaptiveNavigationItem]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
  }

  @objc private func pressed(_ sender: AdaptiveNavigationItem) {
    guard !container.isHidden, container.window != nil, applicationActive,
          interactionEnabled, sender.isEnabled,
          (leading + actions).contains(where: { $0 === sender }) else { return }
    sequence += 1
    channel.invokeMethod("pressed", arguments: [
      "id": sender.actionId, "epoch": epoch, "sequence": sequence,
    ])
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    let interactive = !hidden && interactionEnabled && applicationActive && container.window != nil
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    container.isUserInteractionEnabled = interactive
    for button in leading + actions { button.isEnabled = interactive && button.configuredEnabled }
  }

  func view() -> UIView { container }

  deinit {
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                   green: CGFloat((argb >> 8) & 255) / 255,
                   blue: CGFloat(argb & 255) / 255,
                   alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

private final class AdaptiveNavigationItem: UIBarButtonItem {
  var actionId = ""
  var configuredEnabled = true
}

private final class AdaptiveNavigationContainer: UIView {
  var onWindowChanged: (() -> Void)?
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChanged?()
  }
}

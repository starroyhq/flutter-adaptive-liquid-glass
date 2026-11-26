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
  private let leadingGroup = UIBarButtonItemGroup(barButtonItems: [], representativeItem: nil)
  private let trailingGroup = UIBarButtonItemGroup(barButtonItems: [], representativeItem: nil)
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
      // Leave room for badges that extend above the native button, even in
      // windows whose safe area starts at the top of the screen.
      bar.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
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
    let rightToLeft = props["rtl"] as? Bool == true
    let direction: UISemanticContentAttribute = rightToLeft ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = direction
    bar.semanticContentAttribute = direction
    if #available(iOS 17.0, *) {
      // UINavigationBar's item groups follow the layout-direction trait.
      bar.traitOverrides.layoutDirection = rightToLeft ? .rightToLeft : .leftToRight
    }
    bar.tintColor = Self.color(props["tintColor"])
    item.title = props["title"] as? String ?? ""
    if #available(iOS 26.0, *) { item.subtitle = props["subtitle"] as? String }
    let nextLeading = updateItems(leading, from: props["leading"] as? [[String: Any]] ?? [],
                                  rightToLeft: rightToLeft)
    let nextActions = updateItems(actions, from: props["actions"] as? [[String: Any]] ?? [],
                                  rightToLeft: rightToLeft)
    // Keep existing UIBarButtonItems when only labels, symbols or colors change,
    // preserving their accessibility focus and UIKit interaction state.
    if !sameItems(leading, nextLeading) {
      updateGroup(leadingGroup, with: nextLeading)
      if leading.isEmpty != nextLeading.isEmpty {
        item.leadingItemGroups = nextLeading.isEmpty ? [] : [leadingGroup]
      }
    }
    if !sameItems(actions, nextActions) {
      updateGroup(trailingGroup, with: nextActions)
      if actions.isEmpty != nextActions.isEmpty {
        item.trailingItemGroups = nextActions.isEmpty ? [] : [trailingGroup]
      }
    }
    leading = nextLeading
    actions = nextActions
    updateVisibility()
  }

  private func updateItems(_ previous: [AdaptiveNavigationItem],
                           from props: [[String: Any]], rightToLeft: Bool) -> [AdaptiveNavigationItem] {
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
      let icon = AdaptiveNavigationIcon(
        symbol: props["sfSymbol"] as? String,
        png: (props["png"] as? FlutterStandardTypedData)?.data,
        template: props["template"] as? Bool == true,
        mirror: props["mirror"] as? Bool == true,
        direction: rightToLeft ? .rightToLeft : .leftToRight)
      if button.icon != icon {
        button.icon = icon
        button.image = AdaptiveLiquidGlassMenu.image(
          symbol: icon.symbol, png: icon.png, template: icon.template, mirror: icon.mirror,
          direction: icon.direction)
      }
      let title = button.image == nil ? label : nil
      if button.title != title { button.title = title }
      button.accessibilityIdentifier = id
      button.accessibilityLabel = label
      applyBadge(props["badge"] as? String, to: button)
      button.configuredEnabled = props["enabled"] as? Bool ?? true
      let menu = (props["menu"] as? [String: Any]).flatMap(AdaptiveNavigationMenu.init)
      if (button.menuData == nil) != (menu == nil) {
        // A bar-button item with a menu uses it as the primary action when it
        // has no target/action. UIKit owns menu presentation and gestures.
        button.target = menu == nil ? self : nil
        button.action = menu == nil ? #selector(pressed(_:)) : nil
        button.preferredMenuElementOrder = .fixed
      }
      button.menuData = menu
      // UIKit's glass bar-button glyphs do not always inherit the bar tint.
      button.tintColor = bar.tintColor
      return button
    }
  }

  private func applyBadge(_ value: String?, to button: AdaptiveNavigationItem) {
    if #available(iOS 26.0, *) {
      // Flutter platform view creation and configure both run on the platform
      // thread. UIKit's Swift badge factory requires an explicit main actor.
      MainActor.assumeIsolated {
        let badge = value.map { $0.isEmpty ? UIBarButtonItem.Badge.indicator() : .string($0) }
        if button.badge != badge { button.badge = badge }
      }
    }
  }

  private func updateGroup(_ group: UIBarButtonItemGroup, with buttons: [AdaptiveNavigationItem]) {
    // One UIKit group per side keeps mixed text and image items on a shared
    // glass background. UIKit can collapse the group when space is limited.
    group.barButtonItems = buttons
    if buttons.count > 1 {
      if group.representativeItem == nil {
        group.representativeItem = UIBarButtonItem(
          image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
      }
    } else {
      group.representativeItem = nil
    }
  }

  private func sameItems(_ lhs: [AdaptiveNavigationItem], _ rhs: [AdaptiveNavigationItem]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
  }

  @objc private func pressed(_ sender: AdaptiveNavigationItem) {
    guard sender.menuData == nil, canActivate(sender) else { return }
    sequence += 1
    channel.invokeMethod("pressed", arguments: [
      "id": sender.actionId, "epoch": epoch, "sequence": sequence,
    ])
  }

  private func canActivate(_ sender: AdaptiveNavigationItem) -> Bool {
    guard !container.isHidden, container.window != nil, applicationActive,
          interactionEnabled, sender.isEnabled,
          (leading + actions).contains(where: { $0 === sender }) else { return false }
    return true
  }

  private func applyMenu(to button: AdaptiveNavigationItem) {
    guard button.isEnabled, let menu = button.menuData, !menu.items.isEmpty else {
      if button.menu != nil {
        button.menuGeneration += 1
        button.menu = nil
      }
      return
    }
    let epoch = self.epoch
    if button.menu != nil && button.installedMenuEpoch == epoch &&
        button.installedMenuRevision == menu.revision { return }
    button.installedMenuEpoch = epoch
    button.installedMenuRevision = menu.revision
    button.menuGeneration += 1
    let generation = button.menuGeneration
    button.menu = AdaptiveLiquidGlassMenu.make(items: menu.items) { [weak self, weak button] itemId in
      guard let self, let button, self.epoch == epoch, button.menuGeneration == generation,
            button.menuData?.revision == menu.revision, self.canActivate(button) else { return }
      self.sequence += 1
      self.channel.invokeMethod("menuSelected", arguments: [
        "id": button.actionId, "itemId": itemId, "revision": menu.revision,
        "epoch": epoch, "sequence": self.sequence,
      ])
    }
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    let interactive = !hidden && interactionEnabled && applicationActive && container.window != nil
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    container.isUserInteractionEnabled = interactive
    for button in leading + actions {
      button.isEnabled = interactive && button.configuredEnabled && button.menuData?.items.isEmpty != true
      applyMenu(to: button)
    }
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
  var icon: AdaptiveNavigationIcon?
  var menuData: AdaptiveNavigationMenu?
  var installedMenuEpoch: Int?
  var installedMenuRevision: Int?
  var menuGeneration = 0
}

private struct AdaptiveNavigationIcon: Equatable {
  let symbol: String?
  let png: Data?
  let template: Bool
  let mirror: Bool
  let direction: UITraitEnvironmentLayoutDirection
}

private struct AdaptiveNavigationMenu {
  let revision: Int
  let items: [[String: Any]]

  init?(_ props: [String: Any]) {
    guard let revision = props["revision"] as? Int,
          let items = props["items"] as? [[String: Any]] else { return nil }
    self.revision = revision
    self.items = items
  }
}

private final class AdaptiveNavigationContainer: UIView {
  var onWindowChanged: (() -> Void)?
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChanged?()
  }
}

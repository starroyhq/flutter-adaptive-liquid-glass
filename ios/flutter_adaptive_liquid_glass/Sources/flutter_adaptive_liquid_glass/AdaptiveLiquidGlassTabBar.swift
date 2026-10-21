// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import Flutter
import UIKit

final class AdaptiveLiquidGlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private weak var hostViewController: UIViewController?
  private let suppression = AdaptiveLiquidGlassSuppression()

  /// The system tab bar controller becomes a child of the Flutter view
  /// controller that the plugin registrar reported at registration.
  init(messenger: FlutterBinaryMessenger, hostViewController: UIViewController?) {
    self.messenger = messenger
    self.hostViewController = hostViewController
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassTabBar(frame: frame, id: viewId,
      arguments: args as? [String: Any] ?? [:], messenger: messenger,
      hostViewController: hostViewController, suppression: suppression)
  }
}

/// A retained `UITabBarController` whose system tab bar fills the platform
/// view below a transparent band, into which its glass may extend. The Dart
/// adapter requests this view on iOS 26 and later only; earlier systems get an
/// empty view.
private final class AdaptiveLiquidGlassTabBar: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel
  /// An `AdaptiveTabBarControllerView` on iOS 26 and later.
  private var controllerView: UIView?
  private var fade: AdaptiveLiquidGlassFade?

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger,
       hostViewController: UIViewController?, suppression: AdaptiveLiquidGlassSuppression) {
    container = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/tab-bar/\(id)", binaryMessenger: messenger)
    super.init()
    container.clipsToBounds = false
    container.backgroundColor = .clear
    container.isOpaque = false
    container.layer.isOpaque = false
    if #available(iOS 26.0, *) {
      let configuration = AdaptiveTabBarConfiguration(arguments)
      let nativeView = AdaptiveTabBarControllerView(
        configuration: configuration,
        onTabSelected: { [weak self] index in
          self?.channel.invokeMethod("tabSelected", arguments: index)
        },
        onActionPressed: { [weak self] in
          self?.channel.invokeMethod("actionPressed", arguments: nil)
        })
      nativeView.translatesAutoresizingMaskIntoConstraints = false
      nativeView.attach(to: hostViewController)
      container.addSubview(nativeView)
      // The top band stays empty so the glass can extend into it, unclipped,
      // without leaving the frame Flutter composites.
      NSLayoutConstraint.activate([
        nativeView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        nativeView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        nativeView.topAnchor.constraint(
          equalTo: container.topAnchor, constant: configuration.glassOverflow),
        nativeView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      ])
      controllerView = nativeView
    }
    fade = AdaptiveLiquidGlassFade(
      view: container, suppression: suppression,
      routeSuppressed: arguments["suppressed"] as? Bool ?? false,
      popupOwner: arguments["popupOwner"] as? Bool ?? false)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "setSelectedIndex":
        guard let index = (call.arguments as? NSNumber)?.intValue else {
          result(FlutterError(code: "invalid_tab_index",
                              message: "Expected an integer tab index.", details: nil))
          return
        }
        if #available(iOS 26.0, *) {
          (self.controllerView as? AdaptiveTabBarControllerView)?.setSelectedIndex(index)
        }
        result(nil)
      case "updateBadges":
        let badges = (call.arguments as? [Any] ?? []).map { $0 as? String }
        if #available(iOS 26.0, *) {
          (self.controllerView as? AdaptiveTabBarControllerView)?.updateBadges(badges)
        }
        result(nil)
      case "setSuppressed":
        let state = call.arguments as? [String: Any] ?? [:]
        self.fade?.setRoute(suppressed: state["suppressed"] as? Bool ?? false,
                            popupOwner: state["popupOwner"] as? Bool ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  deinit { channel.setMethodCallHandler(nil) }
}

/// A tab or the trailing action, as sent by Dart.
private struct AdaptiveTabItem {
  let label: String
  let image: UIImage?
  let selectedImage: UIImage?
  /// `nil` shows no badge, an empty string a dot, other text a text badge.
  let badge: String?

  init(_ props: [String: Any]) {
    label = props["label"] as? String ?? ""
    badge = props["badge"] as? String
    if let symbol = props["symbol"] as? String {
      // Symbols take the tab bar's own size and tint.
      image = UIImage(systemName: symbol)
      selectedImage = UIImage(systemName: props["selectedSymbol"] as? String ?? symbol)
    } else {
      let scale = CGFloat((props["scale"] as? NSNumber)?.doubleValue ?? 1)
      let bitmap = Self.bitmap(props["png"], scale: scale)
      image = bitmap ?? UIImage(systemName: "circle")
      selectedImage = Self.bitmap(props["selectedPng"], scale: scale) ?? image
    }
  }

  /// A glyph Flutter drew at the bar's icon size, decoded at the pixel ratio
  /// it was drawn at and drawn in the tab's tint, selected or not.
  private static func bitmap(_ value: Any?, scale: CGFloat) -> UIImage? {
    guard let data = value as? FlutterStandardTypedData else { return nil }
    return UIImage(data: data.data, scale: max(scale, 1))?.withRenderingMode(.alwaysTemplate)
  }
}

private struct AdaptiveTabBarConfiguration {
  let tabs: [AdaptiveTabItem]
  let action: AdaptiveTabItem?
  let currentIndex: Int
  let selectedItemColor: UIColor?
  /// Mirrors the Flutter theme's brightness, independent of the device.
  let userInterfaceStyle: UIUserInterfaceStyle
  let glassOverflow: CGFloat

  init(_ arguments: [String: Any]) {
    let tabs = (arguments["tabs"] as? [[String: Any]] ?? []).map(AdaptiveTabItem.init)
    self.tabs = tabs
    action = (arguments["action"] as? [String: Any]).map(AdaptiveTabItem.init)
    let requested = (arguments["currentIndex"] as? NSNumber)?.intValue ?? 0
    currentIndex = min(max(0, requested), max(tabs.count - 1, 0))
    selectedItemColor = Self.color(arguments["selectedItemColor"])
    switch arguments["brightness"] as? String {
    case "dark": userInterfaceStyle = .dark
    case "light": userInterfaceStyle = .light
    default: userInterfaceStyle = .unspecified
    }
    glassOverflow = max(0, CGFloat((arguments["glassOverflow"] as? NSNumber)?.doubleValue ?? 0))
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

/// Embeds a `UITabBarController` built with the `UITab` API, applies the
/// selected color and forwards user selection.
@available(iOS 26.0, *)
private final class AdaptiveTabBarControllerView: UIView, UITabBarControllerDelegate {
  /// Kept from the previous provider so existing UI tests still find tabs.
  private static let tabIdentifierPrefix = "liquid-glass-tab-"

  private let configuration: AdaptiveTabBarConfiguration
  private let tabBarController = UITabBarController()
  private let onTabSelected: (Int) -> Void
  private let onActionPressed: () -> Void
  private var defaultTabBarTintColor: UIColor?
  /// Identifiers of the selectable tabs in order, without the action.
  private var tabIdentifiers: [String] = []
  private var actionTabIdentifier: String?
  /// The `UITab` API calls the delegate for programmatic selection as well;
  /// a selection made for Flutter must not be reported back as a tap.
  private var isApplyingProgrammaticSelection = false

  init(configuration: AdaptiveTabBarConfiguration,
       onTabSelected: @escaping (Int) -> Void,
       onActionPressed: @escaping () -> Void) {
    self.configuration = configuration
    self.onTabSelected = onTabSelected
    self.onActionPressed = onActionPressed
    super.init(frame: .zero)
    backgroundColor = .clear
    clipsToBounds = false
    isOpaque = false
    layer.isOpaque = false
    configureTabBarController()
    applyUserInterfaceStyle()
    registerForTraitChanges(Self.refreshingTraits) { (view: AdaptiveTabBarControllerView, _: UITraitCollection) in
      view.refreshTabBarVisuals()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private static let refreshingTraits: [UITrait] =
    UITraitCollection.systemTraitsAffectingColorAppearance + [
      UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self,
      UITraitPreferredContentSizeCategory.self, UITraitLayoutDirection.self,
    ]

  /// Pins the bar to the Flutter theme. Navigation detaches and reattaches the
  /// platform view, after which UIKit would resolve dynamic colors against the
  /// device appearance; the style is asserted again on reattachment.
  private func applyUserInterfaceStyle() {
    tabBarController.overrideUserInterfaceStyle = configuration.userInterfaceStyle
    overrideUserInterfaceStyle = configuration.userInterfaceStyle
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }
    // A reattached bar can fall back to the appearance's baked-in colors.
    applyUserInterfaceStyle()
    applySelectedTintColor()
  }

  /// UIKit requires controller containment for an embedded controller.
  func attach(to parent: UIViewController?) {
    guard let parent, tabBarController.parent !== parent else { return }
    if tabBarController.parent != nil {
      tabBarController.willMove(toParent: nil)
      tabBarController.removeFromParent()
    }
    parent.addChild(tabBarController)
    tabBarController.didMove(toParent: parent)
    // Containment can recalculate the bar's rendering.
    applySelectedTintColor()
  }

  deinit {
    if tabBarController.parent != nil {
      tabBarController.willMove(toParent: nil)
      tabBarController.removeFromParent()
    }
  }

  private func configureTabBarController() {
    tabBarController.view.backgroundColor = .clear
    tabBarController.view.clipsToBounds = false
    tabBarController.view.isOpaque = false
    tabBarController.view.layer.isOpaque = false
    tabBarController.tabs = makeTabs()
    applyProminentActionTab()
    selectTab(at: configuration.currentIndex)
    // Keep the bar a tab bar; other modes may override title colors.
    tabBarController.mode = .tabBar
    // Assigning tabs and the selection invokes the delegate synchronously, so
    // it is set only afterwards; otherwise setup would report taps on tab 0.
    tabBarController.delegate = self

    let tabBar = tabBarController.tabBar
    tabBar.clipsToBounds = false
    tabBar.layer.masksToBounds = false
    if defaultTabBarTintColor == nil { defaultTabBarTintColor = tabBar.tintColor }
    tabBar.itemPositioning = .automatic
    applyTabBarAppearance(to: tabBar)
    // Assign the tint after the appearance so no path falls back to blue.
    applySelectedTintColor()
    embedTabBarControllerView()
  }

  /// One `UITab` per tab, then a `UISearchTab` for the action, which UIKit
  /// draws as the separate round button.
  private func makeTabs() -> [UITab] {
    var tabs: [UITab] = configuration.tabs.enumerated().map { index, item in
      let tab = UITab(title: item.label, image: item.image,
                      identifier: "\(Self.tabIdentifierPrefix)\(index)") { _ in
        Self.makeTabContentController()
      }
      if #available(iOS 26.1, *) {
        // `UITab.selectedImage` is absent from SDKs before 26.1; key-value
        // coding keeps this compiling with them.
        tab.setValue(item.selectedImage, forKey: "selectedImage")
      }
      tab.badgeValue = item.badge
      return tab
    }
    tabIdentifiers = tabs.map { $0.identifier }
    if let action = configuration.action {
      // Selection of this tab is refused in the delegate, so the system search
      // never activates; the tap goes to Flutter instead.
      let search = UISearchTab { _ in Self.makeTabContentController() }
      search.automaticallyActivatesSearch = false
      search.title = action.label
      if let image = action.image { search.image = image }
      if #available(iOS 26.1, *), let selectedImage = action.selectedImage {
        search.setValue(selectedImage, forKey: "selectedImage")
      }
      search.badgeValue = action.badge
      actionTabIdentifier = search.identifier
      tabs.append(search)
    } else {
      actionTabIdentifier = nil
    }
    return tabs
  }

  private static func makeTabContentController() -> UIViewController {
    let controller = UIViewController()
    controller.view.backgroundColor = .clear
    return controller
  }

  /// iOS 27 separates the search tab only when it is the prominent tab. The
  /// direct call needs the iOS 27 SDK; older toolchains set it dynamically, so
  /// apps built with Xcode 26 keep the separate button on iOS 27.
  private func applyProminentActionTab() {
    guard let actionTabIdentifier else { return }
    #if compiler(>=6.4)
      if #available(iOS 27.0, *) {
        tabBarController.setProminentTabIdentifier(actionTabIdentifier, animated: false)
      }
    #else
      if tabBarController.responds(to: NSSelectorFromString("setProminentTabIdentifier:")) {
        tabBarController.setValue(actionTabIdentifier, forKey: "prominentTabIdentifier")
      }
    #endif
  }

  private func selectTab(at index: Int) {
    isApplyingProgrammaticSelection = true
    defer { isApplyingProgrammaticSelection = false }
    guard index >= 0, index < tabIdentifiers.count,
          let tab = tabBarController.tab(forIdentifier: tabIdentifiers[index]) else { return }
    tabBarController.selectedTab = tab
  }

  private var currentSelectedIndex: Int {
    guard let identifier = tabBarController.selectedTab?.identifier,
          let index = tabIdentifiers.firstIndex(of: identifier) else { return 0 }
    return index
  }

  private func refreshTabBarVisuals() {
    let tabBar = tabBarController.tabBar
    tabBar.itemPositioning = .automatic
    applyTabBarAppearance(to: tabBar)
    applySelectedTintColor()
  }

  /// A default-background appearance carrying the selected color in every
  /// item layout; without a selected color the system appearance is kept.
  private func applyTabBarAppearance(to tabBar: UITabBar) {
    guard let color = configuration.selectedItemColor else { return }
    let appearance = UITabBarAppearance()
    appearance.configureWithDefaultBackground()
    for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
                 appearance.compactInlineLayoutAppearance] {
      // The title attributes are assigned explicitly, as the previous
      // provider did, before the selected and focused colors are added.
      let normal = item.normal.titleTextAttributes
      var selected = item.selected.titleTextAttributes
      item.normal.titleTextAttributes = normal
      item.selected.titleTextAttributes = selected
      item.selected.iconColor = color
      selected[.foregroundColor] = color
      item.selected.titleTextAttributes = selected
      item.focused.iconColor = color
      var focused = item.focused.titleTextAttributes
      focused[.foregroundColor] = color
      item.focused.titleTextAttributes = focused
    }
    tabBar.standardAppearance = appearance
    tabBar.scrollEdgeAppearance = appearance
  }

  private func embedTabBarControllerView() {
    guard let controllerView = tabBarController.view else { return }
    controllerView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(controllerView)
    NSLayoutConstraint.activate([
      controllerView.leadingAnchor.constraint(equalTo: leadingAnchor),
      controllerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      controllerView.topAnchor.constraint(equalTo: topAnchor),
      controllerView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  /// The tab bar draws its tint from several levels of the hierarchy, so the
  /// selected color is set on each of them and on the appearance.
  private func applySelectedTintColor() {
    let tabBar = tabBarController.tabBar
    let controllers = tabBarController.tabs.compactMap { $0.viewController }
    guard let color = configuration.selectedItemColor else {
      tabBar.tintColor = defaultTabBarTintColor
      tabBarController.view.tintColor = nil
      tintColor = nil
      for controller in controllers { controller.view.tintColor = nil }
      return
    }
    tabBar.tintColor = color
    tabBarController.view.tintColor = color
    tintColor = color
    for controller in controllers { controller.view.tintColor = color }
    // UIKit redraws from the appearance's own selected color, for example
    // after Flutter navigation, so keep that in step with the tint.
    // A fresh copy makes UIKit observe the change and redraw.
    let appearance = tabBar.standardAppearance.copy()
    for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
                 appearance.compactInlineLayoutAppearance] {
      item.selected.iconColor = color
      var selected = item.selected.titleTextAttributes
      selected[.foregroundColor] = color
      item.selected.titleTextAttributes = selected
      item.focused.iconColor = color
      var focused = item.focused.titleTextAttributes
      focused[.foregroundColor] = color
      item.focused.titleTextAttributes = focused
    }
    tabBar.standardAppearance = appearance
    tabBar.scrollEdgeAppearance = appearance
  }

  /// Selects a tab for Flutter without rebuilding the controller.
  func setSelectedIndex(_ index: Int) {
    guard !tabIdentifiers.isEmpty else { return }
    let clamped = min(max(0, index), tabIdentifiers.count - 1)
    guard currentSelectedIndex != clamped else { return }
    selectTab(at: clamped)
    applySelectedTintColor()
  }

  /// Badges in tab order, then the action's.
  func updateBadges(_ badges: [String?]) {
    let tabs = tabBarController.tabs
    for (index, badge) in badges.enumerated() where index < tabs.count {
      tabs[index].badgeValue = badge
    }
  }

  func tabBarController(_ tabBarController: UITabBarController,
                        shouldSelectTab tab: UITab) -> Bool {
    if tab.identifier == actionTabIdentifier {
      onActionPressed()
      return false
    }
    return true
  }

  func tabBarController(_ tabBarController: UITabBarController,
                        didSelectTab selectedTab: UITab, previousTab: UITab?) {
    guard !isApplyingProgrammaticSelection,
          let index = tabIdentifiers.firstIndex(of: selectedTab.identifier) else { return }
    applySelectedTintColor()
    onTabSelected(index)
  }
}

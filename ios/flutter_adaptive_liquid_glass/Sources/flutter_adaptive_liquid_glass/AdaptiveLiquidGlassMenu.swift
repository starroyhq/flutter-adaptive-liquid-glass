import Flutter
import UIKit

/// Converts the shared menu data into UIKit actions and submenus. The owning
/// control decides when a selection is still valid and how to deliver it.
enum AdaptiveLiquidGlassMenu {
  static func make(
    items: [[String: Any]], onSelect: @escaping (Int) -> Void
  ) -> UIMenu {
    UIMenu(children: items.compactMap { element($0, parentEnabled: true, onSelect: onSelect) })
  }

  private static func element(
    _ item: [String: Any], parentEnabled: Bool, onSelect: @escaping (Int) -> Void
  ) -> UIMenuElement? {
    guard let id = item["id"] as? Int, let label = item["label"] as? String else { return nil }
    let icon = image(item)
    let enabled = parentEnabled && (item["enabled"] as? Bool ?? true)
    let destructive = item["destructive"] as? Bool == true
    let inline = item["displayInline"] as? Bool == true
    let children = item["children"] as? [[String: Any]] ?? []
    if (enabled || inline) && !children.isEmpty {
      var options: UIMenu.Options = []
      if destructive { options.insert(.destructive) }
      if inline { options.insert(.displayInline) }
      let menu = UIMenu(
        title: label, image: icon, options: options,
        children: children.compactMap { element($0, parentEnabled: enabled, onSelect: onSelect) })
      if #available(iOS 15.0, *) { menu.subtitle = item["subtitle"] as? String }
      return menu
    }
    var attributes: UIMenuElement.Attributes = []
    if !enabled { attributes.insert(.disabled) }
    if destructive { attributes.insert(.destructive) }
    let action = UIAction(
      title: label, image: icon, attributes: attributes,
      state: item["selected"] as? Bool == true ? .on : .off
    ) { _ in
      guard enabled, children.isEmpty else { return }
      onSelect(id)
    }
    if #available(iOS 15.0, *) { action.subtitle = item["subtitle"] as? String }
    return action
  }

  private static func image(_ item: [String: Any]) -> UIImage? {
    image(symbol: item["symbol"] as? String,
          png: (item["png"] as? FlutterStandardTypedData)?.data,
          template: item["template"] as? Bool == true,
          mirror: item["mirror"] as? Bool == true)
  }

  static func image(
    symbol: String?, png: Data?, template: Bool, mirror: Bool,
    direction: UITraitEnvironmentLayoutDirection? = nil
  ) -> UIImage? {
    let traits = direction.map { UITraitCollection(layoutDirection: $0) }
    if let symbol, let image = UIImage(systemName: symbol, compatibleWith: traits) {
      return image
    }
    guard let png, let bitmap = UIImage(data: png),
          bitmap.size.width > 0, bitmap.size.height > 0 else { return nil }
    // PNGs arrive in pixels. Fit them to a logical icon size and use the
    // template treatment only for monochrome glyphs supplied by Flutter.
    let ratio = 22 / max(bitmap.size.width, bitmap.size.height)
    let size = CGSize(width: bitmap.size.width * ratio, height: bitmap.size.height * ratio)
    let image = UIGraphicsImageRenderer(size: size).image { _ in
      bitmap.draw(in: CGRect(origin: .zero, size: size))
    }.withRenderingMode(template ? .alwaysTemplate : .alwaysOriginal)
    return mirror ? image.imageFlippedForRightToLeftLayoutDirection() : image
  }
}

/// The imperative menu belongs to the plugin's Flutter view, so it never
/// changes which view is first responder just to provide a UIKit anchor.
final class AdaptiveLiquidGlassMenuPresenter {
  private var current: Presentation?

  func show(arguments: Any?, in view: UIView?, result: @escaping FlutterResult) {
    if #available(iOS 17.4, *), let view, view.window != nil,
       UIApplication.shared.applicationState == .active {
      guard let model = arguments as? [String: Any],
            let requestID = model["requestId"] as? Int,
            let anchor = model["anchor"] as? [Double], anchor.count == 4,
            anchor.allSatisfy(\.isFinite), anchor[2] > 0, anchor[3] > 0,
            let items = model["items"] as? [[String: Any]], !items.isEmpty else {
        result(FlutterError(code: "invalid_menu", message: "Invalid menu contents or anchor", details: nil))
        return
      }
      let rect = CGRect(x: anchor[0], y: anchor[1], width: anchor[2], height: anchor[3])
        .intersection(view.bounds)
      guard !rect.isEmpty else { result(nil); return }
      current?.cancel()
      let presentation = Presentation(requestID: requestID, anchor: rect, items: items, result: result)
      presentation.onFinish = { [weak self, weak presentation] in
        guard let self, self.current === presentation else { return }
        self.current = nil
      }
      current = presentation
      presentation.show(in: view)
      return
    }
    result(Self.unavailable())
  }

  func cancel(requestID: Int?) {
    if let presentation = current, presentation.requestID == requestID {
      presentation.cancel()
    }
  }

  private static func unavailable() -> FlutterError {
    FlutterError(code: "menu_unavailable", message: "UIKit could not present this menu", details: nil)
  }

  private final class Presentation: UIButton {
    let requestID: Int
    private var result: FlutterResult?
    private var presentedConfiguration: UIContextMenuConfiguration?
    private var selection: Int?
    private var observers: [NSObjectProtocol] = []
    private var presentationDeadline: DispatchWorkItem?
    var onFinish: (() -> Void)?

    init(requestID: Int, anchor: CGRect, items: [[String: Any]], result: @escaping FlutterResult) {
      self.requestID = requestID
      self.result = result
      super.init(frame: anchor)
      var config = UIButton.Configuration.plain()
      config.background.backgroundColorTransformer = UIConfigurationColorTransformer { _ in .clear }
      configuration = config
      isAccessibilityElement = false
      menu = AdaptiveLiquidGlassMenu.make(items: items) { [weak self] id in
        guard let self, self.selection == nil else { return }
        self.selection = id
      }
      showsMenuAsPrimaryAction = true
      preferredMenuElementOrder = .fixed
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(requestID:anchor:items:result:)") }

    @available(iOS 17.4, *)
    func show(in view: UIView) {
      view.addSubview(self)
      let center = NotificationCenter.default
      observers = [
        center.addObserver(forName: UIApplication.willResignActiveNotification,
                           object: nil, queue: .main) { [weak self] _ in self?.cancel() },
        center.addObserver(forName: UIWindow.didBecomeHiddenNotification,
                           object: view.window, queue: .main) { [weak self] _ in self?.cancel() },
      ]
      // UIKit can decline a presentation without a delegate callback. Only
      // bound the opening handshake; a visible menu may stay open indefinitely.
      let deadline = DispatchWorkItem { [weak self] in
        self?.finish(AdaptiveLiquidGlassMenuPresenter.unavailable())
      }
      presentationDeadline = deadline
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: deadline)
      performPrimaryAction()
    }

    func cancel() { finish(nil) }

    private func finish(_ outcome: Any?) {
      guard let complete = result else { return }
      result = nil
      presentationDeadline?.cancel()
      presentationDeadline = nil
      observers.forEach(NotificationCenter.default.removeObserver)
      observers.removeAll()
      contextMenuInteraction?.dismissMenu()
      removeFromSuperview()
      onFinish?()
      complete(outcome)
    }

    override func contextMenuInteraction(
      _ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration,
      animator: (any UIContextMenuInteractionAnimating)?
    ) {
      super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
      presentedConfiguration = configuration
      presentationDeadline?.cancel()
      presentationDeadline = nil
    }

    override func contextMenuInteraction(
      _ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration,
      animator: (any UIContextMenuInteractionAnimating)?
    ) {
      super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
      guard presentedConfiguration === configuration else { return }
      // UIKit may start the closing animation before calling the action.
      let finish = { [weak self] in self?.finish(self?.selection) }
      if let animator {
        animator.addCompletion { finish() }
      } else {
        DispatchQueue.main.async { finish() }
      }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
  }
}

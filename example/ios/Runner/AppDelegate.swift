import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var colorLifecycleWindow: UIWindow?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Example-only driver: exercise the public AX activation entry point.
    // This does not synthesize touch events or invoke the color-change callback.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GlassExampleAccessibility") else { return }
    let channel = FlutterMethodChannel(name: "glass_example/accessibility", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard ["activateColor", "activateColorTwice", "enableColorLifecycleControls"].contains(call.method),
            let label = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "enableColorLifecycleControls" {
        guard let self, let host = registrar.viewController,
              let scene = host.viewIfLoaded?.window?.windowScene else {
          result(FlutterError(code: "missing_window", message: "The example window is not mounted.", details: nil))
          return
        }
        let window = ExampleColorLifecycleWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.rootViewController = ExampleColorLifecycleDriver(host: host) { [weak self] in
          self?.colorLifecycleWindow?.isHidden = true
          self?.colorLifecycleWindow = nil
        }
        self.colorLifecycleWindow?.isHidden = true
        self.colorLifecycleWindow = window
        // Do not make this window key: the original host continues to own
        // application focus and the real system picker presentation.
        window.isHidden = false
        result(true)
        return
      }
      func findWell(_ view: UIView) -> UIColorWell? {
        if let well = view as? UIColorWell, well.accessibilityLabel == label { return well }
        for child in view.subviews {
          if let found = findWell(child) { return found }
        }
        return nil
      }
      guard let view = registrar.viewController?.view,
            let well = findWell(view) else {
        result(FlutterError(code: "missing_color_well", message: "The labeled native color well is not mounted.", details: nil))
        return
      }
      if call.method == "activateColorTwice" {
        // Two real public activations in the same run-loop turn exercise the
        // in-flight presentation guard before UIKit's animation completes.
        result([well.accessibilityActivate(), well.accessibilityActivate()])
      } else {
        result(well.accessibilityActivate())
      }
    }
  }
}

/// Example-only controls remain reachable while a real UIKit palette is modal.
/// They issue public presentation methods; no package state or callbacks are
/// exposed. Outside this small toolbar, touches pass to the original app window.
private final class ExampleColorLifecycleWindow: UIWindow {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    return hit === self || hit === rootViewController?.view ? nil : hit
  }
}

private final class ExampleColorLifecycleDriver: UIViewController {
  private weak var host: UIViewController?
  private weak var coveredPicker: UIColorPickerViewController?
  private var cover: UIViewController?
  private var closingControls = false
  private var dismissingCoveredStack = false
  private let status = UILabel()
  private let onClose: () -> Void

  init(host: UIViewController, onClose: @escaping () -> Void) {
    self.host = host
    self.onClose = onClose
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    status.text = "Native lifecycle controls ready"
    status.font = .systemFont(ofSize: 11)
    status.textAlignment = .center
    let actions = UIStackView(arrangedSubviews: [
      button("Cover palette", action: #selector(coverPalette)),
      button("Return to palette", action: #selector(returnToPalette)),
      button("Dismiss palette", action: #selector(dismissPalette)),
    ])
    actions.axis = .horizontal
    actions.distribution = .fillEqually
    actions.spacing = 4
    let close = button("×", action: #selector(closeControls))
    close.accessibilityLabel = "Close lifecycle controls"
    let row = UIStackView(arrangedSubviews: [actions, close])
    row.axis = .horizontal
    let toolbar = UIStackView(arrangedSubviews: [row, status])
    toolbar.axis = .vertical
    toolbar.spacing = 4
    toolbar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toolbar)
    NSLayoutConstraint.activate([
      toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
      toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
      // Keep the system palette's top close button and its swatch grid exposed.
      toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
      row.heightAnchor.constraint(equalToConstant: 44),
      close.widthAnchor.constraint(equalToConstant: 44),
    ])
  }

  @objc private func closeControls() {
    guard !closingControls else { return }
    closingControls = true
    view.isUserInteractionEnabled = false
    guard let cover else {
      coveredPicker = nil
      onClose()
      return
    }
    // The driver owns only this cover. Dismiss it before removing the toolbar,
    // leaving the application's palette and its delegate alive underneath.
    cover.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      self.cover = nil
      self.coveredPicker = nil
      self.onClose()
    }
  }

  private func button(_ title: String, action: Selector) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 12)
    button.addTarget(self, action: action, for: .touchUpInside)
    return button
  }

  private func activePicker() -> UIColorPickerViewController? {
    var visited = Set<ObjectIdentifier>()
    func find(_ controller: UIViewController) -> UIColorPickerViewController? {
      guard visited.insert(ObjectIdentifier(controller)).inserted else { return nil }
      if let picker = controller as? UIColorPickerViewController { return picker }
      if let presented = controller.presentedViewController, let picker = find(presented) { return picker }
      for child in controller.children {
        if let picker = find(child) { return picker }
      }
      return nil
    }
    return host.flatMap(find)
  }

  @objc private func coverPalette() {
    guard cover == nil, let picker = activePicker() else {
      status.text = "Cover failed: palette unavailable"
      return
    }
    let controller = UIViewController()
    controller.modalPresentationStyle = .fullScreen
    controller.view.backgroundColor = .systemIndigo
    let label = UILabel()
    label.text = "Nested native cover"
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(label)
    let dismissStack = button("Dismiss covered stack", action: #selector(dismissCoveredStack))
    dismissStack.setTitleColor(.white, for: .normal)
    dismissStack.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(dismissStack)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
      dismissStack.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      dismissStack.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
      dismissStack.heightAnchor.constraint(equalToConstant: 44),
    ])
    coveredPicker = picker
    cover = controller
    picker.present(controller, animated: true) { [weak self] in
      self?.status.text = "Native palette covered"
    }
  }

  @objc private func returnToPalette() {
    guard let cover else { status.text = "Return failed: cover unavailable"; return }
    cover.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      self.cover = nil
      self.status.text = self.coveredPicker != nil && self.coveredPicker === self.activePicker()
        ? "Original native palette restored" : "Return failed: palette changed"
      self.coveredPicker = nil
    }
  }

  @objc private func dismissPalette() {
    guard cover == nil, let picker = activePicker() else {
      status.text = "Dismiss failed: palette unavailable"
      return
    }
    picker.dismiss(animated: true) { [weak self] in
      self?.status.text = "Native palette programmatically dismissed"
    }
  }

  @objc private func dismissCoveredStack() {
    guard !dismissingCoveredStack, let cover, let picker = coveredPicker,
          picker === activePicker(), picker.presentedViewController === cover,
          let presenter = picker.presentingViewController,
          presenter.presentedViewController === picker else {
      status.text = "Covered stack dismissal failed: ownership changed"
      return
    }
    dismissingCoveredStack = true
    // Exercise an external UIKit caller. No package session or lifecycle API
    // participates, and the completion must not keep the palette alive itself.
    presenter.dismiss(animated: true) { [weak self, weak picker, weak cover] in
      guard let self else { return }
      self.dismissingCoveredStack = false
      let paletteDeparted = picker == nil ||
        (picker?.presentingViewController == nil && picker?.viewIfLoaded?.window == nil)
      let coverDeparted = cover == nil ||
        (cover?.presentingViewController == nil && cover?.viewIfLoaded?.window == nil)
      guard paletteDeparted && coverDeparted else {
        self.status.text = "Covered stack dismissal failed: controller remains"
        return
      }
      self.cover = nil
      self.coveredPicker = nil
      self.status.text = "Covered native stack externally dismissed"
    }
  }
}

import UIKit

/// A standalone test host: no Flutter engine, package plugin, or color-well
/// trigger participates in the first system color-picker presentation.
@main
final class BaselineAppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    baselineTrace("application didFinishLaunching")
    return true
  }

  func application(_ application: UIApplication,
                   configurationForConnecting connectingSceneSession: UISceneSession,
                   options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(name: "Baseline", sessionRole: connectingSceneSession.role)
    configuration.delegateClass = BaselineSceneDelegate.self
    return configuration
  }
}

final class BaselineSceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = BaselineViewController()
    self.window = window
    window.makeKeyAndVisible()
    baselineTrace("scene connected")
  }

  func sceneDidBecomeActive(_ scene: UIScene) { baselineTrace("scene active") }
  func sceneWillResignActive(_ scene: UIScene) { baselineTrace("scene inactive") }
  func sceneDidDisconnect(_ scene: UIScene) { baselineTrace("scene disconnected") }
}

private func baselineTrace(_ event: String) {
  NSLog("[GlassUIKitBaseline] uptime=%.6f %@", ProcessInfo.processInfo.systemUptime, event)
}

private final class BaselineColorPicker: UIColorPickerViewController {
  var onLifecycle: ((String) -> Void)?
  var onDisappeared: ((BaselineColorPicker) -> Void)?
  private func record(_ event: String) {
    if let onLifecycle { onLifecycle(event) } else { baselineTrace(event) }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    record("picker viewDidLoad")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    record("picker viewWillAppear")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    record("picker viewDidAppear")
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    record("picker viewWillDisappear dismissing=\(isBeingDismissed)")
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    record("picker viewDidDisappear dismissing=\(isBeingDismissed)")
    onDisappeared?(self)
  }

  deinit { baselineTrace("picker deinit") }
}

/// Isolate subclass identity from all lifecycle overrides and instrumentation.
private final class BareBaselineColorPicker: UIColorPickerViewController {}

private final class BaselineViewController: UIViewController,
  UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private let openButton = UIButton(type: .system)
  private let countLabel = UILabel()
  private let valueLabel = UILabel()
  private let presentationsLabel = UILabel()
  private let lifecycleLabel = UILabel()
  private var picker: UIColorPickerViewController?
  // The independent plain-UIKit CI arm changes only this fixture flag in its
  // built app. The original arm keeps its instrumented controller subclass.
  private var usesPlainPicker: Bool {
    Bundle.main.object(forInfoDictionaryKey: "GlassUsePlainColorPicker") as? Bool ?? false
  }
  private var usesBareSubclass: Bool {
    Bundle.main.object(forInfoDictionaryKey: "GlassUseBareColorPickerSubclass") as? Bool ?? false
  }
  private var closing = false
  private var colorCalls = 0
  private var lastContinuously: Bool?
  private var firstTerminalCount: Int?
  private var terminalCalls = 0
  private var presentationCalls = 0
  private var color = UIColor(red: 0x24 / 255.0, green: 0x63 / 255.0, blue: 0xb8 / 255.0, alpha: 1)
  private var lifecycle: [String] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let heading = UILabel()
    heading.text = "UIKit color baseline"
    heading.font = .preferredFont(forTextStyle: .title2)
    openButton.configuration = .filled()
    openButton.setTitle("Open color palette", for: .normal)
    openButton.accessibilityIdentifier = "baseline-open-color"
    openButton.addTarget(self, action: #selector(openColorPicker), for: .touchUpInside)
    lifecycleLabel.accessibilityIdentifier = "baseline-lifecycle"
    countLabel.accessibilityIdentifier = "baseline-host-selection-state"
    countLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    countLabel.numberOfLines = 0
    lifecycleLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    lifecycleLabel.numberOfLines = 0
    lifecycleLabel.lineBreakMode = .byTruncatingHead
    let stack = UIStackView(arrangedSubviews: [
      heading, openButton, presentationsLabel, countLabel, valueLabel, lifecycleLabel,
    ])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
      openButton.heightAnchor.constraint(equalToConstant: 48),
      lifecycleLabel.heightAnchor.constraint(equalToConstant: 180),
    ])
    updateLabels()
    record("host viewDidLoad")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    record("host viewDidAppear")
  }

  @objc private func openColorPicker() {
    record("button touchUpInside")
    guard picker == nil, presentedViewController == nil else {
      record("presentation rejected: existing controller")
      return
    }
    record("picker init begin")
    let controller: UIColorPickerViewController
    if usesPlainPicker {
      record("controller class plain UIColorPickerViewController")
      controller = UIColorPickerViewController()
    } else if usesBareSubclass {
      record("controller class bare UIColorPickerViewController subclass")
      controller = BareBaselineColorPicker()
    } else {
      controller = BaselineColorPicker()
    }
    record("picker init end isViewLoaded=\(controller.isViewLoaded)")
    picker = controller
    closing = false
    openButton.isEnabled = false
    if let instrumented = controller as? BaselineColorPicker {
      instrumented.onLifecycle = { [weak self] event in self?.record(event) }
      instrumented.onDisappeared = { [weak self] controller in
        guard let self, self.closing || controller.isBeingDismissed
          || controller.presentingViewController == nil else { return }
        self.releasePicker(controller)
      }
    }
    controller.delegate = self
    controller.modalPresentationStyle = .pageSheet
    controller.presentationController?.delegate = self
    controller.supportsAlpha = true
    controller.title = "Preview color"
    controller.selectedColor = color
    controller.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
    // Do not access controller.view or loadViewIfNeeded(): UIKit decides when
    // to load its view. This arm performs no explicit service initialization.
    record("picker configured isViewLoaded=\(controller.isViewLoaded) explicitViewAccess=false")
    presentationCalls += 1
    updateLabels()
    record("present invoked")
    present(controller, animated: true) { [weak self] in
      self?.record("present completion")
    }
  }

  func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                 didSelect color: UIColor, continuously: Bool) {
    // Count every real delegate callback, including same-value notifications.
    // No deduplication may hide a UIKit callback difference in this control arm.
    colorCalls += 1
    lastContinuously = continuously
    if !continuously {
      terminalCalls += 1
      // Capture once, before closing can cause any additional callbacks.
      if firstTerminalCount == nil { firstTerminalCount = colorCalls }
    }
    self.color = color
    updateLabels()
    record("delegate didSelect continuously=\(continuously) argb=\(argb(color)) calls=\(colorCalls)")
  }

  func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
    guard viewController === picker else { return }
    closing = true
    record("delegate didFinish")
    if usesPlainPicker || usesBareSubclass {
      // These arms have no viewDidDisappear override. Release the same owned
      // controller after dismissal rather than retaining it past the close.
      viewController.dismiss(animated: true) { [weak self, weak viewController] in
        guard let viewController else { return }
        self?.releasePicker(viewController)
      }
    }
  }

  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    guard presentationController.presentedViewController === picker else { return }
    closing = true
    record("presentation willDismiss")
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let controller = presentationController.presentedViewController as? UIColorPickerViewController else { return }
    record("presentation didDismiss")
    releasePicker(controller)
  }

  private func releasePicker(_ controller: UIColorPickerViewController) {
    guard picker === controller else { return }
    picker = nil
    closing = false
    openButton.isEnabled = true
    record("host released picker")
  }

  private func updateLabels() {
    presentationsLabel.text = "Presentation calls: \(presentationCalls)"
    countLabel.text = selectionState
    valueLabel.text = "Color value: \(argb(color))"
  }

  private var selectionState: String {
    let continuous = lastContinuously.map { String($0) } ?? "none"
    return "callbacks=\(colorCalls) firstTerminal=\(firstTerminalCount ?? 0) terminals=\(terminalCalls) continuous=\(continuous) argb=\(argb(color))"
  }

  private func record(_ event: String) {
    let entry = String(format: "%.6f %@", ProcessInfo.processInfo.systemUptime, event)
    lifecycle.append(entry)
    if lifecycle.count > 32 { lifecycle.removeFirst(lifecycle.count - 32) }
    lifecycleLabel.text = lifecycle.joined(separator: "\n")
    baselineTrace(event)
  }

  private func argb(_ color: UIColor) -> String {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "unresolved" }
    func byte(_ component: CGFloat) -> Int { Int((max(0, min(1, component)) * 255).rounded()) }
    return String(format: "%02x%02x%02x%02x", byte(alpha), byte(red), byte(green), byte(blue))
  }
}

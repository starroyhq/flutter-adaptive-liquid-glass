import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
#if DEBUG
  private var colorWellDiagnostics: ColorWellDiagnostics?
#endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
#if DEBUG
    colorWellDiagnostics = ColorWellDiagnostics.startIfRequested()
#endif
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Example-only driver: exercise the public AX activation entry point.
    // This does not synthesize touch events or invoke the color-change callback.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GlassExampleAccessibility") else { return }
    let channel = FlutterMethodChannel(name: "glass_example/accessibility", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "activateColor", let label = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
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
      result(well.accessibilityActivate())
    }
  }
}

#if DEBUG
/// Opt-in example diagnostics. Reads public UIKit state and passively records
/// control events, without recognizing gestures or invoking control actions.
private final class ColorWellDiagnostics {
  private let file: FileHandle
  private let startedAt = ProcessInfo.processInfo.systemUptime
  private var timer: Timer?
  private var identities: [ObjectIdentifier: Int] = [:]
  private var nextIdentity = 1
  private var eventTargets: [ObjectIdentifier: ColorWellEventTarget] = [:]
  private var nextControlIdentity = 1
  private var previousSnapshot: String?
  private var lines = 0
  private var bytes = 0
  private var stopped = false

  static func startIfRequested() -> ColorWellDiagnostics? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "--glass-color-well-trace"),
          arguments.indices.contains(index + 1),
          FileManager.default.fileExists(atPath: arguments[index + 1]) else { return nil }
    do {
      // XCTest owns this pre-created trace file and collects it as an attachment.
      let file = try FileHandle(forWritingTo: URL(fileURLWithPath: arguments[index + 1]))
      try file.seekToEnd()
      let diagnostics = ColorWellDiagnostics(file: file)
      diagnostics.start()
      return diagnostics
    } catch {
      NSLog("Color well diagnostics unavailable")
      return nil
    }
  }

  private init(file: FileHandle) {
    self.file = file
  }

  private func start() {
    record("version=2 interval=0.25 maxSeconds=180 maxLines=512 maxBytes=262144 passiveControlEvents=true")
    sample()
    guard !stopped else { return }
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
      self?.sample()
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func sample() {
    guard !stopped else { return }
    guard ProcessInfo.processInfo.systemUptime - startedAt < 180 else {
      record("stopped=duration-limit")
      stop()
      return
    }
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var remainingViews = 10000
    var wells: [UIColorWell] = []
    func collect(_ view: UIView) {
      guard remainingViews > 0, wells.count < 16 else { return }
      remainingViews -= 1
      if let well = view as? UIColorWell { wells.append(well) }
      for child in view.subviews { collect(child) }
    }
    for window in windows { collect(window) }
    var currentControls: Set<ObjectIdentifier> = []
    let summaries: [(Int, String)] = wells.map { well in
      let identity = ObjectIdentifier(well)
      let number: Int
      if let existing = identities[identity] {
        number = existing
      } else {
        number = nextIdentity
        nextIdentity += 1
        identities[identity] = number
      }
      observeControls(in: well, wellNumber: number, currentControls: &currentControls)
      return (number, describe(well, number: number))
    }
    eventTargets = eventTargets.filter { identity, target in
      guard currentControls.contains(identity) else {
        target.detach()
        return false
      }
      return true
    }
    let currentIdentities = Set(wells.map { ObjectIdentifier($0) })
    identities = identities.filter { currentIdentities.contains($0.key) }
    let snapshot = "app=\(UIApplication.shared.applicationState.rawValue) windows=\(windows.count) "
      + "scanLimited=\(remainingViews == 0 || wells.count == 16) "
      + summaries.sorted { $0.0 < $1.0 }.map { $0.1 }.joined(separator: " | ")
    guard snapshot != previousSnapshot else { return }
    previousSnapshot = snapshot
    record(snapshot)
  }

  private func observeControls(
    in well: UIColorWell,
    wellNumber: Int,
    currentControls: inout Set<ObjectIdentifier>
  ) {
    var remainingViews = 256
    func visit(_ view: UIView) {
      guard !stopped, remainingViews > 0 else { return }
      remainingViews -= 1
      // Any nested well is discovered separately by the window scan.
      if view !== well, view is UIColorWell { return }
      if let control = view as? UIControl {
        let identity = ObjectIdentifier(control)
        currentControls.insert(identity)
        if let existing = eventTargets[identity], existing.control === control,
           existing.wellNumber == wellNumber {
          // Keep a single passive target per mounted control.
        } else {
          eventTargets.removeValue(forKey: identity)?.detach()
          let number = nextControlIdentity
          nextControlIdentity += 1
          let source = control === well ? "well" : "descendant"
          let target = ColorWellEventTarget(control: control, wellNumber: wellNumber) {
            [weak self] event, sender in
            self?.record("event=\(event) well=\(wellNumber) control=\(number) source=\(source) "
              + "enabled=\(sender.isEnabled) attached=\(sender.window != nil) "
              + "highlighted=\(sender.isHighlighted) tracking=\(sender.isTracking) "
              + "touchInside=\(sender.isTouchInside)")
          }
          eventTargets[identity] = target
          record("observe well=\(wellNumber) control=\(number) source=\(source)")
        }
      }
      for child in view.subviews { visit(child) }
    }
    visit(well)
  }

  private func describe(_ well: UIColorWell, number: Int) -> String {
    // Labels only identify our fixed synthetic fixtures. Arbitrary AX text,
    // private UIKit class names, and filesystem paths are never recorded.
    let role: String
    switch well.accessibilityLabel {
    case "Preview color": role = "catalog"
    case "Sample color": role = "probe"
    case "Accent color": role = "probe-renamed"
    default: role = "other"
    }
    var hiddenAncestor = false
    var blockedAncestor = false
    var hiddenAccessibilityAncestor = false
    var effectiveAlpha: CGFloat = 1
    var ancestor: UIView? = well
    while let view = ancestor {
      hiddenAncestor = hiddenAncestor || view.isHidden
      blockedAncestor = blockedAncestor || !view.isUserInteractionEnabled
      hiddenAccessibilityAncestor = hiddenAccessibilityAncestor || view.accessibilityElementsHidden
      effectiveAlpha *= view.alpha
      ancestor = view.superview
    }
    var frame = "none"
    var centerHit = "no-window"
    var onScreen = false
    if let window = well.window {
      let rect = well.convert(well.bounds, to: window)
      frame = String(format: "%.1f,%.1f,%.1f,%.1f", rect.minX, rect.minY, rect.width, rect.height)
      onScreen = rect.intersects(window.bounds)
      let hit = window.hitTest(CGPoint(x: rect.midX, y: rect.midY), with: nil)
      if hit === well {
        centerHit = "self"
      } else if let hit {
        centerHit = hit.isDescendant(of: well) ? "descendant" : "other"
      } else {
        centerHit = "nil"
      }
    }
    var responder: UIResponder? = well.next
    var controller: UIViewController?
    while let current = responder {
      if let candidate = current as? UIViewController {
        controller = candidate
        break
      }
      responder = current.next
    }
    let presentation: String
    if let controller {
      let presented = controller.presentedViewController
      presentation = "hostAttached=\(controller.viewIfLoaded?.window != nil) "
        + "hostPresenting=\(controller.presentingViewController != nil) "
        + "hostBeingPresented=\(controller.isBeingPresented) hostDismissing=\(controller.isBeingDismissed) "
        + "presented=\(presented != nil) presentedColorPicker=\(presented is UIColorPickerViewController) "
        + "presentedDismissing=\(presented?.isBeingDismissed ?? false)"
    } else {
      presentation = "host=none"
    }
    return "well=\(number) role=\(role) enabled=\(well.isEnabled) interactive=\(well.isUserInteractionEnabled) "
      + "highlighted=\(well.isHighlighted) tracking=\(well.isTracking) touchInside=\(well.isTouchInside) "
      + "tintAdjustment=\(well.tintAdjustmentMode.rawValue) attached=\(well.window != nil) "
      + "hidden=\(hiddenAncestor) blocked=\(blockedAncestor) axHidden=\(hiddenAccessibilityAncestor) "
      + "alpha=\(String(format: "%.3f", effectiveAlpha)) frame=\(frame) onScreen=\(onScreen) "
      + "centerHit=\(centerHit) \(presentation)"
  }

  private func record(_ message: String) {
    guard !stopped else { return }
    let data = Data("\(ProcessInfo.processInfo.systemUptime) \(message)\n".utf8)
    guard lines < 512, bytes + data.count <= 262144 else {
      stop()
      return
    }
    do {
      try file.write(contentsOf: data)
      lines += 1
      bytes += data.count
    } catch {
      stop()
    }
  }

  private func stop() {
    guard !stopped else { return }
    stopped = true
    timer?.invalidate()
    timer = nil
    for target in eventTargets.values { target.detach() }
    eventTargets.removeAll()
    try? file.close()
  }

  deinit {
    timer?.invalidate()
    for target in eventTargets.values { target.detach() }
    try? file.close()
  }
}

/// UIControl does not retain its targets. The diagnostic owns these adapters;
/// each adapter only weakly references the observed control and diagnostic.
private final class ColorWellEventTarget: NSObject {
  weak var control: UIControl?
  let wellNumber: Int
  private let record: (String, UIControl) -> Void

  init(control: UIControl, wellNumber: Int, record: @escaping (String, UIControl) -> Void) {
    self.control = control
    self.wellNumber = wellNumber
    self.record = record
    super.init()
    control.addTarget(self, action: #selector(touchDown(_:)), for: .touchDown)
    control.addTarget(self, action: #selector(touchUpInside(_:)), for: .touchUpInside)
    control.addTarget(self, action: #selector(touchUpOutside(_:)), for: .touchUpOutside)
    control.addTarget(self, action: #selector(touchCancel(_:)), for: .touchCancel)
    control.addTarget(self, action: #selector(primaryAction(_:)), for: .primaryActionTriggered)
    control.addTarget(self, action: #selector(menuAction(_:)), for: .menuActionTriggered)
  }

  func detach() {
    // Remove only this adapter's passive targets, leaving system actions alone.
    control?.removeTarget(self, action: nil, for: .allEvents)
    control = nil
  }

  @objc private func touchDown(_ sender: UIControl) { record("touchDown", sender) }
  @objc private func touchUpInside(_ sender: UIControl) { record("touchUpInside", sender) }
  @objc private func touchUpOutside(_ sender: UIControl) { record("touchUpOutside", sender) }
  @objc private func touchCancel(_ sender: UIControl) { record("touchCancel", sender) }
  @objc private func primaryAction(_ sender: UIControl) { record("primaryActionTriggered", sender) }
  @objc private func menuAction(_ sender: UIControl) { record("menuActionTriggered", sender) }

  deinit { detach() }
}
#endif

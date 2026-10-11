import Flutter
import UIKit

private enum AdaptiveColorDiagnostics {
  static var enabled: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("-glass-color-lifecycle-diagnostics")
    #else
    false
    #endif
  }
  static func record(_ event: @autoclosure () -> String) {
    guard enabled else { return }
    NSLog("[GlassColorLifecycle] %@", event())
  }
}

#if DEBUG
/// Opt-in observation of the existing touch path, without another recognizer or
/// target. Store bounded structural data and write logs outside touch delivery.
private final class AdaptiveColorTouchDiagnostics {
  struct Configuration {
    let revision: Int
    let custom: Bool
    let controlEnabled: Bool
    let controlInteractionEnabled: Bool
    let containerEnabled: Bool
    let tapEnabled: Bool
    let tapState: Int?
    let attached: Bool
    let hidden: Bool
    let configuring: Bool
  }
  private struct Event {
    let time: TimeInterval
    let phase: String
    let sequence: Int?
    let state: Int?
    let point: CGPoint?
    let eventType: Int?
    let touchPhase: Int?
    let hitType: String?
    let hitID: ObjectIdentifier?
    let configuration: Configuration?
  }
  var configuration: (() -> Configuration?)?
  var touchInProgress = false
  private let viewID: Int64
  private var ring = [Event?](repeating: nil, count: 128)
  private var nextEvent = 0
  private var nextDumpEvent = 0
  private var dumpScheduled = false

  init(viewID: Int64) { self.viewID = viewID }

  func append(_ phase: String, sequence: Int? = nil, state: UIGestureRecognizer.State? = nil,
              point: CGPoint? = nil, event: UIEvent? = nil, touch: UITouch? = nil,
              hit: UIView? = nil) {
    ring[nextEvent % ring.count] = Event(
      time: ProcessInfo.processInfo.systemUptime, phase: phase, sequence: sequence,
      state: state?.rawValue, point: point, eventType: event?.type.rawValue,
      touchPhase: touch?.phase.rawValue, hitType: hit.map { String(reflecting: type(of: $0)) },
      hitID: hit.map(ObjectIdentifier.init), configuration: configuration?())
    nextEvent += 1
  }

  func scheduleDump() {
    guard !dumpScheduled else { return }
    dumpScheduled = true
    // Retain only the bounded buffer. Its configuration closure is weak and no
    // record retains the view, recognizer, event, touch or platform component.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
      dumpScheduled = false
      // A hit-test fallback timer must not log in the middle of a touch which
      // subsequently reached us. Its end/cancellation/reset schedules the dump.
      guard !touchInProgress else { return }
      let first = max(nextDumpEvent, nextEvent - ring.count)
      guard first < nextEvent else { return }
      NSLog("[GlassColorTouch] view=%lld events=%d..<%d skipped=%d", viewID, first, nextEvent, first - nextDumpEvent)
      for number in first..<nextEvent {
        guard let event = ring[number % ring.count] else { continue }
        let sequence = event.sequence.map(String.init) ?? "-"
        let state = event.state.map(String.init) ?? "-"
        let point = event.point.map { "\($0.x),\($0.y)" } ?? "-"
        let type = event.eventType.map(String.init) ?? "-"
        let touch = event.touchPhase.map(String.init) ?? "-"
        let hit = event.hitID.map { String(describing: $0) } ?? "nil"
        let c = event.configuration
        let config = c.map {
          "rev=\($0.revision) custom=\($0.custom) control=\($0.controlEnabled) controlInput=\($0.controlInteractionEnabled) container=\($0.containerEnabled) tap=\($0.tapEnabled)/\($0.tapState.map(String.init) ?? "-") window=\($0.attached) hidden=\($0.hidden) configuring=\($0.configuring)"
        } ?? "owner=nil"
        NSLog("[GlassColorTouch] view=%lld #%d t=%.6f %@ seq=%@ state=%@ point=%@ event=%@ touch=%@ hit=%@/%@ %@",
              viewID, number, event.time, event.phase, sequence, state, point, type,
              touch, event.hitType ?? "nil", hit, config)
      }
      nextDumpEvent = nextEvent
    }
  }
}

private final class AdaptiveColorDiagnosticContainer: UIView {
  private let diagnostics: AdaptiveColorTouchDiagnostics
  init(diagnostics: AdaptiveColorTouchDiagnostics) {
    self.diagnostics = diagnostics
    super.init(frame: .zero)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    diagnostics.append("hitTest", point: point, event: event,
                       touch: event?.allTouches?.first, hit: hit)
    // Also flush a hit which never reaches the recognizer. The delayed output
    // cannot forward the touch or alter the original hit-test result.
    diagnostics.scheduleDump()
    return hit
  }
}

private final class AdaptiveColorDiagnosticTap: UITapGestureRecognizer {
  private let diagnostics: AdaptiveColorTouchDiagnostics
  private var sequence = 0
  init(diagnostics: AdaptiveColorTouchDiagnostics, target: Any?, action: Selector?) {
    self.diagnostics = diagnostics
    super.init(target: target, action: action)
  }

  private func record(_ phase: String, touches: Set<UITouch>, event: UIEvent) {
    let touch = touches.first
    diagnostics.append(phase, sequence: sequence, state: state,
                       point: touch.map { $0.location(in: view) }, event: event, touch: touch)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    diagnostics.touchInProgress = true
    sequence += 1
    record("began.before", touches: touches, event: event)
    super.touchesBegan(touches, with: event)
    record("began.after", touches: touches, event: event)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    record("moved.before", touches: touches, event: event)
    super.touchesMoved(touches, with: event)
    record("moved.after", touches: touches, event: event)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    record("ended.before", touches: touches, event: event)
    super.touchesEnded(touches, with: event)
    record("ended.after", touches: touches, event: event)
    diagnostics.touchInProgress = false
    diagnostics.scheduleDump()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    record("cancelled.before", touches: touches, event: event)
    super.touchesCancelled(touches, with: event)
    record("cancelled.after", touches: touches, event: event)
    diagnostics.touchInProgress = false
    diagnostics.scheduleDump()
  }

  override func reset() {
    diagnostics.append("reset.before", sequence: sequence, state: state)
    super.reset()
    diagnostics.append("reset.after", sequence: sequence, state: state)
    diagnostics.touchInProgress = false
    diagnostics.scheduleDump()
  }
}
#endif

enum AdaptiveLiquidGlassPickerKind { case date, color }

/// Cancellation outlives the originating platform view. UIKit can finish an
/// asynchronous presentation after that view and its session have been removed.
private final class AdaptiveManagedColorPicker: UIColorPickerViewController {
  weak var presentationSession: AdaptiveColorPickerPresentation?
  private var presentationCancelled = false

  func cancelPresentation() {
    AdaptiveColorDiagnostics.record("picker cancelPresentation")
    presentationCancelled = true
    dismissCancelledPresentation()
  }

  func presentationCompleted() {
    if presentationCancelled {
      dismissCancelledPresentation()
    } else {
      presentationSession?.presentationCompleted()
    }
  }

  private func dismissCancelledPresentation() {
    guard presentationCancelled, !isBeingDismissed,
          presentingViewController != nil || viewIfLoaded?.window != nil else { return }
    // Only this controller is dismissed. In particular, a late completion must
    // not dismiss a newer controller belonging to the same presenter.
    dismiss(animated: false) { [weak self] in
      self?.presentationSession?.disappearanceCompleted()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    AdaptiveColorDiagnostics.record("picker didLoad id=\(ObjectIdentifier(self))")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    AdaptiveColorDiagnostics.record("picker willAppear id=\(ObjectIdentifier(self))")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    AdaptiveColorDiagnostics.record("picker didAppear")
    presentationCompleted()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    AdaptiveColorDiagnostics.record("picker didDisappear")
    presentationSession?.disappearanceCompleted()
  }

  deinit {
    AdaptiveColorDiagnostics.record("picker deinit")
    presentationSession?.pickerDeinitialized()
  }
}

/// Keep the delegate separate from UIColorWell: UIKit uses the same delegate
/// selectors for the system presentation used by an unlabeled well.
private final class AdaptiveColorPickerPresentation: NSObject,
  UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
  private enum Phase { case presenting, presented, dismissing, finished }
  private weak var owner: AdaptiveAccessibleColorWell?
  // The platform view owns this session; the picker and well point back weakly.
  // Retain the controller throughout UIKit's asynchronous presentation handoff.
  private(set) weak var picker: AdaptiveManagedColorPicker?
  private var retainedPicker: AdaptiveManagedColorPicker?
  private var phase = Phase.presenting
  private(set) var cancelled = false
  private var inactiveObserver: NSObjectProtocol?

  init(owner: AdaptiveAccessibleColorWell, picker: AdaptiveManagedColorPicker) {
    self.owner = owner
    self.picker = picker
    retainedPicker = picker
    super.init()
    AdaptiveColorDiagnostics.record("session init id=\(ObjectIdentifier(self)) owner=\(ObjectIdentifier(owner)) picker=\(ObjectIdentifier(picker))")
    picker.presentationSession = self
    picker.delegate = self
    picker.presentationController?.delegate = self
    inactiveObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in AdaptiveColorDiagnostics.record("willResignActive"); self?.cancel() }
  }

  func present(from presenter: UIViewController) {
    guard phase == .presenting, !cancelled, let picker else { return }
    AdaptiveColorDiagnostics.record("present type=\(type(of: presenter)) viewLoaded=\(picker.isViewLoaded) source=\(owner?.canPresentPicker == true)")
    presenter.present(picker, animated: true) { [weak picker] in
      picker?.presentationCompleted()
    }
    if AdaptiveColorDiagnostics.enabled {
      for delay in [1.0, 5.0, 15.0] {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
          guard let self else { AdaptiveColorDiagnostics.record("delayed session gone"); return }
          AdaptiveColorDiagnostics.record("delayed phase=\(self.phase) pickerAlive=\(self.picker != nil) attached=\(self.picker?.viewIfLoaded?.window != nil) presenter=\(self.picker?.presentingViewController != nil) owner=\(self.owner != nil) eligible=\(self.owner?.canPresentPicker == true)")
        }
      }
    }
    // UIKit may forward presentation through an internal host. A synchronous
    // presentedViewController identity check cannot determine whether it worked.
  }

  func presentationCompleted() {
    AdaptiveColorDiagnostics.record("presentationCompleted phase=\(phase) cancelled=\(cancelled)")
    guard phase != .finished else { return }
    if phase == .presenting { phase = .presented }
    if cancelled || owner?.canPresentPicker != true { cancel() }
  }

  func cancel() {
    AdaptiveColorDiagnostics.record("session cancel phase=\(phase) owner=\(owner != nil) eligible=\(owner?.canPresentPicker == true) attached=\(picker?.viewIfLoaded?.window != nil)")
    guard phase != .finished else { return }
    cancelled = true
    guard let picker else { finish(); return }
    let wasPresenting = phase == .presenting
    phase = .dismissing
    picker.cancelPresentation()
    if wasPresenting {
      // Release our strong ownership without reopening the well. If UIKit never
      // took ownership, deinit completes cancellation; otherwise the weak picker
      // remains observable until its late presentation has actually dismissed.
      retainedPicker = nil
    }
  }

  func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                 didSelect color: UIColor, continuously: Bool) {
    let acceptsSelection = phase == .presented
      || (phase == .presenting && viewController.viewIfLoaded?.window != nil)
    guard viewController === picker, acceptsSelection, !cancelled,
          !viewController.isBeingDismissed else { return }
    owner?.colorPickerDidSelect(self, color: color)
  }

  func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
    guard viewController === picker, phase != .finished else { return }
    // This callback starts dismissal; it is not its completion. Keep ownership
    // until viewDidDisappear/transition completion so a second action cannot open
    // another picker over the outgoing one.
    observeDismissal()
  }

  func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
    guard presentationController.presentedViewController === picker else { return }
    observeDismissal()
  }

  private func observeDismissal() {
    phase = .dismissing
    picker?.transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] context in
      guard let self, self.phase != .finished else { return }
      if context.isCancelled {
        self.phase = .presented
        if self.cancelled || self.owner?.canPresentPicker != true { self.cancel() }
      } else {
        self.finish()
      }
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard presentationController.presentedViewController === picker else { return }
    finish()
  }

  func disappearanceCompleted() {
    // A nested system controller can temporarily cover the picker. Only an
    // actual dismissal that we observed may release the originating well.
    if phase == .dismissing { finish() }
  }

  func pickerDeinitialized() {
    // The picker may be released when a cancelled presentation was never adopted
    // by UIKit. Its weak reference is not safe to access during deinitialization.
    finish(detachPicker: false)
  }

  private func finish(detachPicker: Bool = true) {
    AdaptiveColorDiagnostics.record("session finish phase=\(phase) detach=\(detachPicker)")
    guard phase != .finished else { return }
    phase = .finished
    if let inactiveObserver { NotificationCenter.default.removeObserver(inactiveObserver) }
    inactiveObserver = nil
    if detachPicker {
      picker?.delegate = nil
      picker?.presentationController?.delegate = nil
      picker?.presentationSession = nil
    }
    owner?.colorPickerDidDismiss(self)
    owner = nil
    picker = nil
    retainedPicker = nil
  }

  deinit {
    if let inactiveObserver { NotificationCenter.default.removeObserver(inactiveObserver) }
  }
}

/// When the caller supplies a label, expose the public control and present the
/// public UIKit picker for both AX and the container's physical tap. Keep an
/// unlabeled well's system accessibility and physical behavior unchanged.
private final class AdaptiveAccessibleColorWell: UIColorWell {
  private var semanticLabel: String?
  private weak var colorPresentation: AdaptiveColorPickerPresentation?
  var onAccessibilityColorChange: (() -> Void)?
  var retainColorPresentation: ((AdaptiveColorPickerPresentation) -> Bool)?
  var releaseColorPresentation: ((AdaptiveColorPickerPresentation) -> Void)?

  var usesCustomActivation: Bool { semanticLabel != nil }

  override var isAccessibilityElement: Bool {
    get { usesCustomActivation || super.isAccessibilityElement }
    set { super.isAccessibilityElement = newValue }
  }

  override var accessibilityLabel: String? {
    get { semanticLabel ?? super.accessibilityLabel }
    set {
      semanticLabel = newValue
      super.accessibilityLabel = newValue
      // The native well continues drawing its normal enabled/disabled state.
      // Only its internal physical action is disabled in the labeled path;
      // the container provides the single tap recognizer for that path.
      updateActivationMode()
    }
  }

  override var accessibilityValue: String? {
    get {
      guard usesCustomActivation else { return super.accessibilityValue }
      return selectedColor?.accessibilityName ?? super.accessibilityValue
    }
    set { super.accessibilityValue = newValue }
  }

  override var accessibilityTraits: UIAccessibilityTraits {
    get {
      guard usesCustomActivation else { return super.accessibilityTraits }
      var traits = super.accessibilityTraits.union(.button)
      if !isEnabled { traits.insert(.notEnabled) }
      return traits
    }
    set { super.accessibilityTraits = newValue }
  }

  override func accessibilityActivate() -> Bool {
    guard colorPresentation == nil else { return false }
    guard usesCustomActivation else { return super.accessibilityActivate() }
    return presentColorPicker()
  }

  private func updateActivationMode() {
    // Switching back to system defaults must wait for our previous presentation
    // to finish, or UIKit's internal trigger could bypass its cancellation gate.
    let waitingForSystemActivation = !usesCustomActivation && colorPresentation != nil
    isUserInteractionEnabled = !usesCustomActivation && !waitingForSystemActivation
    accessibilityElementsHidden = waitingForSystemActivation
  }

  @discardableResult
  func presentColorPicker() -> Bool {
    AdaptiveColorDiagnostics.record("activate eligible=\(canPresentPicker) existing=\(colorPresentation != nil) alpha=\(supportsAlpha)")
    guard canPresentPicker, colorPresentation == nil else { return false }
    var responder: UIResponder? = next
    while responder != nil && !(responder is UIViewController) {
      responder = responder?.next
    }
    guard let presenter = responder as? UIViewController,
          presenter.viewIfLoaded?.window != nil,
          !presenter.isBeingDismissed,
          presenter.presentedViewController == nil else { return false }

    let picker = AdaptiveManagedColorPicker()
    picker.modalPresentationStyle = traitCollection.userInterfaceIdiom == .pad
      ? .popover : .pageSheet
    if let popover = picker.popoverPresentationController {
      popover.sourceView = self
      popover.sourceRect = bounds
    }
    let presentation = AdaptiveColorPickerPresentation(owner: self, picker: picker)
    // A popover may retain its source view after Flutter disposed the platform
    // view. Only its still-live platform owner may accept a new presentation.
    guard retainColorPresentation?(presentation) == true else {
      presentation.cancel()
      return false
    }
    colorPresentation = presentation
    synchronizeAccessibilityPicker()
    presentation.present(from: presenter)
    return true
  }

  var canPresentPicker: Bool {
    guard usesCustomActivation, isEnabled, window != nil,
          !isHidden, !accessibilityElementsHidden,
          UIApplication.shared.applicationState == .active else {
      return false
    }
    // The well itself is deliberately render-only. Its ancestors must still
    // accept input; route suppression, detach and background remain barriers.
    var opacity = alpha
    guard opacity > 0.01 else { return false }
    var ancestor = superview
    while let view = ancestor {
      opacity *= view.alpha
      guard !view.isHidden, view.isUserInteractionEnabled,
            !view.accessibilityElementsHidden, opacity > 0.01 else {
        return false
      }
      ancestor = view.superview
    }
    return true
  }

  func synchronizeAccessibilityPicker() {
    guard let presentation = colorPresentation else { return }
    guard canPresentPicker else { presentation.cancel(); return }
    guard !presentation.cancelled, let picker = presentation.picker else { return }
    picker.supportsAlpha = supportsAlpha
    picker.title = title
    let color = selectedColor ?? .clear
    let value = supportsAlpha ? color : color.withAlphaComponent(1)
    if picker.selectedColor != value { picker.selectedColor = value }
    picker.overrideUserInterfaceStyle = traitCollection.userInterfaceStyle
    AdaptiveColorDiagnostics.record("configure before view access loaded=\(picker.isViewLoaded)")
    picker.view.tintColor = tintColor
    picker.view.semanticContentAttribute = semanticContentAttribute
    AdaptiveColorDiagnostics.record("configure after view access loaded=\(picker.isViewLoaded)")
  }

  func cancelAccessibilityPresentation() { colorPresentation?.cancel() }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { AdaptiveColorDiagnostics.record("well detached"); cancelAccessibilityPresentation() }
  }

  func colorPickerDidSelect(_ presentation: AdaptiveColorPickerPresentation, color: UIColor) {
    guard presentation === colorPresentation, canPresentPicker, !presentation.cancelled else { return }
    let value = supportsAlpha ? color : color.withAlphaComponent(1)
    guard selectedColor != value else { return }
    selectedColor = value
    // Only a real UIKit selection enters the controlled-value bridge.
    onAccessibilityColorChange?()
  }

  func colorPickerDidDismiss(_ presentation: AdaptiveColorPickerPresentation) {
    if presentation === colorPresentation {
      colorPresentation = nil
      updateActivationMode()
      releaseColorPresentation?(presentation)
    }
  }

  deinit { AdaptiveColorDiagnostics.record("well deinit"); colorPresentation?.cancel() }
}

final class AdaptiveLiquidGlassPickerFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let kind: AdaptiveLiquidGlassPickerKind
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger, kind: AdaptiveLiquidGlassPickerKind) {
    self.messenger = messenger
    self.kind = kind
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassPicker(
      frame: frame, identifier: viewId, kind: kind,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger, suppression: suppression
    )
  }
}

/// UIKit controls are retained through all configuration changes. A complete
/// configuration replaces the old state, including nullable colors and bounds.
private final class AdaptiveLiquidGlassPicker: NSObject, FlutterPlatformView {
  private let container: UIView
  #if DEBUG
  private let touchDiagnostics: AdaptiveColorTouchDiagnostics?
  #endif
  private let control: UIControl
  private let kind: AdaptiveLiquidGlassPickerKind
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var observer: UUID?
  private var popupOwner = false
  private var routeSuppressed = false
  private var configuring = false
  private var revision = 0
  private var colorTap: UITapGestureRecognizer?
  private var colorPresentation: AdaptiveColorPickerPresentation?

  init(frame: CGRect, identifier: Int64, kind: AdaptiveLiquidGlassPickerKind,
       arguments: [String: Any], messenger: FlutterBinaryMessenger,
       suppression: AdaptiveLiquidGlassSuppression) {
    self.kind = kind
    self.suppression = suppression
    #if DEBUG
    let diagnostics = kind == .color && AdaptiveColorDiagnostics.enabled
      ? AdaptiveColorTouchDiagnostics(viewID: identifier) : nil
    touchDiagnostics = diagnostics
    container = diagnostics.map { AdaptiveColorDiagnosticContainer(diagnostics: $0) } ?? UIView()
    #else
    container = UIView()
    #endif
    control = kind == .date ? UIDatePicker() : AdaptiveAccessibleColorWell()
    let name = kind == .date ? "date" : "color"
    channel = FlutterMethodChannel(
      name: "flutter_adaptive_liquid_glass/\(name)_picker/\(identifier)",
      binaryMessenger: messenger
    )
    super.init()
    #if DEBUG
    touchDiagnostics?.configuration = { [weak self] in
      guard let self else { return nil }
      return AdaptiveColorTouchDiagnostics.Configuration(
        revision: self.revision,
        custom: (self.control as? AdaptiveAccessibleColorWell)?.usesCustomActivation == true,
        controlEnabled: self.control.isEnabled,
        controlInteractionEnabled: self.control.isUserInteractionEnabled,
        containerEnabled: self.container.isUserInteractionEnabled,
        tapEnabled: self.colorTap?.isEnabled == true,
        tapState: self.colorTap?.state.rawValue,
        attached: self.container.window != nil,
        hidden: self.container.isHidden,
        configuring: self.configuring)
    }
    #endif
    container.frame = frame
    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      control.topAnchor.constraint(equalTo: container.topAnchor),
      control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    if control is AdaptiveAccessibleColorWell {
      let tap: UITapGestureRecognizer
      #if DEBUG
      if let touchDiagnostics {
        tap = AdaptiveColorDiagnosticTap(diagnostics: touchDiagnostics,
                                        target: self, action: #selector(activateColorPicker))
      } else {
        tap = UITapGestureRecognizer(target: self, action: #selector(activateColorPicker))
      }
      #else
      tap = UITapGestureRecognizer(target: self, action: #selector(activateColorPicker))
      #endif
      tap.isEnabled = false
      container.addGestureRecognizer(tap)
      colorTap = tap
    }
    (control as? AdaptiveAccessibleColorWell)?.onAccessibilityColorChange = { [weak self] in
      self?.changed()
    }
    (control as? AdaptiveAccessibleColorWell)?.retainColorPresentation = { [weak self] presentation in
      guard let self, self.colorPresentation == nil else { return false }
      self.colorPresentation = presentation
      return true
    }
    (control as? AdaptiveAccessibleColorWell)?.releaseColorPresentation = { [weak self] presentation in
      guard let self, self.colorPresentation === presentation else { return }
      self.colorPresentation = nil
    }
    observer = suppression.observe { [weak self] in self?.updateVisibility() }
    if let error = configure(arguments) {
      // Invalid initial parameters cannot accidentally expose an enabled picker
      // containing an unrelated default value.
      control.isEnabled = false
      assertionFailure(error.message ?? "Invalid picker configuration")
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "setConfiguration":
        guard let config = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_configuration", message: "Expected a picker configuration.", details: nil))
          return
        }
        result(self.configure(config))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  /// All fallible decoding happens before UIKit mutation. Nulls are assigned
  /// explicitly so clearing a bound/tint/locale works as well as setting it.
  private func configure(_ config: [String: Any]) -> FlutterError? {
    guard let number = config["value"] as? NSNumber,
          number.doubleValue.isFinite else {
      return invalid("A finite value is required.")
    }
    var dateMode: UIDatePicker.Mode = .dateAndTime
    var dateStyle: UIDatePickerStyle = .compact
    var minimum: Date?
    var maximum: Date?
    var interval = 1
    if kind == .date {
      switch config["mode"] as? String {
      case "date": dateMode = .date
      case "time": dateMode = .time
      case "dateAndTime": dateMode = .dateAndTime
      default: return invalid("Invalid date mode.")
      }
      switch config["style"] as? String {
      case "compact": dateStyle = .compact
      case "inline": dateStyle = .inline
      case "wheels": dateStyle = .wheels
      default: return invalid("Invalid date style.")
      }
      interval = (config["minuteInterval"] as? NSNumber)?.intValue ?? 1
      guard [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30].contains(interval) else {
        return invalid("Invalid minute interval.")
      }
      for key in ["minimumDate", "maximumDate"] {
        if let bound = config[key], !(bound is NSNull) {
          guard let value = bound as? NSNumber, value.doubleValue.isFinite else {
            return invalid("Invalid date bound.")
          }
        }
      }
      minimum = Self.date(config["minimumDate"])
      maximum = Self.date(config["maximumDate"])
      if let minimum, let maximum, minimum > maximum {
        return invalid("Minimum date exceeds maximum date.")
      }
    }

    configuring = true
    #if DEBUG
    touchDiagnostics?.append("configure.begin", state: colorTap?.state)
    #endif
    defer { configuring = false }
    let incomingRevision = (config["revision"] as? NSNumber)?.intValue ?? 0
    let valueIsEcho = config["valueIsEcho"] as? Bool == true && incomingRevision == revision
    revision = incomingRevision
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    container.semanticContentAttribute = config["rtl"] as? Bool == true ? .forceRightToLeft : .forceLeftToRight
    control.semanticContentAttribute = container.semanticContentAttribute
    control.tintColor = Self.color(config["tint"])
    control.accessibilityLabel = config["semanticLabel"] as? String
    control.isEnabled = config["enabled"] as? Bool ?? false
    if let well = control as? AdaptiveAccessibleColorWell {
      colorTap?.isEnabled = well.usesCustomActivation && well.isEnabled
    }
    popupOwner = config["popupOwner"] as? Bool ?? false
    routeSuppressed = config["suppressed"] as? Bool ?? false

    if let date = control as? UIDatePicker {
      let locale = (config["locale"] as? String).map(Locale.init(identifier:))
      // Avoid reassigning native picker properties on every accepted value.
      // Even setting the same selectedColor/date can interrupt a system drag.
      if date.locale != locale { date.locale = locale }
      if date.timeZone != .current { date.timeZone = .current }
      if date.datePickerMode != dateMode { date.datePickerMode = dateMode }
      if date.preferredDatePickerStyle != dateStyle { date.preferredDatePickerStyle = dateStyle }
      if date.minuteInterval != interval { date.minuteInterval = interval }
      if date.minimumDate != minimum || date.maximumDate != maximum {
        date.minimumDate = nil
        date.maximumDate = nil
        date.minimumDate = minimum
        date.maximumDate = maximum
      }
      if !valueIsEcho {
        date.setDate(Date(timeIntervalSince1970: number.doubleValue / 1000), animated: false)
      }
    } else if let well = control as? UIColorWell {
      let supportsAlpha = config["supportsAlpha"] as? Bool ?? true
      if well.supportsAlpha != supportsAlpha { well.supportsAlpha = supportsAlpha }
      let title = config["title"] as? String
      if well.title != title { well.title = title }
      if !valueIsEcho {
        let color = Self.color(number) ?? .clear
        well.selectedColor = supportsAlpha ? color : color.withAlphaComponent(1)
      }
    }
    updateVisibility()
    #if DEBUG
    touchDiagnostics?.append("configure.end", state: colorTap?.state)
    touchDiagnostics?.scheduleDump()
    #endif
    return nil
  }

  @objc private func activateColorPicker(_ recognizer: UITapGestureRecognizer) {
    #if DEBUG
    touchDiagnostics?.append("target.enter", state: recognizer.state)
    defer { touchDiagnostics?.scheduleDump() }
    #endif
    guard recognizer.state == .ended, !configuring else { return }
    #if DEBUG
    touchDiagnostics?.append("target.accepted", state: recognizer.state)
    #endif
    (control as? AdaptiveAccessibleColorWell)?.presentColorPicker()
  }

  @objc private func changed() {
    guard !configuring, control.isEnabled, !container.isHidden else { return }
    let value: Any
    if let date = control as? UIDatePicker {
      value = Int64((date.date.timeIntervalSince1970 * 1000).rounded())
    } else if let well = control as? UIColorWell, let color = well.selectedColor {
      value = Self.argb(well.supportsAlpha ? color : color.withAlphaComponent(1))
    } else { return }
    channel.invokeMethod("changed", arguments: ["value": value, "revision": revision])
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    (control as? AdaptiveAccessibleColorWell)?.synchronizeAccessibilityPicker()
  }

  private func invalid(_ message: String) -> FlutterError {
    FlutterError(code: "invalid_configuration", message: message, details: nil)
  }

  private static func date(_ value: Any?) -> Date? {
    guard let number = value as? NSNumber else { return nil }
    return Date(timeIntervalSince1970: number.doubleValue / 1000)
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                   green: CGFloat((argb >> 8) & 255) / 255,
                   blue: CGFloat(argb & 255) / 255,
                   alpha: CGFloat((argb >> 24) & 255) / 255)
  }

  private static func argb(_ color: UIColor) -> UInt32 {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let converted = color.cgColor.converted(to: space, intent: .defaultIntent, options: nil)
    let color = converted.map(UIColor.init(cgColor:)) ?? color
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    func byte(_ value: CGFloat) -> UInt32 {
      UInt32((max(0, min(1, value)) * 255).rounded())
    }
    return (byte(alpha) << 24) | (byte(red) << 16) | (byte(green) << 8) | byte(blue)
  }

  deinit {
    AdaptiveColorDiagnostics.record("platform deinit kind=\(kind) id=\(ObjectIdentifier(self)) control=\(ObjectIdentifier(control))")
    colorPresentation?.cancel()
    channel.setMethodCallHandler(nil)
    control.removeTarget(self, action: #selector(changed), for: .valueChanged)
    if let observer { suppression.remove(observer) }
  }
}

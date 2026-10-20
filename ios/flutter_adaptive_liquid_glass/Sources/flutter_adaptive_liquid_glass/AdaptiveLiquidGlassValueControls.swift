import Flutter
import UIKit

final class AdaptiveLiquidGlassValueControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let configuration = args as? [String: Any] ?? [:]
    if configuration["kind"] as? String == "slider" {
      return AdaptiveLiquidGlassNativeSlider(frame: frame, id: viewId, arguments: configuration, messenger: messenger, suppression: suppression)
    }
    return AdaptiveLiquidGlassValueControl(frame: frame, id: viewId, arguments: configuration, messenger: messenger, suppression: suppression)
  }
}

private final class AdaptiveLiquidGlassValueControl: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let control: UIControl
  private let channel: FlutterMethodChannel
  private let kind: String
  private let suppression: AdaptiveLiquidGlassSuppression
  private var suppressionObserver: UUID?
  private var routeSuppressed = false
  private var popupOwner = false
  private var enabled = true
  private var revision = 0
  private var minimum = 0.0
  private var maximum = 1.0
  private var divisions: Int?
  private var step = 1.0
  private var wraps = false
  private var value = 0.0
  private var configuring = false

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    kind = arguments["kind"] as? String ?? "slider"
    self.suppression = suppression
    switch kind {
    case "switch": control = AdaptiveGlassSwitch()
    default: control = AdaptiveGlassStepper()
    }
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/value-control/\(id)", binaryMessenger: messenger)
    super.init()
    container.frame = frame
    container.backgroundColor = .clear
    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    if let stepper = control as? AdaptiveGlassStepper {
      stepper.autorepeat = true
      stepper.isContinuous = true
      stepper.onAccessibilityAdjust = { [weak self] direction in self?.accessibilityAdjust(direction) }
    }
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    configure(arguments)
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "configure":
        guard let config = call.arguments as? [String: Any], self.valid(config) else {
          result(FlutterError(code: "invalid_value_configuration", message: "Invalid finite range or value control configuration", details: nil))
          return
        }
        self.configure(config)
        result(nil)
      case "setSuppressed":
        self.routeSuppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
        self.updateVisibility()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func valid(_ config: [String: Any]) -> Bool {
    guard let min = config["min"] as? Double, let max = config["max"] as? Double,
          let value = config["value"] as? Double, let step = config["step"] as? Double,
          min.isFinite, max.isFinite, value.isFinite, step.isFinite,
          min < max, (max - min).isFinite, value >= min, value <= max, step > 0,
          config["kind"] as? String == kind else { return false }
    if let divisions = config["divisions"] as? Int, divisions <= 0 { return false }
    return true
  }

  /// All properties are installed together. UIKit setters never emit callbacks.
  private func configure(_ config: [String: Any]) {
    configuring = true
    defer { configuring = false }
    let incomingRevision = config["revision"] as? Int ?? revision
    if incomingRevision != revision {
      control.cancelTracking(with: nil)
    }
    let valueIsEcho = config["valueIsEcho"] as? Bool == true && incomingRevision == revision
    revision = incomingRevision
    minimum = (config["min"] as? NSNumber)?.doubleValue ?? 0
    maximum = (config["max"] as? NSNumber)?.doubleValue ?? 1
    if !valueIsEcho { value = (config["value"] as? NSNumber)?.doubleValue ?? minimum }
    divisions = config["divisions"] as? Int
    step = (config["step"] as? NSNumber)?.doubleValue ?? 1
    wraps = config["wraps"] as? Bool ?? false
    enabled = config["enabled"] as? Bool ?? true
    routeSuppressed = config["suppressed"] as? Bool ?? false
    popupOwner = config["popupOwner"] as? Bool ?? false
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    let direction: UISemanticContentAttribute = config["rtl"] as? Bool == true ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = direction
    control.semanticContentAttribute = direction
    control.accessibilityLabel = config["semanticLabel"] as? String
    let accent = Self.color(config["accent"])
    control.tintColor = accent // nil restores UIKit's inherited tint.
    if let toggle = control as? UISwitch {
      toggle.onTintColor = accent
      if !valueIsEcho { toggle.setOn(value >= 0.5, animated: false) }
    } else if let stepper = control as? UIStepper {
      // Expand bounds first so a new disjoint range cannot clamp an endpoint
      // before the other endpoint is installed.
      stepper.minimumValue = min(stepper.minimumValue, minimum)
      stepper.maximumValue = max(stepper.maximumValue, maximum)
      stepper.minimumValue = minimum
      stepper.maximumValue = maximum
      stepper.stepValue = step
      stepper.wraps = wraps
      if !valueIsEcho { stepper.value = value }
      stepper.accessibilityValue = config["semanticValue"] as? String
    }
    updateVisibility()
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    if hidden || !enabled {
      control.cancelTracking(with: nil)
    }
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    control.isEnabled = enabled && !hidden
  }

  private func currentValue() -> Double {
    if let toggle = control as? UISwitch { return toggle.isOn ? 1 : 0 }
    if let stepper = control as? UIStepper { return stepper.value }
    return value
  }

  private func emit(_ phase: String, _ candidate: Double) {
    guard !configuring, control.isEnabled, !container.isHidden else { return }
    channel.invokeMethod("valueEvent", arguments: ["phase": phase, "value": candidate, "revision": revision])
  }

  @objc private func changed() {
    guard !configuring, control.isEnabled, !container.isHidden else { return }
    value = currentValue()
    emit("change", value)
  }

  private func accessibilityAdjust(_ direction: Int) {
    guard control.isEnabled else { return }
    let proposed = value + Double(direction) * step
    var candidate = min(maximum, max(minimum, proposed))
    if wraps && proposed > maximum { candidate = minimum }
    if wraps && proposed < minimum { candidate = maximum }
    guard candidate != value else { return }
    value = candidate
    (control as? UIStepper)?.value = candidate
    emit("change", candidate)
  }

  func view() -> UIView { container }

  deinit {
    control.cancelTracking(with: nil)
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

/// UIKit owns slider tracking, including its final value. The bridge never
/// derives a business value from touch coordinates or a delayed timer.
private final class AdaptiveLiquidGlassNativeSlider: NSObject, FlutterPlatformView {
  private let container = AdaptiveGlassSliderContainer()
  private let slider = AdaptiveGlassTrackedSlider()
  private let touchSequence = AdaptiveGlassSliderTouchSequence()
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var suppressionObserver: UUID?
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var applicationActive = UIApplication.shared.applicationState == .active
  private var routeSuppressed = false
  private var popupOwner = false
  private var enabled = true
  private var configuring = false
  private var revision = 0
  private var nextGesture = 0
  private var activeGesture: Int?
  private var activeTracking: Int?
  private var activeTouchSequence: Int?
  private var pendingActivation: Int?
  private var activationInside = false
  private var activationPrimary = false
  private var activationEndComplete = false
  private var minimum = 0.0
  private var maximum = 1.0
  private var divisions: Int?
  private var value = 0.0
  private var lastNativeUnit: Float = 0
  private var semanticValue: String?

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    self.suppression = suppression
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/value-control/\(id)", binaryMessenger: messenger)
    super.init()
    container.frame = frame
    container.backgroundColor = .clear
    slider.translatesAutoresizingMaskIntoConstraints = false
    // UISlider's Float is only a unit coordinate; Dart's business range and
    // snapped detents remain Double, including ranges outside Float's limits.
    slider.minimumValue = 0
    slider.maximumValue = 1
    slider.isContinuous = true
    container.addSubview(slider)
    NSLayoutConstraint.activate([
      slider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
      slider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      slider.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])
    container.addGestureRecognizer(touchSequence)
    touchSequence.onNewSequence = { [weak self] in
      guard let self else { return false }
      if self.activeGesture != nil || self.slider.trackingIdentity != nil {
        self.cancelInteraction()
      } else {
        self.clearPendingActivation()
      }
      return self.canInteract
    }
    touchSequence.onCancellation = { [weak self] in self?.cancelInteraction() }
    touchSequence.onRelease = { [weak self] _ in self?.finishPendingActivation() }
    slider.shouldBegin = { [weak self] in self?.canInteract == true }
    slider.onBegin = { [weak self] tracking in self?.beginTracking(tracking) }
    slider.onEnd = { [weak self] tracking in self?.endTracking(tracking) }
    slider.onCancel = { [weak self] tracking in self?.cancelTracking(tracking) }
    slider.onWillCancel = { [weak self] in
      self?.touchSequence.invalidate()
      self?.clearPendingActivation()
    }
    slider.onUntrackedEnd = { [weak self] completed in self?.untrackedEnd(completed: completed) }
    slider.onAccessibilityAdjust = { [weak self] direction in self?.adjust(direction) }
    slider.addTarget(self, action: #selector(changed), for: .valueChanged)
    slider.addTarget(self, action: #selector(activatedInside), for: .touchUpInside)
    slider.addTarget(self, action: #selector(primaryActivated), for: .primaryActionTriggered)
    slider.addTarget(self, action: #selector(cancelledActivation), for: [.touchUpOutside, .touchCancel])
    container.onHierarchyChanged = { [weak self] in self?.updateVisibility() }
    for (name, active) in [(UIApplication.willResignActiveNotification, false),
                           (UIApplication.didBecomeActiveNotification, true)] {
      lifecycleObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.applicationActive = active
        self?.updateVisibility()
      })
    }
    _ = configure(arguments)
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "configure":
        guard let config = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_value_configuration", message: "Expected a slider configuration", details: nil))
          return
        }
        result(self.configure(config))
      case "setSuppressed":
        self.routeSuppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
        self.updateVisibility()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private var canInteract: Bool {
    !configuring && enabled && applicationActive && container.window != nil &&
      !routeSuppressed && !(suppression.active && !popupOwner)
  }

  private func configure(_ config: [String: Any]) -> FlutterError? {
    guard config["kind"] as? String == "slider",
          let minimum = (config["min"] as? NSNumber)?.doubleValue,
          let maximum = (config["max"] as? NSNumber)?.doubleValue,
          let value = (config["value"] as? NSNumber)?.doubleValue,
          minimum.isFinite, maximum.isFinite, value.isFinite,
          minimum < maximum, (maximum - minimum).isFinite,
          value >= minimum, value <= maximum else {
      return FlutterError(code: "invalid_value_configuration", message: "Invalid finite slider range or value", details: nil)
    }
    let divisions = config["divisions"] as? Int
    if let divisions, divisions <= 0 {
      return FlutterError(code: "invalid_value_configuration", message: "Slider divisions must be positive", details: nil)
    }
    let incomingRevision = config["revision"] as? Int ?? revision
    let echo = config["valueIsEcho"] as? Bool == true && incomingRevision == revision
    // Even if a caller omits a revision, changed tracking geometry must never
    // continue an operation that began with a different range or direction.
    let rtl = config["rtl"] as? Bool == true
    let direction: UISemanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
    let rangeChanged = self.minimum != minimum || self.maximum != maximum || self.divisions != divisions
    if incomingRevision != revision || rangeChanged || slider.semanticContentAttribute != direction || (!echo && value != self.value) {
      cancelInteraction()
    }
    configuring = true
    defer { configuring = false }
    revision = incomingRevision
    self.minimum = minimum
    self.maximum = maximum
    self.divisions = divisions
    enabled = config["enabled"] as? Bool ?? true
    routeSuppressed = config["suppressed"] as? Bool ?? false
    popupOwner = config["popupOwner"] as? Bool ?? false
    semanticValue = config["semanticValue"] as? String
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    container.semanticContentAttribute = direction
    slider.semanticContentAttribute = direction
    slider.accessibilityLabel = config["semanticLabel"] as? String
    let accent = Self.color(config["accent"])
    slider.tintColor = accent
    // UISlider's filled track has its own public tint override. nil restores
    // the system default rather than retaining the last explicit theme color.
    slider.minimumTrackTintColor = accent
    if rangeChanged, #available(iOS 26.0, *) {
      // Bound visual tick allocation independently of the public numeric range.
      // Above 256 divisions, keep the standard system track and business snapping;
      // hundreds of subpixel tick marks do not add useful visual information.
      if let divisions, divisions <= 256 {
        slider.trackConfiguration = .init(numberOfTicks: divisions + 1)
      } else {
        slider.trackConfiguration = nil
      }
    }
    if !echo || rangeChanged {
      self.value = value
      lastNativeUnit = unitValue(value)
      slider.setValue(lastNativeUnit, animated: false)
    }
    updateAccessibilityValue()
    updateVisibility()
    return nil
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    let effectiveEnabled = enabled && applicationActive && !hidden && container.window != nil
    if !effectiveEnabled { cancelInteraction() }
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
    slider.isEnabled = effectiveEnabled
  }

  private func unitValue(_ value: Double) -> Float {
    if value <= minimum { return 0 }
    if value >= maximum { return 1 }
    return Float((value - minimum) / (maximum - minimum))
  }

  private func businessValue(_ unit: Double) -> Double {
    var fraction = min(1.0, max(0.0, unit))
    if let divisions { fraction = (fraction * Double(divisions)).rounded() / Double(divisions) }
    // Preserve exact endpoints and avoid rounding a wide range beyond its bounds.
    if fraction <= 0 { return minimum }
    if fraction >= 1 { return maximum }
    return min(maximum, max(minimum, minimum + fraction * (maximum - minimum)))
  }

  private func beginTracking(_ tracking: Int) {
    guard canInteract, activeGesture == nil,
          let sequence = touchSequence.current, touchSequence.isEligible(sequence) else {
      slider.cancelTracking(with: nil)
      return
    }
    clearPendingActivation()
    nextGesture += 1
    activeGesture = nextGesture
    activeTracking = tracking
    activeTouchSequence = sequence
    emit("start", value)
    // UIKit may update the value during beginTracking before it accepts the
    // gesture. Read that native result after acceptance, never infer it ourselves.
    acceptNativeValue()
  }

  @objc private func changed() {
    guard canInteract, activeGesture != nil, activeTracking == slider.trackingIdentity else { return }
    acceptNativeValue()
  }

  private func acceptNativeValue() {
    // Merely pressing an unchanged thumb must not round a Double controlled
    // value through Float. Only a different system unit value proposes an edit.
    let nativeUnit = slider.value
    guard nativeUnit != lastNativeUnit else { return }
    lastNativeUnit = nativeUnit
    let candidate = businessValue(Double(nativeUnit))
    guard candidate != value else { return }
    value = candidate
    updateAccessibilityValue()
    emit("change", candidate)
  }

  private func endTracking(_ tracking: Int) {
    guard activeTracking == tracking, activeGesture != nil else { return }
    guard canInteract else { cancelInteraction(); return }
    // Called only after UISlider.endTracking has completed its system work.
    // Whether this is a reliable boundary is verified by physical-input XCTest.
    acceptNativeValue()
    if let sequence = activeTouchSequence { touchSequence.consume(sequence) }
    emit("end", value)
    activeGesture = nil
    activeTracking = nil
    activeTouchSequence = nil
  }

  private func cancelTracking(_ tracking: Int) {
    guard activeTracking == tracking else { return }
    if activeGesture != nil { emit("cancel", value) }
    activeGesture = nil
    activeTracking = nil
    activeTouchSequence = nil
    touchSequence.invalidate()
    clearPendingActivation()
  }

  private func cancelInteraction() {
    touchSequence.invalidate()
    clearPendingActivation()
    slider.cancelTracking(with: nil)
    if activeGesture != nil { emit("cancel", value) }
    activeGesture = nil
    activeTracking = nil
    activeTouchSequence = nil
  }

  private func clearPendingActivation() {
    pendingActivation = nil
    activationInside = false
    activationPrimary = false
    activationEndComplete = false
  }

  private func untrackedEnd(completed: Bool) {
    // Flutter can deliver a stationary press after release. UIKit then emits
    // endTracking(nil), touchUpInside and primaryAction without beginTracking.
    // Associate that public activation chain with a fresh real touch identity.
    guard canInteract, activeGesture == nil, let sequence = touchSequence.current,
          touchSequence.isEligible(sequence) else { return }
    if pendingActivation != sequence {
      clearPendingActivation()
      pendingActivation = sequence
    }
    if completed { activationEndComplete = true }
    finishPendingActivation()
  }

  @objc private func activatedInside() {
    guard pendingActivation != nil else { return }
    activationInside = true
    finishPendingActivation()
  }

  @objc private func primaryActivated() {
    guard pendingActivation != nil else { return }
    activationPrimary = true
    finishPendingActivation()
  }

  @objc private func cancelledActivation() {
    // This notification already comes from UIKit's terminal path. Do not call
    // cancelTracking again from inside its own action dispatch.
    touchSequence.invalidate()
    clearPendingActivation()
    if activeGesture != nil { emit("cancel", value) }
    activeGesture = nil
    activeTracking = nil
    activeTouchSequence = nil
  }

  private func finishPendingActivation() {
    guard canInteract, activeGesture == nil,
          let sequence = pendingActivation, touchSequence.isEligible(sequence),
          touchSequence.isReleased, activationInside, activationPrimary,
          activationEndComplete else { return }
    // Consume before callbacks. The drag's trailing activation and duplicate
    // terminals cannot create a second cycle; no timer or inferred value is used.
    touchSequence.consume(sequence)
    clearPendingActivation()
    nextGesture += 1
    activeGesture = nextGesture
    emit("start", value)
    acceptNativeValue()
    emit("end", value)
    activeGesture = nil
  }

  private func adjust(_ direction: Int) {
    guard canInteract, activeGesture == nil else { return }
    cancelInteraction()
    let unit = (value - minimum) / (maximum - minimum)
    let nextUnit = min(1.0, max(0.0, unit + Double(direction) / Double(divisions ?? 20)))
    let candidate = businessValue(nextUnit)
    guard candidate != value else { return }
    nextGesture += 1
    activeGesture = nextGesture
    emit("start", value)
    value = candidate
    lastNativeUnit = unitValue(candidate)
    slider.setValue(lastNativeUnit, animated: false)
    updateAccessibilityValue()
    emit("change", candidate)
    emit("end", candidate)
    activeGesture = nil
  }

  private func updateAccessibilityValue() {
    slider.accessibilityValue = semanticValue ?? "\(Int((Double(unitValue(value)) * 100).rounded()))%"
  }

  private func emit(_ phase: String, _ candidate: Double) {
    guard let activeGesture else { return }
    channel.invokeMethod("valueEvent", arguments: ["phase": phase, "value": candidate, "revision": revision, "gestureId": activeGesture])
  }

  func view() -> UIView { container }

  deinit {
    slider.onBegin = nil
    slider.onEnd = nil
    slider.onCancel = nil
    slider.onWillCancel = nil
    slider.onUntrackedEnd = nil
    slider.shouldBegin = nil
    slider.onAccessibilityAdjust = nil
    touchSequence.onNewSequence = nil
    touchSequence.onCancellation = nil
    touchSequence.onRelease = nil
    touchSequence.invalidate()
    slider.cancelTracking(with: nil)
    container.onHierarchyChanged = nil
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
    for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

/// Observes real touch identity without ever recognizing or preventing a gesture.
/// Values and completion still come exclusively from UISlider's public events.
private final class AdaptiveGlassSliderTouchSequence: UIGestureRecognizer {
  private var touches: Set<UITouch> = []
  private var nextSequence = 0
  private var consumedSequence: Int?
  private var cancelled = false
  private(set) var current: Int?
  var isReleased: Bool { touches.isEmpty }
  var onNewSequence: (() -> Bool)?
  var onCancellation: (() -> Void)?
  var onRelease: ((Int) -> Void)?

  init() {
    super.init(target: nil, action: nil)
    cancelsTouchesInView = false
    delaysTouchesBegan = false
    delaysTouchesEnded = false
  }

  override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
  override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

  func isEligible(_ sequence: Int) -> Bool {
    current == sequence && !cancelled && consumedSequence != sequence
  }

  func consume(_ sequence: Int) {
    if current == sequence { consumedSequence = sequence }
  }

  func invalidate() {
    current = nil
    cancelled = true
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    self.touches = self.touches.filter {
      $0.phase != .ended && $0.phase != .cancelled &&
        (event.allTouches?.contains($0) ?? true)
    }
    if self.touches.isEmpty {
      // Cancel an unfinished older control operation before minting permission
      // for this new real touch; programmatic updates cannot mint permission.
      let allowed = onNewSequence?() == true
      nextSequence += 1
      current = allowed ? nextSequence : nil
      cancelled = !allowed
    }
    self.touches.formUnion(touches)
    if self.touches.count > 1 {
      invalidate()
      onCancellation?()
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    guard !self.touches.isDisjoint(with: touches) else { return }
    self.touches.subtract(touches)
    if self.touches.isEmpty {
      state = .failed
      if let current { onRelease?(current) }
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    guard !self.touches.isDisjoint(with: touches) else { return }
    self.touches.subtract(touches)
    invalidate()
    onCancellation?()
    if self.touches.isEmpty { state = .failed }
  }

  override func reset() {
    super.reset()
    // A released identity survives until UIKit's activation chain consumes it.
    // The next actual begin reconciles old fingers after detach/cancellation.
  }
}

private final class AdaptiveGlassTrackedSlider: UISlider {
  var shouldBegin: (() -> Bool)?
  var onBegin: ((Int) -> Void)?
  var onEnd: ((Int) -> Void)?
  var onCancel: ((Int) -> Void)?
  var onWillCancel: (() -> Void)?
  var onUntrackedEnd: ((Bool) -> Void)?
  var onAccessibilityAdjust: ((Int) -> Void)?
  private var nextTrackingIdentity = 0
  private(set) var trackingIdentity: Int?

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    let accepted = shouldBegin?() == true && super.beginTracking(touch, with: event)
    guard accepted else { return false }
    nextTrackingIdentity += 1
    trackingIdentity = nextTrackingIdentity
    onBegin?(nextTrackingIdentity)
    return trackingIdentity != nil
  }

  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    let identity = trackingIdentity
    if identity == nil { onUntrackedEnd?(false) }
    super.endTracking(touch, with: event)
    if identity == nil { onUntrackedEnd?(true) }
    guard let identity, trackingIdentity == identity else { return }
    onEnd?(identity)
    if trackingIdentity == identity { trackingIdentity = nil }
  }

  override func cancelTracking(with event: UIEvent?) {
    let identity = trackingIdentity
    // UIKit may implement cancellation through endTracking(nil). Revoke even
    // an untracked press before super can dispatch any terminal actions.
    onWillCancel?()
    trackingIdentity = nil
    super.cancelTracking(with: event)
    if let identity { onCancel?(identity) }
  }

  override func accessibilityIncrement() { onAccessibilityAdjust?(1) }
  override func accessibilityDecrement() { onAccessibilityAdjust?(-1) }
}

private final class AdaptiveGlassSliderContainer: UIView {
  var onHierarchyChanged: (() -> Void)?
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    onHierarchyChanged?()
  }
  override func didMoveToWindow() {
    super.didMoveToWindow()
    onHierarchyChanged?()
  }
}

private final class AdaptiveGlassStepper: UIStepper {
  var onAccessibilityAdjust: ((Int) -> Void)?
  override var isAccessibilityElement: Bool { get { true } set {} }
  override var accessibilityTraits: UIAccessibilityTraits {
    get { isEnabled ? [.adjustable] : [.adjustable, .notEnabled] }
    set {}
  }
  override func accessibilityIncrement() { onAccessibilityAdjust?(1) }
  override func accessibilityDecrement() { onAccessibilityAdjust?(-1) }
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.insetBy(dx: -5, dy: -8).contains(point)
  }
}

private final class AdaptiveGlassSwitch: UISwitch {
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.insetBy(dx: -6, dy: -8).contains(point)
  }
}

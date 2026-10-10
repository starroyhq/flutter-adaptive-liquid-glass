import Flutter
import UIKit
import SwiftUI

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

/// SwiftUI owns the native slider's editing lifecycle. Modern UISlider can
/// deliver touch-up before its final valueChanged inside a Flutter platform
/// view, so observing UIKit touch phases cannot define a reliable commit.
private final class AdaptiveLiquidGlassNativeSlider: NSObject, FlutterPlatformView {
  private let container = AdaptiveGlassHostingContainer()
  private let channel: FlutterMethodChannel
  private let model = AdaptiveGlassSliderModel()
  private let hosting: UIHostingController<AdaptiveGlassSliderView>
  private var hostingConstraints: [NSLayoutConstraint] = []
  private var isAttached = false
  private let suppression: AdaptiveLiquidGlassSuppression
  private var suppressionObserver: UUID?
  private var revision = 0
  private var generation = 0
  private var nextGesture = 0
  private var activeGesture: Int?
  private var popupOwner = false
  private var routeSuppressed = false
  private var enabled = true

  init(frame: CGRect, id: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    self.suppression = suppression
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/value-control/\(id)", binaryMessenger: messenger)
    hosting = UIHostingController(rootView: AdaptiveGlassSliderView(model: model))
    super.init()
    container.frame = frame
    container.backgroundColor = .clear
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    hostingConstraints = [
      hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ]
    model.onValue = { [weak self] value, generation in self?.propose(value, generation: generation) }
    model.onEditing = { [weak self] editing, generation in self?.editing(editing, generation: generation) }
    model.onAdjust = { [weak self] direction, generation in self?.adjust(direction, generation: generation) }
    container.onHierarchyChanged = { [weak self] in self?.updateHostingParent() }
    _ = configure(arguments)
    suppressionObserver = suppression.observe { [weak self] in self?.updateVisibility() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "configure":
        guard let configuration = call.arguments as? [String: Any] else {
          result(FlutterError(code: "invalid_value_configuration", message: "Expected a slider configuration", details: nil))
          return
        }
        result(self.configure(configuration))
      case "setSuppressed":
        self.routeSuppressed = (call.arguments as? [String: Any])?["suppressed"] as? Bool ?? false
        self.updateVisibility()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configure(_ configuration: [String: Any]) -> FlutterError? {
    guard configuration["kind"] as? String == "slider",
          let minimum = (configuration["min"] as? NSNumber)?.doubleValue,
          let maximum = (configuration["max"] as? NSNumber)?.doubleValue,
          let value = (configuration["value"] as? NSNumber)?.doubleValue,
          minimum.isFinite, maximum.isFinite, value.isFinite,
          minimum < maximum, (maximum - minimum).isFinite,
          value >= minimum, value <= maximum else {
      return FlutterError(code: "invalid_value_configuration", message: "Invalid finite slider range or value", details: nil)
    }
    let divisions = configuration["divisions"] as? Int
    if let divisions, divisions <= 0 {
      return FlutterError(code: "invalid_value_configuration", message: "Slider divisions must be positive", details: nil)
    }
    let incomingRevision = configuration["revision"] as? Int ?? revision
    let echo = configuration["valueIsEcho"] as? Bool == true && incomingRevision == revision
    if incomingRevision != revision {
      // Recreate only the SwiftUI interaction identity on authoritative reset.
      // Accepted echoes retain both the hosted control and the current gesture.
      activeGesture = nil
      generation += 1
    }
    revision = incomingRevision
    enabled = configuration["enabled"] as? Bool ?? true
    popupOwner = configuration["popupOwner"] as? Bool ?? false
    routeSuppressed = configuration["suppressed"] as? Bool ?? false
    var next = model.configuration
    next.minimum = minimum
    next.maximum = maximum
    next.divisions = divisions
    if !echo { next.value = value }
    next.accent = Self.color(configuration["accent"])
    next.label = configuration["semanticLabel"] as? String
    next.semanticValue = configuration["semanticValue"] as? String
    next.dark = configuration["dark"] as? Bool ?? false
    next.rtl = configuration["rtl"] as? Bool ?? false
    next.generation = generation
    model.configuration = next
    updateVisibility()
    return nil
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    let effectiveEnabled = enabled && !hidden
    var next = model.configuration
    if next.enabled != effectiveEnabled {
      activeGesture = nil
      generation += 1
      next.generation = generation
    }
    next.enabled = effectiveEnabled
    model.configuration = next
    container.isHidden = hidden
    container.accessibilityElementsHidden = hidden
  }

  private func updateHostingParent() {
    guard container.window != nil else {
      detachHosting()
      return
    }
    var responder: UIResponder? = container.superview
    while let current = responder {
      if let parent = current as? UIViewController {
        guard hosting.parent !== parent else { return }
        detachHosting()
        parent.addChild(hosting)
        container.addSubview(hosting.view)
        NSLayoutConstraint.activate(hostingConstraints)
        hosting.didMove(toParent: parent)
        isAttached = true
        return
      }
      responder = current.next
    }
    detachHosting()
  }

  private func detachHosting() {
    guard isAttached else { return }
    isAttached = false
    // A delayed begin or binding write can arrive before an active gesture was
    // recorded. Every actual detach invalidates the old SwiftUI closures.
    activeGesture = nil
    generation += 1
    var next = model.configuration
    next.generation = generation
    model.configuration = next
    hosting.willMove(toParent: nil)
    NSLayoutConstraint.deactivate(hostingConstraints)
    hosting.view.removeFromSuperview()
    hosting.removeFromParent()
  }

  private func begin() {
    guard activeGesture == nil else { return }
    nextGesture += 1
    activeGesture = nextGesture
    emit("start", model.configuration.value)
  }

  private func propose(_ value: Double, generation: Int) {
    guard isAttached, container.window != nil, generation == self.generation,
          model.configuration.enabled, value.isFinite else { return }
    var next = model.configuration
    var candidate = min(next.maximum, max(next.minimum, value))
    if let divisions = next.divisions {
      let fraction = ((candidate - next.minimum) / (next.maximum - next.minimum) * Double(divisions)).rounded() / Double(divisions)
      candidate = next.minimum + fraction * (next.maximum - next.minimum)
    }
    // SwiftUI can repeat its final binding write after editing(false). Check
    // the normalized value before opening a gesture so that this echo cannot
    // create a second start with no corresponding end. A real no-change press
    // still starts through editing(true).
    guard candidate != next.value else { return }
    begin()
    next.value = candidate
    model.configuration = next
    emit("change", candidate)
  }

  private func editing(_ editing: Bool, generation: Int) {
    guard isAttached, container.window != nil, generation == self.generation,
          model.configuration.enabled else { return }
    if editing {
      begin()
    } else if activeGesture != nil {
      emit("end", model.configuration.value)
      activeGesture = nil
    }
  }

  private func adjust(_ direction: Int, generation: Int) {
    guard isAttached, container.window != nil, generation == self.generation,
          model.configuration.enabled else { return }
    let state = model.configuration
    let increment = (state.maximum - state.minimum) / Double(state.divisions ?? 20)
    let candidate = min(state.maximum, max(state.minimum, state.value + Double(direction) * increment))
    guard candidate != state.value else { return }
    propose(candidate, generation: generation)
    editing(false, generation: generation)
  }

  private func emit(_ phase: String, _ value: Double) {
    guard let activeGesture else { return }
    channel.invokeMethod("valueEvent", arguments: ["phase": phase, "value": value, "revision": revision, "gestureId": activeGesture])
  }

  func view() -> UIView { container }

  deinit {
    container.onHierarchyChanged = nil
    channel.setMethodCallHandler(nil)
    if let suppressionObserver { suppression.remove(suppressionObserver) }
    if hosting.parent != nil {
      hosting.willMove(toParent: nil)
      NSLayoutConstraint.deactivate(hostingConstraints)
      hosting.view.removeFromSuperview()
      hosting.removeFromParent()
    }
  }

  private static func color(_ value: Any?) -> UIColor? {
    guard let number = value as? NSNumber else { return nil }
    let argb = number.uint32Value
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255, blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}

private final class AdaptiveGlassHostingContainer: UIView {
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

private struct AdaptiveGlassSliderConfiguration {
  var value = 0.0
  var minimum = 0.0
  var maximum = 1.0
  var divisions: Int?
  var enabled = true
  var accent: UIColor?
  var label: String?
  var semanticValue: String?
  var dark = false
  var rtl = false
  var generation = 0
}

private final class AdaptiveGlassSliderModel: ObservableObject {
  @Published var configuration = AdaptiveGlassSliderConfiguration()
  var onValue: ((Double, Int) -> Void)?
  var onEditing: ((Bool, Int) -> Void)?
  var onAdjust: ((Int, Int) -> Void)?
}

private struct AdaptiveGlassSliderView: View {
  @ObservedObject var model: AdaptiveGlassSliderModel

  var body: some View {
    let state = model.configuration
    let binding = Binding<Double>(
      get: { model.configuration.value },
      set: { model.onValue?($0, state.generation) }
    )
    let editing: (Bool) -> Void = { model.onEditing?($0, state.generation) }
    Group {
      if let divisions = state.divisions {
        Slider(value: binding, in: state.minimum...state.maximum,
               step: (state.maximum - state.minimum) / Double(divisions), onEditingChanged: editing)
      } else {
        Slider(value: binding, in: state.minimum...state.maximum, onEditingChanged: editing)
      }
    }
    .id(state.generation)
    .tint(state.accent.map { Color(uiColor: $0) })
    .disabled(!state.enabled)
    .accessibilityLabel(Text(state.label ?? ""))
    .accessibilityValue(Text(state.semanticValue ?? "\(Int(((state.value - state.minimum) / (state.maximum - state.minimum) * 100).rounded()))%"))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: model.onAdjust?(1, state.generation)
      case .decrement: model.onAdjust?(-1, state.generation)
      @unknown default: break
      }
    }
    .environment(\.layoutDirection, state.rtl ? .rightToLeft : .leftToRight)
    .environment(\.colorScheme, state.dark ? .dark : .light)
    .padding(.horizontal, 8)
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

import Flutter
import UIKit

/// Observes only the Flutter view served by this engine, while Dart is listening.
final class AdaptiveLiquidGlassWindowGeometry: NSObject, FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var events: FlutterEventSink?
  private var probe: WindowGeometryProbe?
  private var observers: [NSObjectProtocol] = []
  private var lastSnapshot: NSDictionary?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    stop()
    self.events = events
    let notifications = [
      UIWindow.didBecomeVisibleNotification,
      UIScene.didActivateNotification,
    ]
    observers = notifications.map { name in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] _ in self?.attach()
      }
    }
    attach()
    // An implicit Flutter engine may have registered before it has a controller.
    DispatchQueue.main.async { [weak self] in self?.attach() }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    return nil
  }

  private func attach() {
    guard events != nil else { return }
    guard let view = registrar?.viewController?.viewIfLoaded else { return }
    if let probe, probe.superview === view {
      probe.scheduleUpdate()
      return
    }
    probe?.removeFromSuperview()
    let next = WindowGeometryProbe(frame: view.bounds)
    next.onChange = { [weak self] probe in self?.emit(from: probe) }
    probe = next
    view.insertSubview(next, at: 0)
    next.setNeedsUpdateConstraints()
    next.scheduleUpdate()
  }

  private func emit(from probe: WindowGeometryProbe) {
    guard self.probe === probe, let events, let snapshot = probe.snapshot() else { return }
    let comparable = snapshot as NSDictionary
    guard lastSnapshot != comparable else { return }
    lastSnapshot = comparable
    events(snapshot)
  }

  private func stop() {
    events = nil
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    probe?.removeFromSuperview()
    probe = nil
    lastSnapshot = nil
  }

  deinit { stop() }
}

private final class WindowGeometryProbe: UIView {
  var onChange: ((WindowGeometryProbe) -> Void)?
  private var updateScheduled = false
  private var hingePosture: String?
  private var cornerGuide: UILayoutGuide?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) {
        (view: WindowGeometryProbe, _: UITraitCollection) in view.scheduleUpdate()
      }
    }
    #if compiler(>=6.4)
      if #available(iOS 27.1, *) {
        registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
          (view: WindowGeometryProbe, _: UITraitCollection) in view.scheduleUpdate()
        }
        addInteraction(UIHingeInteraction { [weak self] _, update in
          guard let self else { return }
          let posture: String?
          switch update.hinge?.status {
          case .partiallyOpen: posture = "halfOpened"
          case .fullyOpen: posture = "flat"
          default: posture = nil
          }
          guard hingePosture != posture else { return }
          hingePosture = posture
          scheduleUpdate()
        })
      }
    #endif
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if #available(iOS 26.0, *), window != nil, traitCollection.userInterfaceIdiom == .pad {
      observeCornerGuide()
    }
    scheduleUpdate()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    scheduleUpdate()
  }

  override func updateConstraints() {
    #if compiler(>=6.4)
      if #available(iOS 27.1, *) {
        // UIKit tracks these reads in updateConstraints, even when the view size is unchanged.
        _ = reservedRegions(kind: .division, options: .includeInactive)
        _ = reservedRegions(kind: .occlusion, options: .includeInactive)
      }
    #endif
    scheduleUpdate()
    super.updateConstraints()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    scheduleUpdate()
  }

  @available(iOS, deprecated: 17.0)
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      scheduleUpdate()
    }
  }

  func scheduleUpdate() {
    guard !updateScheduled else { return }
    updateScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      updateScheduled = false
      onChange?(self)
    }
  }

  func snapshot() -> [String: Any]? {
    guard window != nil, bounds.width > 0, bounds.height > 0 else { return nil }
    var snapshot: [String: Any] = [
      "width": Double(bounds.width),
      "height": Double(bounds.height),
      "reservedRegions": [[String: Any]](),
    ]
    snapshot["horizontalSizeClass"] = sizeClassName(traitCollection.horizontalSizeClass)
    snapshot["verticalSizeClass"] = sizeClassName(traitCollection.verticalSizeClass)
    if let frame = cornerGuide?.layoutFrame, !frame.isEmpty {
      snapshot["windowControlMargins"] = [
        "left": Double(max(0, frame.minX - bounds.minX)),
        "top": Double(max(0, frame.minY - bounds.minY)),
        "right": Double(max(0, bounds.maxX - frame.maxX)),
        "bottom": Double(max(0, bounds.maxY - frame.maxY)),
      ]
    }
    #if compiler(>=6.4)
      if #available(iOS 27.1, *) {
        switch traitCollection.verticalBarEdge {
        case .leading: snapshot["verticalBarEdge"] = "leading"
        case .trailing: snapshot["verticalBarEdge"] = "trailing"
        default: break
        }
        let divisions = regionSnapshots(kind: .division, name: "division", posture: hingePosture)
        let occlusions = regionSnapshots(kind: .occlusion, name: "occlusion", posture: nil)
        snapshot["reservedRegions"] = divisions + occlusions
      }
    #endif
    return snapshot
  }

  private func sizeClassName(_ sizeClass: UIUserInterfaceSizeClass) -> String? {
    switch sizeClass {
    case .compact: return "compact"
    case .regular: return "regular"
    default: return nil
    }
  }

  @available(iOS 26.0, *)
  private func observeCornerGuide() {
    guard cornerGuide == nil else { return }
    let guide = layoutGuide(for: .margins(cornerAdaptation: .horizontal))
    let witness = WindowGeometryGuideProbe()
    witness.onChange = { [weak self] in self?.scheduleUpdate() }
    witness.isOpaque = false
    witness.isUserInteractionEnabled = false
    witness.accessibilityElementsHidden = true
    witness.translatesAutoresizingMaskIntoConstraints = false
    addSubview(witness)
    NSLayoutConstraint.activate([
      witness.leftAnchor.constraint(equalTo: guide.leftAnchor),
      witness.topAnchor.constraint(equalTo: guide.topAnchor),
      witness.rightAnchor.constraint(equalTo: guide.rightAnchor),
      witness.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
    ])
    cornerGuide = guide
  }

  #if compiler(>=6.4)
    @available(iOS 27.1, *)
    private func regionSnapshots(kind: UIView.ReservedRegion.Kind, name: String, posture: String?)
      -> [[String: Any]]
    {
      let regions = reservedRegions(kind: kind, options: .includeInactive).sorted { lhs, rhs in
        let left = lhs.frame
        let right = rhs.frame
        return (left.minX, left.minY, left.width, left.height, lhs.isActive ? 1 : 0)
          < (right.minX, right.minY, right.width, right.height, rhs.isActive ? 1 : 0)
      }
      return regions.map { region in
        // ReservedRegion.frame already includes the system's interactive margins.
        let frame = region.frame
        var result: [String: Any] = [
          "kind": name,
          "x": Double(frame.minX),
          "y": Double(frame.minY),
          "width": Double(frame.width),
          "height": Double(frame.height),
          "active": region.isActive,
        ]
        result["posture"] = posture
        return result
      }
    }
  #endif
}

private final class WindowGeometryGuideProbe: UIView {
  var onChange: (() -> Void)?

  override var frame: CGRect {
    didSet {
      if oldValue != frame { onChange?() }
    }
  }
}

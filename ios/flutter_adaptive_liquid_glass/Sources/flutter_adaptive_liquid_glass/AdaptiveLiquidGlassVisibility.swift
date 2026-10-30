// The fade is adapted from native_liquid_glass 0.3.1 (MIT); see
// THIRD_PARTY_NOTICES.md.
import Flutter
import UIKit

/// Track the package's aggregate suppression notifications from plugin
/// registration onward, so a platform view created beneath an existing popup
/// starts hidden as well.
final class AdaptiveLiquidGlassSuppression {
  /// Posted by `FlutterAdaptiveLiquidGlassPlugin` when Flutter presents the
  /// first popup route over native views, and when the last one has left.
  static let suppressAll = Notification.Name("FlutterAdaptiveLiquidGlassSuppressAll")
  static let unsuppressAll = Notification.Name("FlutterAdaptiveLiquidGlassUnsuppressAll")

  private(set) var active = false
  private var observers: [NSObjectProtocol] = []
  private var listeners: [UUID: () -> Void] = [:]

  init() {
    for (name, value) in [(Self.suppressAll, true), (Self.unsuppressAll, false)] {
      observers.append(NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        guard let self else { return }
        self.active = value
        for update in self.listeners.values { update() }
      })
    }
  }
  func observe(_ update: @escaping () -> Void) -> UUID {
    let token = UUID()
    listeners[token] = update
    return token
  }
  func remove(_ token: UUID) { listeners.removeValue(forKey: token) }
  deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
}

/// Hides a platform view whose Flutter route is covered, or that lies beneath a
/// popup it does not belong to. The view fades out in 0.15 s after 0.3 s and
/// returns at once; the state it is created with applies without animation. A
/// hidden view leaves the accessibility tree and stops taking touches at once.
final class AdaptiveLiquidGlassFade {
  private weak var view: UIView?
  private let suppression: AdaptiveLiquidGlassSuppression
  private var token: UUID?
  private var routeSuppressed: Bool
  private var popupOwner: Bool
  private(set) var hidden: Bool

  init(view: UIView, suppression: AdaptiveLiquidGlassSuppression,
       routeSuppressed: Bool, popupOwner: Bool) {
    self.view = view
    self.suppression = suppression
    self.routeSuppressed = routeSuppressed
    self.popupOwner = popupOwner
    hidden = routeSuppressed || (suppression.active && !popupOwner)
    apply(animated: false)
    token = suppression.observe { [weak self] in self?.update() }
  }

  /// Applies the route state that Dart computed for the view.
  func setRoute(suppressed: Bool, popupOwner: Bool) {
    routeSuppressed = suppressed
    self.popupOwner = popupOwner
    update()
  }

  private func update() {
    // A popup does not hide its own native views. A popup above it makes the
    // owner's route non-current, and route suppression wins.
    let next = routeSuppressed || (suppression.active && !popupOwner)
    guard next != hidden else { return }
    hidden = next
    apply(animated: true)
  }

  private func apply(animated: Bool) {
    guard let view else { return }
    view.accessibilityElementsHidden = hidden
    view.isUserInteractionEnabled = !hidden
    view.layer.removeAllAnimations()
    if hidden && animated {
      // Flutter takes a covered view out of composition and paints the
      // control's Flutter rendering in its place in the same frame. This
      // message can arrive before that frame is on screen, so the fade waits
      // for it rather than leaving neither on screen.
      UIView.animate(withDuration: 0.15, delay: 0.3) { view.alpha = 0 }
    } else {
      // A returning view has the control's Flutter rendering under it until
      // it is back, so it appears at once.
      view.alpha = hidden ? 0 : 1
    }
  }

  deinit { if let token { suppression.remove(token) } }
}

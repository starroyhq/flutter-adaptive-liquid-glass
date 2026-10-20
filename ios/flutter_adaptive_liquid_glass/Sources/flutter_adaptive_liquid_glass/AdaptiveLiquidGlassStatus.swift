import Flutter
import UIKit

final class AdaptiveLiquidGlassStatusFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let suppression = AdaptiveLiquidGlassSuppression()

  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AdaptiveLiquidGlassStatus(frame: frame, id: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger, suppression: suppression)
  }
}

private final class AdaptiveLiquidGlassStatus: NSObject, FlutterPlatformView {
  private let container: AdaptiveGlassStatusContainer
  private let channel: FlutterMethodChannel
  private let suppression: AdaptiveLiquidGlassSuppression
  private var observer: UUID?
  private var popupOwner = false
  private var routeSuppressed = false
  private var animating = false

  init(frame: CGRect, id: Int64, arguments: [String: Any],
       messenger: FlutterBinaryMessenger, suppression: AdaptiveLiquidGlassSuppression) {
    container = AdaptiveGlassStatusContainer(frame: frame)
    channel = FlutterMethodChannel(name: "flutter_adaptive_liquid_glass/status/\(id)",
                                   binaryMessenger: messenger)
    self.suppression = suppression
    super.init()
    if let error = configure(arguments) {
      container.isHidden = true
      assertionFailure(error.message ?? "Invalid status configuration")
    }
    observer = suppression.observe { [weak self] in self?.updateVisibility() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "configure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let config = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_status_configuration",
                           message: "Expected a status configuration.", details: nil))
        return
      }
      result(self.configure(config))
    }
  }

  private func configure(_ config: [String: Any]) -> FlutterError? {
    guard let kind = config["kind"] as? String, ["activity", "progress"].contains(kind),
          let progress = (config["progress"] as? NSNumber)?.doubleValue,
          progress.isFinite, progress >= 0, progress <= 1,
          let height = (config["height"] as? NSNumber)?.doubleValue,
          height.isFinite, height > 0,
          let style = config["style"] as? String, ["medium", "large"].contains(style) else {
      return FlutterError(code: "invalid_status_configuration",
                          message: "Invalid status kind, progress, height or style.", details: nil)
    }
    // Both UIKit instances are retained. No progress/color update recreates a
    // platform view, and nullable colors explicitly restore UIKit defaults.
    container.kind = kind
    container.progressHeight = CGFloat(height)
    container.overrideUserInterfaceStyle = config["dark"] as? Bool == true ? .dark : .light
    let direction: UISemanticContentAttribute = config["rtl"] as? Bool == true ? .forceRightToLeft : .forceLeftToRight
    container.semanticContentAttribute = direction
    container.progress.semanticContentAttribute = direction
    container.activity.semanticContentAttribute = direction
    container.progress.progressTintColor = Self.color(config["color"])
    container.progress.trackTintColor = Self.color(config["trackColor"])
    container.progress.setProgress(Float(progress), animated: false)
    container.activity.style = style == "large" ? .large : .medium
    container.activity.color = Self.color(config["color"])
    animating = config["animating"] as? Bool ?? false
    popupOwner = config["popupOwner"] as? Bool ?? false
    routeSuppressed = config["suppressed"] as? Bool ?? false
    container.setNeedsLayout()
    updateVisibility()
    return nil
  }

  private func updateVisibility() {
    let hidden = routeSuppressed || (suppression.active && !popupOwner)
    container.isHidden = hidden
    container.progress.isHidden = container.kind != "progress"
    container.activity.isHidden = container.kind != "activity"
    let shouldAnimate = container.kind == "activity" && animating && !hidden
    if shouldAnimate && !container.activity.isAnimating {
      container.activity.startAnimating()
    } else if !shouldAnimate && container.activity.isAnimating {
      container.activity.stopAnimating()
    }
  }

  func view() -> UIView { container }

  deinit {
    container.activity.stopAnimating()
    channel.setMethodCallHandler(nil)
    if let observer { suppression.remove(observer) }
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

private final class AdaptiveGlassStatusContainer: UIView {
  let progress = UIProgressView(progressViewStyle: .default)
  let activity = UIActivityIndicatorView(style: .medium)
  var kind = "progress"
  var progressHeight: CGFloat = 4

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    // Flutter supplies a single label/value node for both rendering paths.
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    progress.isAccessibilityElement = false
    activity.isAccessibilityElement = false
    activity.hidesWhenStopped = false
    addSubview(progress)
    addSubview(activity)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    let progressSize = progress.sizeThatFits(CGSize(width: bounds.width, height: progressHeight))
    let intrinsicHeight = max(1, progressSize.height)
    progress.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: intrinsicHeight)
    progress.center = CGPoint(x: bounds.midX, y: bounds.midY)
    progress.transform = CGAffineTransform(scaleX: 1, y: progressHeight / intrinsicHeight)
    let activitySize = activity.intrinsicContentSize
    activity.bounds = CGRect(origin: .zero, size: activitySize)
    activity.center = CGPoint(x: bounds.midX, y: bounds.midY)
    let scale = min(1, min(bounds.width / max(1, activitySize.width),
                           bounds.height / max(1, activitySize.height)))
    activity.transform = CGAffineTransform(scaleX: scale, y: scale)
  }
}

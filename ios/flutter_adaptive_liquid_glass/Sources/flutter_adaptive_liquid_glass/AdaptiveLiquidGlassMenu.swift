import Flutter
import UIKit

/// Converts the shared menu data into UIKit actions and submenus. The owning
/// control decides when a selection is still valid and how to deliver it.
enum AdaptiveLiquidGlassMenu {
  static func make(
    items: [[String: Any]], onSelect: @escaping (Int) -> Void
  ) -> UIMenu {
    UIMenu(children: items.compactMap { element($0, onSelect: onSelect) })
  }

  private static func element(
    _ item: [String: Any], onSelect: @escaping (Int) -> Void
  ) -> UIMenuElement? {
    guard let id = item["id"] as? Int, let label = item["label"] as? String else { return nil }
    let icon = image(item)
    let enabled = item["enabled"] as? Bool ?? true
    let destructive = item["destructive"] as? Bool == true
    let children = item["children"] as? [[String: Any]] ?? []
    if enabled && !children.isEmpty {
      return UIMenu(
        title: label, image: icon, options: destructive ? .destructive : [],
        children: children.compactMap { element($0, onSelect: onSelect) })
    }
    var attributes: UIMenuElement.Attributes = []
    if !enabled { attributes.insert(.disabled) }
    if destructive { attributes.insert(.destructive) }
    return UIAction(
      title: label, image: icon, attributes: attributes,
      state: item["selected"] as? Bool == true ? .on : .off
    ) { _ in
      guard enabled, children.isEmpty else { return }
      onSelect(id)
    }
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

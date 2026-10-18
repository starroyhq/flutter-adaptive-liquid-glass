# flutter_adaptive_liquid_glass 0.5.2

This patch fixes how native glass controls look next to their fallbacks on iOS
26: SF Symbols in native buttons were about a third larger than the matching
Material icons, a sheet lost its material while an alert covered it, and the
native segmented control was narrower than the space it was given. The fallback
slider and switch thumbs are now white in a dark theme. No public API changes,
no new production dependencies and no toolchain upgrade.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.5.2
```

Run `flutter pub get` and rebuild the native app. Flutter 3.41.2+, Dart 3.11+,
iOS 16+ and Android remain supported; native glass requires iOS 26+.
`native_liquid_glass` stays pinned to 0.3.1.

## Changes

- Native symbol size. A symbol's point size is a font size, and native buttons
  sized every symbol as a 22-point font, so it looked about a third larger than
  the fallback's 22-point Material icon. A symbol beside a title now takes the
  title's font, as UIKit buttons do. A symbol on its own, or with a requested
  `iconSize`, is sized at 0.75 of the icon size: a 22-point icon becomes a
  16.5-point symbol. Icon-only buttons pass that size to `native_liquid_glass`;
  bitmap icons keep their 22-point box. The width reserved for a symbol beside a
  title follows the new size.
- Covered native surfaces. While another route covers a native
  `LiquidGlassSurface`, its system material leaves the compositor so it cannot
  clip the Flutter content above it. A sheet under an alert then showed its
  content over the page. The surface now paints an opaque material in its place,
  6% of the way from the colour scheme's surface to its foreground, the tone the
  system material has over a plain page, or the surface's tint when it has one.
  Native controls inside the surface, such as buttons and progress bars, still
  hide until the route above leaves.
- Native segmented control width. `native_liquid_glass` 0.3.1 insets its
  SwiftUI picker by 16 points on each side. The package widens the platform view
  by that much, so the segments span the width the control was given; touches
  still land only inside that width.
- Fallback thumbs. Slider and switch thumbs used the colour scheme's lowest
  surface, which some dark themes make black. They are white in both
  appearances, as on iOS, unless the palette sets `surfaceTint`.

## Validation

The source passed `dart format`, analysis of the package and the example, 312
package tests (3 new: the covered surface's material, the icon-only symbol size
and the segmented control's width) and 8 example tests. `pod install` for the
example passed.

The changes were checked from screenshots of a consuming app built against this
source with a local override, on an iOS 26.5 simulator with native glass and on
iOS 18.6 with the fallback, in light and dark appearance: buttons with a symbol
and a title, icon-only buttons and capsules, toolbars, segmented controls, a
sheet under an alert and a fallback slider. The comparison images are not part
of the package.

The gating `Component checks` run for the tagged commit, including the native
iOS 26.5 interaction job, is linked from the GitHub release.

## Known validation limits

The independent first-use system colour-palette failure recorded for 0.2.1
remains unresolved in some hosted iOS 26.5 runs; this release does not touch that
path. The symbol conversion is one factor for every symbol, so symbols with
unusual proportions still differ somewhat from their Material counterparts.
Native titles keep the system's 17-point semibold font; the fallback uses the
app's text style. Physical devices and large text were not checked.

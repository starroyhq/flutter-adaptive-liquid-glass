# flutter_adaptive_liquid_glass 0.4.0

This minor release draws the native `LiquidGlassSurface` material with a
package-owned UIKit view, adds opt-in content sizing for sheets and an action row
for sheets and forms, and changes how a disabled prominent button is drawn.
Existing public APIs remain available, with no new production dependencies or
toolchain upgrade.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.4.0
```

Run `flutter pub get` and rebuild the native app. Flutter 3.41.2+, Dart 3.11+,
iOS 16+ and Android remain supported; native glass requires iOS 26+.
`native_liquid_glass` stays pinned to 0.3.1.

## Changes

- Draw the native `LiquidGlassSurface` material with a package-owned
  `UIVisualEffectView` and `UIGlassEffect` instead of the provider's SwiftUI
  `LiquidGlassContainer`. The provider's container lays its shape out inside the
  window's safe area and does not refresh the insets it read at first layout, so
  a sheet, which is created below the screen and slides in, could end up shorter
  than its content or stay missing until something resized it. Radius, tint, the
  fill behind the glass, route coverage and popup suppression are unchanged.
- Add opt-in `fitContent` to `showLiquidGlassSheet`: the sheet is as tall as its
  content, up to the large detent, rests on the bottom safe area and rides above
  the keyboard. The handle pulls the whole sheet down to dismiss it. The default
  sheet is unchanged.
- Add `LiquidGlassActionBar`: the last action is a prominent button at the
  trailing edge and any earlier ones share one glass capsule at the leading
  edge; they stack when they do not fit on one line.
- Add an optional `id` to `LiquidGlassButton` and `LiquidGlassButton.icon`, the
  accessibility identifier of the native button (`button` as before when null).
  `LiquidGlassActionBar` passes its action ids through, so UI tests find the
  prominent button by the same identifier as the grouped ones.
- Draw a disabled `prominent` button like any other disabled button. On iOS 26 it
  was a solid accent capsule under a label too faint to read, and the fallback
  drew a gray pill. A loading button keeps its fill. This is a deliberate visual
  change.

## Validation

The source passed `dart format`, analysis of the package and the example, 284
package tests and 8 example tests. Mutation checks confirmed that the button tests
fail without the disabled-button change.

On iOS 26.5 simulators (iPhone 17 Pro) the bottom edge of the sheet panel on its
first settled frame was read from screenshots, expected 840 pt. The provider's
container ended at 823 pt when idle and 806 pt, or was missing, while twelve busy
processes competed for the CPU. The package-owned view ended at 839.7 pt in every
measured run, for a content-sized panel built from `LiquidGlassSurface` and for the
`fitContent` sheet, and the default medium-detent sheet ended there in two runs
while other builds kept the machine busy. The method and numbers are in
[native surface validation](native-surface-validation.md).

A consuming application, the AgentKib Flutter app, was built against this source
in a scratch copy. Its 328 tests passed, its native XCUITest acceptance classes
passed 8 of 8 on iOS 26.5 with its Swift tests unchanged, and its fallback flow
passed on iOS 18.6. Screenshots of the action bar, the content-sized sheet and the
button states were inspected on iOS 26.5 in light and dark appearance and on iOS
18.6, and the app's sheets also on iOS 27.0.

The gating `Component checks` run for the tagged commit, including the native
iOS 26.5 interaction job, is linked from the GitHub release.

## Known validation limits

The independent first-use system color-palette failure recorded for 0.2.1 remains
unresolved in some hosted iOS 26.5 runs. This release does not modify that
presentation path or claim that the failure is fixed or that physical devices are
unaffected. See the
[existing validation record](native-accessibility-validation.md#release-decision-and-remaining-boundary).

The sheet measurements come from simulators at one device size; physical devices
were not measured. The cause of the provider's shortfall is described from its
observed behavior, its source and two one-line patches that remove it, and has
not been confirmed with the provider's maintainer. The provider's other
SwiftUI-hosted views were not measured for the same effect. Large text was
inspected for the action bar on iOS 26.5 only.

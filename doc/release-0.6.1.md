# flutter_adaptive_liquid_glass 0.6.1

This patch makes a drag on the native slider follow the finger, keeps every
tab reachable where iOS 27.1 and later put the tab bar in the vertical bar at
the screen edge, and in debug builds explains why a control whose mode resolves
to native draws its Flutter rendering. No public API changes, no new
production dependencies and no toolchain upgrade.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.6.1
```

`^0.6.0` already includes this version: run `flutter pub upgrade` and rebuild
the native app. Flutter 3.41.2+, Dart 3.11+, iOS 16+ and Android remain
supported; native glass requires iOS 26+ and builds with Xcode 26 or later.

## Changes

- Native slider drag. A drag that starts on the thumb keeps the point where the
  finger pressed it. Before, the movement until Flutter's drag gesture passed
  its touch slop (about 18 points) was lost and the thumb ended that far behind
  the finger. A press on the track away from the thumb still behaves as UIKit
  does, and vertical drags that start on a slider in a scrollable still scroll.
- Tab bar in the vertical bar. From iOS 27.1 UIKit can move tab bars into a
  vertical bar at the screen edge, as in the iPhone Duo simulator. The system
  bar embedded in the platform view then showed only the selected tab, and the
  other tabs could not be reached. The embedded `UITabBarController` cannot opt
  out itself; the host view controller's `preferredVerticalBarBehavior`
  decides. The native bar now reads UIKit's `verticalBarEdge` trait (by key, so
  the plugin still compiles with Xcode 26), hides itself and switches every
  `LiquidGlassTabBar` to the Flutter tab bar for the rest of the process. Apps
  whose root view controller returns `.disabled` from
  `preferredVerticalBarBehavior` (iOS 27.1 SDK) keep the system bar. Where
  UIKit reports no vertical bar the tab bar is unchanged.
- Debug explanations. A control whose mode resolves to native but which draws
  its Flutter rendering prints the reason once per process with `debugPrint`:
  a `loading` button; a button, button group or segmented control at a large
  text size; a navigation bar with more than one leading or trailing action, a
  long press, an icon without an `sfSymbol` or large text; and a tab bar in the
  vertical bar. Release builds and the fallback and opaque modes print nothing.
- Documentation. The navigation bar keeps disabled actions native, and apps
  that use the standalone `material_ui` package need its compatibility bridge.
  The README describes the CI matrix and the iPad and vertical-bar behaviour.
- CI. The Swift Package Manager build uses Xcode 27.1 (`xcode-27` image), so
  the native code compiles against both the iOS 26 and the iOS 27 SDK. The
  native interaction job also runs on an iOS 27.0 iPhone 17 Pro simulator with
  Xcode 27.1, next to the existing Xcode 26.6 / iOS 26 run. The pinned 3.41.9
  CocoaPods build and the release artifacts are unchanged.

## Validation

The source passed `dart format`, analysis and 358 package tests (7 more than
0.6.0: 1 for the slider's grab point, 4 for the debug explanations and 2 for
the vertical-bar switch). The example's Dart code did not change since 0.6.0.
`pod install` for the example passed.

Simulator checks used Flutter 3.41.9 and Xcode 27.1, on one clean build of the
final source with the default example configuration:

- iOS 27.0, iPhone 17 Pro: the CI native UI suite (`NativeAccessibilityUITests`
  and `NativeSliderUITests`) ran 17 tests with no failures and no skipped
  palette case. Light and dark screenshots of the catalog, the material,
  new-controls, native controls, layout, RTL and mixed-modal configurations
  show the horizontal native tab bar and the separate prominent search button
  as before.
- iOS 27.1, iPhone Duo: UIKit reports `verticalBarEdge` trailing for the
  catalog's tab bar (phone idiom, compact width, `mode` `.tabBar`, sidebar
  hidden, 466 × 678-point window). With this release the catalog shows the
  Flutter tab bar with all four tabs in light and dark, and a temporary UI test
  tapped every tab and reached its page. Returning `.disabled` from the host view
  controller's `preferredVerticalBarBehavior` instead restored the horizontal
  system tab bar.
- iOS 27.0, iPad Pro 11-inch (M5), portrait: UIKit draws the iPad's floating
  bar of text tabs with every tab shown; `verticalBarEdge` does not exist on
  iOS 27.0, so the change does not apply.
- iOS 18.6, iPhone 16: the catalog reports the fallback renderer and exposes no
  system tab bar; a temporary UI test opened the Pickers, Popups and Search
  pages in light and dark. The example's `integration_test` suite passed (3 tests).

The `material_ui` compatibility bridge was checked with a widget test on
Flutter 3.47.8 and `material_ui` 1.8.0.

CI runs for this release are listed under
[Component checks on fix/0.6.1](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/workflows/ci.yml?query=branch%3Afix%2F0.6.1);
the gating run for the tagged commit, including both native interaction runs,
is linked from the GitHub release.

## Known validation limits

Physical devices were not checked: the slider drag, the iPhone Duo tab bar,
haptics, VoiceOver and rendering performance still need acceptance on
hardware. iOS 26 was covered by CI only, and iPad, landscape and Split View
only by the single check above. The first-use system colour-palette failure in
some hosted iOS 26.5 runs remains unresolved; this release does not touch that
path.

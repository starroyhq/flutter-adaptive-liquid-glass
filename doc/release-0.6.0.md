# flutter_adaptive_liquid_glass 0.6.0

This release removes the upstream `native_liquid_glass` dependency, so the
Flutter SDK is the package's only production dependency and apps no longer pull
in its pods and packages (SVGKit, CocoaLumberjack, `flutter_svg`, `path_parsing`
and others). The plugin now supports Swift Package Manager as well as CocoaPods
and ships a `PrivacyInfo.xcprivacy`. The native tab bar, segmented control and
icon-only buttons are package-owned UIKit bridges, and a series of native fixes
make controls update in place, follow Flutter's `Directionality`, refuse stale
choices and find their host view controller under the UIScene life cycle.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.6.0
```

Flutter 3.41.2+, Dart 3.11+, iOS 16+ and Android remain supported; native glass
requires iOS 26+ and Xcode 26+.

## Upgrading

1. Change the constraint to `^0.6.0`. In a 0.x version `^0.5.x` does not select
   0.6.0 automatically.
2. Run `flutter pub get`.
3. Perform a full native rebuild, so the removed `native_liquid_glass` pods and
   packages leave the app (for CocoaPods, `pod install` runs as part of the
   build).
4. With Swift Package Manager, set the app's iOS Deployment Target to 16.0 or
   later. `flutter create` sets 15.0, and Xcode then reports that the package
   product requires minimum platform version 16.0.

Existing APIs remain available and need no code changes.

## Visible changes

- Tab icons given only as `IconData`. On iOS 26 such a tab icon is drawn at the
  screen's pixel ratio and at about the size of the bar's SF Symbols. Before, its
  bitmap was shown at a scale of 1 and covered the selected tab's capsule.
- Icon-only buttons with a long press. A native icon-only button with a long
  press now looks like one without: a semibold symbol centred on its ink, or the
  trimmed Material glyph, in colours that do not change when pressed or
  disabled. This includes the default trigger of an icon-only
  `LiquidGlassMenuButton`, which opens on a long press by default.
- Right-to-left layout. Native buttons, button groups, toolbars, action bars,
  the navigation bar's capsules, the tab bar and the segmented control follow
  Flutter's `Directionality` instead of the device language. Right to left, a
  button's icon is to the right of its title, the first action, tab and segment
  are on the right, and semantic symbols such as `arrow.backward` and
  `chevron.backward` take their right-to-left form. Indexes stay in logical
  order, as in the fallback.
- Disabled navigation bar actions. A native `LiquidGlassNavigationBar` keeps the
  system `UINavigationBar` when one of its actions is disabled and updates that
  action in place. Before, a disabled action switched the whole bar to the
  Flutter title layout.
- Home indicator. With `native_liquid_glass` removed, the iOS home indicator
  follows the system default and can appear where it stayed hidden before. The
  package does not control it. An app that wants iOS to hide it automatically
  can call
  `SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top])`;
  on Android the same call also hides the navigation bar.
- Native icon-only buttons apply `iconColor`, `iconSize` and `menuIndicator`, as
  the fallback already did, and use `id` and `semanticLabel` as their native
  accessibility identifier and label.
- The native segmented control is as wide as the space it is given, without the
  previous 32-point widening.
- Fallback controls show a light highlight under a hovering mouse pointer; the
  cursor stays Flutter's default.

## Behaviour fixes

- In-place updates. Native buttons, and each action of a button group, toolbar,
  action bar or grouped navigation bar capsule, update their native view in
  place when they are enabled or disabled or their emphasis or colours change.
  A press UIKit reported before the change is still rejected. New titles, icons,
  long-press actions, text direction or added, removed and reordered actions
  still create a new view.
- Segmented control rollback. The native `LiquidGlassSegmentedControl` returns
  to its selected segment on the next frame when the parent does not adopt a
  choice, as the tab bar already did; so does a disabled one.
- Host view controller under UIScene. The native tab bar's
  `UITabBarController` becomes a child of the view controller that shows the
  bar, found through the responder chain once the bar is in a window, instead of
  the registrar's view controller, which can be nil when an implicit engine
  registers plugins.
- Apps that also depend on `native_liquid_glass` no longer share its platform
  views or lifecycle channel with this package.

## New and deprecated API

New:

- `LiquidGlassTheme.maybeOf` returns null when there is no `LiquidGlassTheme`
  above the context.
- `showLiquidGlassPopover` accepts a `barrierColor`; the default scrim stays 8%
  black.
- `LiquidGlassColorPicker` accepts `hexLabelText`, `hexErrorText` and
  `channelSemanticFormatterCallback` to replace the English text of its fallback
  sheet. The defaults are unchanged.

Deprecated:

- The `disableAnimations` argument of `LiquidGlassThemeData.resolve`. It never
  affected the result.

## Validation

The source passed `dart format`, analysis of the package and the example, 351
package tests and 11 example tests on Flutter 3.41.9, and
`flutter pub publish --dry-run` with 0 warnings. The `Component checks` run for
the last code commit passed every job, including analysis and tests on the
current stable channel, the Android build, the iOS simulator builds with
CocoaPods and with Swift Package Manager, and the native iOS 26 interaction job:
<https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/39565239553>.
The gating run for the tagged commit is linked from the GitHub release.

On an iPhone 17 Pro simulator with iOS 26.5, screenshots in light and dark
appearance were compared with the previous build: the catalog's tab bar,
segmented control and standalone buttons match outside the status bar and
activity indicator; tab bitmap icons now fit the bar; icon-only buttons with and
without a long press have identical frames and ink; right-to-left capsules, tab
bar and segmented control are mirrored as described above. XCUITest covers
in-place updates of standalone buttons and of a button group's actions, with
stale presses rejected; the segmented control restoring a refused choice; menus,
alerts and sheets hiding native controls beneath them and restoring them after
closing; the long press of a standalone icon button; and right-to-left tab and
segment order and taps. Under the UIScene life cycle the tab bar attached to its
host view controller on every launch checked, and followed a live appearance
change.

Still requiring acceptance on a physical device:

- VoiceOver touch exploration and activation of native controls inside a sheet.
  XCUITest does not report them as hittable, apparently because Flutter's
  full-screen barrier node is ordered after the sheet; taps at their position
  work.
- Haptic and sound feedback.
- Hiding the home indicator through `SystemChrome` as described above.
- Hardware rendering and performance, iPad, landscape and large text.

## Known limitations

- In simulator UI tests a slow drag on the native slider can end about 20 points
  behind the finger. Flutter's drag gesture hands the touch to UIKit only after
  it passes the touch slop, and that movement is lost. This has not yet been
  confirmed on a device; a later release is planned to fix it.
- The independent first-use system colour-palette failure recorded for 0.2.1
  remains unresolved in some hosted iOS 26.5 runs; the CI gate keeps skipping
  only a first palette that does not appear.
- Building the bundled example with Swift Package Manager needs a checkout
  directory named `flutter_adaptive_liquid_glass`. Apps that depend on the
  package from pub.dev or by path are not affected.

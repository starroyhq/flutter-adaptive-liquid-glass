# Fallback validation — 2026-10-10

Environment: Flutter 3.41.9 / Dart 3.11.5, Android API 35 emulator,
iOS 18.6 and iOS 27.0 dedicated test simulators.

## Automated checks

- `flutter analyze`: no issues.
- `flutter test --reporter expanded`: 71 passed (including custom colors and route coverage).
- Example static analysis and two widget tests: passed.
- Root and example `flutter pub get --enforce-lockfile`: passed.
- Example `flutter build apk --debug`: passed.
- iOS simulator arm64 Xcode build with `--config-only` and `pod install --deployment`: passed.
- GitHub CI for source commit `0dbd9cc99b86a8abdbb963700d8c335ae53f34df`: all three jobs passed.
  [Run 38035711296](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38035711296)
  includes quality, Android APK and iOS arm64 simulator builds. The two example
  artifacts are retained for 14 days.

Tests cover shared selection travel, interrupted/reversed travel, RTL, larger
text, resizing, enabled/disabled semantics, system/application reduced motion,
theme changes, shared action hit regions and constrained full-width buttons.
Pixel tests cover material clipping and backdrop visibility; 32 contrasting
background/foreground combinations use the actual selection widget and reach
at least 4.5:1 text contrast in neutral and default Material 3 palettes. Arbitrary
custom tints and custom foreground colors require their own contrast checks.

The color tests cover partial overrides, seed-generated light/dark palettes,
local `copyWith` scope, explicit surface tint precedence and resetting to default
colors. Default → custom light → custom dark → default transitions retain the
selected values and the internal state/controller/draft of a TextField with no
caller-provided controller, without firing selection callbacks.

## Simulator observations

- Android: light/dark system appearance, shared toolbar capsule, tab and segment
  selection callbacks, and options sheet.
- iOS 18.6: light/dark material, tab/segment selection, options sheet,
  composer rises above the keyboard, tabs hide and return after dismissal.
- iOS 27.0: native main-page surfaces and tab bar remain present in light/dark
  appearances; native toolbar actions open the settings sheet. Native source
  files were not changed by this iteration.

Custom-color follow-up: iOS 18.6 displayed the Green palette in light and dark
appearance while retaining the selected Account tab. iOS 27.0 displayed the Blue
palette in dark appearance, including the prominent native button, native
surfaces and system tab bar. The new Dart adapters pass supported native color
parameters; UIKit still owns selection material, outlines and shadows. The
existing Swift implementation was not changed.

## Native mixed-modal fix

The regression was reproduced in an iOS 27.0 simulator: a sheet above native
controls lost Flutter text, draft content and switches between platform views;
its native surface was also clipped. The same panel rendered correctly on its
own. Disabling individual controls restored adjacent Flutter regions. Adding
RepaintBoundary around the platform views did not help. Removing the covered
background from composition restored all content.

The fix excludes covered native subtrees from Flutter painting, rather than
only hiding their UIKit views. Layout and widget state are retained. Coverage
holds until `TransitionRoute.completed`, so closing a nested overlay does not
restore the previous layer before the exit animation completes. Native surface
backgrounds and their Flutter children are handled separately.

The independent `GLASS_MODAL_PROBE` verified a sheet containing native segments,
a UIKit capsule, a native surface and interleaved Flutter text/inputs/switches;
a dialog nested within it; Blue/Green and light/dark changes; preserved segment
selection and tap count on return; and restoration of the root native tabs.
The settings-sheet forced-fallback workaround has been removed.
Automated lifecycle tests cover delayed exits, nested overlays, rapid pop/push,
route replacement/removal, observer disposal, and retained state/layout without
paint, hit testing or semantics on covered routes. These tests do not substitute
for simulator composition observations.

## Native glass under the package's popups
Checked in the iOS 27.0 simulator with Flutter 3.41.9, on a page shaped like a
list screen: a standalone "+" icon button, a segmented control, a text
button, a tab bar with a search tab, and Flutter rows. iOS 26 was not run
locally; the CI native-interaction matrix covers it.

Composition rule. Flutter's iOS embedder (`flow/view_slicer.cc`, and
`bringLayersIntoView` in `FlutterPlatformViewsController.mm`) cuts the frame
into slices, one after each platform view. Slice k gets an overlay layer for
the bounds of its intersections with platform views 0 to k; the rest of the
slice goes to the background layer, which is cut by every earlier overlay
rectangle. A popup's barrier is painted after the page's last platform view
and covers all of them, so its slice's overlay spans nearly the whole screen.
Flutter content painted in a later slice that is over no platform view, but
inside that rectangle, is therefore not drawn. The rule that follows: once the
page's native views stay, every Flutter pixel painted after the popup's first
platform view must lie on a platform view.

Observations with the page's native views kept (before the fix, by patching
out every hiding path in an experiment checkout of 0.6.1):

- The package's popover, alert and fit-content sheet, with only Flutter
  content, or with native switches and Flutter text after them, rendered
  completely: their content is clipped to their own native surface.
- A `showModalBottomSheet` with a white Flutter surface and native switches
  lost the Flutter text, the draft, the label and the Material switch after
  its first native switch; this is the regression the mixed-modal fix above
  addressed. Over a page without native views it rendered completely.
- A Flutter-drawn text selection toolbar of a field in a sheet or an alert
  lost the parts outside the popup's surface (its rounded ends, and about 11
  points on the left in the sheet). A field's default toolbar on iOS is the
  system menu, a UIKit view, which is not affected.
- A `Tooltip` below a popover stayed complete, but only because it lay over
  the tab bar's platform view.
- An app toast in its own `OverlayEntry`, above a popover and over the page's
  "+" button, lost its rounded ends where the button's native view is.

Behaviour of the fix, observed in the same simulator:

- The package's popover, alert and sheets leave the page's native glass on
  screen under the barrier, and close without a frame that lacks it.
- A `showModalBottomSheet` isolates the page as before; the page's controls
  show their Flutter rendering under the barrier instead of leaving gaps. A
  frame-by-frame look at a screen recording of opening and closing it found no
  frame without the "+" button. Before the UIKit fade-out was delayed, a slow
  first frame in a debug build left about 0.1 s without it on opening, and the
  returning native view, fading in over the Flutter rendering, made the
  control look washed out for about 0.25 s on closing.
- Focusing a field in a sheet isolates the page, and the Flutter toolbar is
  complete. The guarded toast is complete; the unguarded one loses its rounded
  ends, as documented.
- Tapping where a page control is while a package popup is open only closes
  the popup, and XCUITest does not find the page's controls, in
  `testPopupsKeepNativeControlsBeneathThemOutOfReach`.
- `GLASS_MODAL_PROBE` still renders its Material sheet and dialog completely.

These observations depend on the embedder's slicing, an implementation detail;
rerun them after a Flutter upgrade.

## Build detail and limits

`flutter build ios --simulator --debug` failed while checking the combined
`arm64 x86_64` architecture value in this toolchain. With the generated Flutter
configuration in place, this command from `example/ios` succeeded:

```sh
xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination "id=$SIMULATOR_ID" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

Set `SIMULATOR_ID` to the ID of a local test simulator before running the command. No project
architecture settings or global toolchain versions were changed.

Physical-device GPU/scrolling performance, full input-method composition and
VoiceOver/TalkBack journeys have not been revalidated in this iteration. Widget
and pixel tests do not establish frame-rate or native-glass fidelity. This
fallback uses blur, protective fill and highlights, without a refraction shader.

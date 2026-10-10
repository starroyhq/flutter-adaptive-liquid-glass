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
- GitHub CI has been configured; its first remote run is pending at this commit.

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

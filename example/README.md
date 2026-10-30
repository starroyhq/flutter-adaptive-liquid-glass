# flutter_adaptive_liquid_glass_example

Standalone iOS/Android showcase for `flutter_adaptive_liquid_glass`. Its dependency
uses `path: ../`, resolving to the surrounding package checkout. This example
demonstrates the **0.7.0** component catalog. Applications can use the hosted
`flutter_adaptive_liquid_glass: ^0.7.0` dependency; the example deliberately keeps
its local path so it tests the same source checkout. See the
[upgrade notes](../README.md#upgrading-from-02x) when moving from 0.2.x.

Development and the pinned CI jobs use Flutter 3.41.9 / Dart 3.11.5; CI also
builds this example on the current stable channel with Swift Package Manager.
Use the committed lockfiles with the pinned toolchain. The package's only
production dependency is the Flutter SDK, so the example installs no
third-party pods or Swift packages besides Flutter's own `integration_test`.

From the package root:

```sh
cd example
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <device-id>
```

To build the example with Swift Package Manager (the default from Flutter
3.44), name the checkout directory `flutter_adaptive_liquid_glass`, for example
`git clone https://github.com/starroyhq/flutter-adaptive-liquid-glass flutter_adaptive_liquid_glass`.
Flutter adds the plugin's Swift package to this project as a local override,
and the two package identities must match; CI checks out the repository the
same way.

## Component catalog

The default entry point is `ComponentCatalogApp`.

| Page | Examples |
| --- | --- |
| Controls | Surfaces, text/icon buttons, grouped toolbar, segments, activity/progress, slider, switch and stepper |
| Pickers | Date/time modes and compact/inline/wheel styles, color well with alpha |
| Popups | Three independent menus, alert/action sheet, mixed-content sheet, anchored popover and nested presentations |
| Search | Flutter search editing and a controlled search scaffold with retained page state |

The **Appearance** action changes System/Light/Dark, the optional custom teal
palette, rendering mode, reduced motion and reduced transparency. Palette changes
are independent of appearance. On iOS 26+, tabs remain native even when selecting
fallback or opaque rendering; use older iOS or Android to inspect fallback tabs.
The catalog includes localization delegates for English, simplified/traditional
Chinese, Japanese and Arabic; explanatory sample text remains English.

The [component coverage matrix](../doc/component-coverage.md) maps all 21
capabilities to implementations and regression sources. Actual execution results
belong in the [component validation record](../doc/component-validation.md) and
[interaction validation record](../doc/interaction-validation.md).
The checks below are acceptance steps, not a claim that every check has passed.

1. Change slider, switch, stepper and segment values; change appearance, palette
   and rendering mode, then return to the page. Confirm controlled values remain
   accepted by the app. Exercise disabled controls, range ends and stepper hold.
2. Inspect date modes/styles. The catalog uses the default minute interval and
   unbounded dates; bounds and other minute intervals are covered by picker tests
   and can be supplied when adapting the example. Open the color well;
   change RGB and alpha, enter valid and invalid HEX, and return to the page.
   Verify state after light/dark changes and reopening.
3. Open each of the three menus, visit nested items, use Back rapidly, select a
   leaf or dismiss. Only the initiating menu should receive a result. Check its
   disabled item, then try alert/action-sheet confirmation, deletion and cancel.
4. Open **Mixed sheet**, type Chinese/Japanese and emoji into the Flutter field,
   change values, then open **Nest sheet** and the nested popover. Close layers
   individually. Text, selection and focus must belong to the visible layer;
   drafts must survive returning to a previous layer. The root tabs must return
   after the final exit animation, with no native view bleeding through a popup.
5. Drag a sheet between its medium and large detents, scroll its list, dismiss it
   from the top, and repeat while the keyboard is visible. Resize/rotate while a
   popover is open and check its position, safe area and available height.
6. Enter a composing IME draft in Search; clear, cancel, submit, switch pages and
   reopen search. Clear empties the draft; cancel retains it. Verify keyboard
   dismissal and system back behavior, then background and restore the app.
7. Repeat in light/dark and custom colors, with large text, right-to-left layout,
   reduced motion and reduced transparency. Inspect labels, focus order and hit
   areas with the platform's accessibility tools. On iOS 26+, also inspect the
   actual native material during scrolling and popup transitions.

The [custom color API](../README.md#custom-colors) supports partial tokens,
`fromColorScheme` and local `copyWith` overrides. Colors are not a fixed palette
and arbitrary custom colors do not carry a contrast guarantee. Native UIKit
materials retain their own fills, rims and shadows. The Flutter fallback uses
bounded blur and a protective fill; it does not implement a refraction shader.

When copying the mixed-sheet example, keep `primary: true` on its primary
vertical `ListView`, or use `PrimaryScrollController.of(sheetContext)`. The
sheet supplies that controller to coordinate scrolling and detent dragging.
A separately owned controller does not participate in that coordination.

Dates display local calendar values even when the input is UTC, while callbacks
retain the input's UTC/local representation. Date-only edits preserve the local
time; time-only edits preserve the local date. Time modes clear seconds and use
the supported minute grid; bounds snap inward to selectable values. This is not
a named-time-zone scheduler. Color changes are continuous sRGB edits, not a
transaction committed on close. Fallback HEX uses `RRGGBB` or `RRGGBBAA` with
optional `#`; alpha is last.

## Automated checks

From `example/`:

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test
flutter test --no-pub integration_test/components_test.dart -d <device-id>
```

The first integration scenario opens a mixed-content sheet, enters a Unicode draft,
opens and closes a nested sheet, verifies the preserved draft and returns to the
root tab bar. It exercises the compiled application with native views present on
an applicable runtime. Its Flutter assertions do not prove that every native
control was drawn correctly or that every UIKit gesture worked; inspect actual
composition and native interactions separately.

The second forces fallback and exercises slider, switch and stepper gestures,
search submission/clear/theme changes, and a color editor round trip. It uses
the Flutter SDK's synthetic text-input channel consistently; this avoids a
Flutter 3.41 driver connection-cache issue after submission and does not claim
system keyboard or IME acceptance.

The third forces fallback and verifies tap/long-press exclusivity, two independent
menu triggers followed by reopening, stepper hold/release and actual date-wheel
scrolling. It also runs in the example Widget suite. The latest interaction
results and remaining hardware checks are recorded in
[interaction validation](../doc/interaction-validation.md).

The configured CI runs root/example unit and widget tests and builds Android
and iOS simulator applications. It formats/analyzes integration-test source but
does not currently run this device scenario. See the validation records above
for the checks actually executed on a particular source revision.

A simulator can validate application flow, layout and native integration on its
installed runtime. It cannot establish physical-device GPU/frame performance,
power usage, high-refresh behavior, full hardware keyboard/IME behavior or
complete VoiceOver/TalkBack acceptance. Record those physical-device checks
separately; an iOS 26+ simulator result is not an iOS hardware result. Broader
local checks used iOS 27; the dedicated CI gate uses actual iOS 26 for the native
slider scenario below. See [release validation](../doc/release-validation.md)
for the normal-duration slider result and the remaining platform coverage.

## Original material probe

```sh
flutter run -d <device-id> --dart-define=GLASS_MATERIAL_PROBE=true
```

This starts `GlassExample`, the original reading-content/material showcase.
The toolbar, segmented control, floating Flutter composer and bottom tabs sit
over a neutral canvas. Adjacent toolbar actions share one capsule. Scroll text
and solid code blocks behind them to inspect material boundaries and legibility.

The sliders action opens appearance/accessibility settings and the original
Neutral/Blue/Green demonstration palettes. Compare light and dark independently
of color, inspect rapid shared-capsule retargeting, then test reduced motion and
reduced transparency separately. Enter Chinese, Japanese and emoji into the
composer and confirm it rises above the keyboard. Tabs hide while editing and
return after keyboard dismissal.

## Native controls probe

```sh
flutter run -d <device-id> --dart-define=GLASS_NATIVE_CONTROLS_PROBE=true
```

This starts `NativeControlsProbeApp`, a fixed page for comparing screenshots and
for UI tests; the catalog's Search page opens the same page with **Open native
controls probe**. It holds four standalone icon buttons without long-press
actions: `probe-add` (an SF Symbol), `probe-close` (a Material glyph only),
`probe-up` (prominent) and the disabled `probe-disabled`. Below them are an
enabled segmented control, a disabled one and the native tab bar with a dot
badge on Beta, Material glyphs for Gamma and a trailing **Find** button. Text
counters show the icon presses, the selected segment and tab, and the Find
presses. The title bar is a Flutter `AppBar` and nothing animates, so two
renderings differ only in these native controls. This flag takes precedence over
the other probe flags.

At the bottom of the page, below the compared controls, are a prominent
`probe-send` text button and two toggles: **Toggle Delete** enables
`probe-disabled`, and **Toggle Move up** disables both `probe-up` and
`probe-send`, so UI tests can change enabled states in place. A **Public** /
**Locked** segmented control follows; the page refuses **Locked** without
rebuilding, and counts the attempts.

## Native layout probe

```sh
flutter run -d <device-id> --dart-define=GLASS_NATIVE_LAYOUT_PROBE=true
```

This starts `NativeLayoutProbeApp`; the catalog's Search page opens the same
page with **Open native layout probe**. Its first row is laid out and themed
like the native controls probe's first row: a plus and a trash icon button, each
without and then with a long press (`layout-plus-tap`, `layout-plus-hold`,
`layout-trash-tap`, `layout-trash-hold`), with tap and hold counters. Below are
a segmented control, triggers for a menu, an alert and a sheet with native
buttons (`layout-alert`, `layout-sheet`), the last popup's result, a
right-to-left region with a titled icon button, a mirrored Material glyph, an
SF Symbol arrow and a three-action button group, and a native tab bar. Only
`GLASS_NATIVE_CONTROLS_PROBE` takes precedence over this flag.

## Native RTL probe

```sh
flutter run -d <device-id> --dart-define=GLASS_NATIVE_RTL_PROBE=true
```

This starts `NativeRtlProbeApp`, a right-to-left page; the catalog's Search page
opens the same page with **Open native RTL probe**. It holds standalone SF Symbol
icon buttons (`arrow.backward` and `arrow.forward`, which turn with the
direction, and `arrow.left` and `star`, which do not), titled buttons with
`chevron.backward` and `chevron.forward`, a **Day** / **Week** / **Month**
segmented control, a **Copy** / **Paste** / **Cut** button group whose Paste
action **Toggle Paste** enables and disables in place, and the native tab bar
with Alpha, Beta, Gamma (Material glyphs, unselected at first) and a trailing
**Find** button. The first segment and tab are at the right and Find at the
left; counters show the selected segment and tab and the presses. The controls
and layout probe flags take precedence over this flag.

## Original mixed native/Flutter modal probe

```sh
flutter run -d <device-id> --dart-define=GLASS_MODAL_PROBE=true
```

This starts `NativeModalExample`. Open Dialog and Bottom Sheet, nest them, and
close them in order. Each layer interleaves Flutter text, an editable draft,
a switch, native segments, a shared capsule and a native surface. Use its three
native toggles to isolate a control; compile-time defaults can also be set with
`GLASS_MODAL_SEGMENT`, `GLASS_MODAL_CAPSULE` and `GLASS_MODAL_SURFACE`. These flags
do not change the native-tab policy. `GLASS_MODAL_PROBE` takes precedence if both
probe entry-point flags are set.

Verify all content stays visible, callbacks target only the front layer, values
survive returning to a previous layer and root tabs return after popup exit.
Repeat with light/dark and Blue/Green. An iOS 26+ runtime is required to inspect
native composition; widget tests alone validate only Dart behavior. The earlier
release's [fallback validation record](../doc/fallback-validation.md) remains
historical evidence, separate from the 0.2.0 execution records.

## Owned fallback and feedback checks

In Controls, tap and hold Action, Add and Hold only; inspect separate action and
long-press counters. Hold either action in the shared Undo/Redo capsule and verify
that releasing does not increment the click counter. In Appearance, independently
toggle Package haptics and Package system sounds. Native controls and the inline
calendar retain system feedback; these toggles do not override it.

The fallback slider, switch, stepper buttons, date wheels and activity indicator
are package-owned. Date wheels reuse SDK locale resources rather than Cupertino
control widgets. Both feedback permissions default to enabled; disabling one
does not disable the other or change reduced-motion settings.

In Popups, hold First menu, choose or cancel, then tap and hold the other triggers.
The default menu trigger accepts both gestures; choose `LiquidGlassMenuTrigger.tap`
or `.longPress` to test an explicit single-gesture policy.
There must be one popup and one result per gesture. In Pickers, select wheels and
exercise month ends, localized 12/24-hour time, external resets and keyboard focus.
The Controls spinner must stop when motion is reduced or the app backgrounds.

The device suite also performs fallback long presses, silent stepper repetition
and actual month-wheel scrolling. Physical vibration, audibility and VoiceOver /
TalkBack require separate hardware acceptance.

## Native slider acceptance

`NativeSliderAcceptance` is a separate Xcode UI-test scheme. It launches the
default catalog, verifies that its renderer is native, then uses Apple's public
[press, drag and hold API](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press%28forduration%3Athendragto%3Awithvelocity%3Athenholdforduration%3A%29)
to send normal-duration system input. It does not use Flutter's synthetic pointer
channel or modify the production slider's event handling.

Each drag holds the thumb for 0.2 seconds, moves at the SDK's `.slow` velocity,
then holds its destination for 0.2 seconds. Four consecutive drags alternate
between 0.8 and 0.2 from an initial 0.4. Every drag must increment Flutter's start
and end counters exactly once, reach the requested detent within 0.051, and
report the same final value through `onChangeEnd`. Two subsequent stationary
thumb presses must each produce one start/end pair without changing the value.
The fixture waits for the
slider's frame to stop moving after revealing it; XCTest's normal idle detection
does not observe Flutter scroll tickers. Screenshots and the initial native
accessibility hierarchy are retained in the `.xcresult` bundle.

Use an explicitly selected, dedicated iOS 26+ simulator. The UI-test target has
an iOS 26 minimum; the example application's minimum remains iOS 16. From this
example directory:

```sh
flutter build ios --simulator --debug --config-only --no-pub
cd ios
pod install --deployment
GLASS_SIMULATOR_ID='<dedicated-simulator-uuid>'
xcodebuild -workspace Runner.xcworkspace -scheme NativeSliderAcceptance \
  -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$GLASS_SIMULATOR_ID" \
  -derivedDataPath ../build/ios-parity \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -collect-test-diagnostics never \
  -resultBundlePath ../build/native-slider-acceptance.xcresult \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test
```

Use a new result-bundle path when repeating the command: Xcode does not overwrite
an existing `.xcresult`. Parallel testing is disabled to avoid simulator clones.
An iOS 27 result verifies that runtime only; iOS 26 compatibility and physical
device behavior require their own executions. See the current
[release validation record](../doc/release-validation.md) for completed checks.

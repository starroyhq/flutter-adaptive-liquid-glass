# Owned fallback and interaction validation

This is an unpublished 0.2.0 follow-up to source checkpoint `8524992`. It changes
only the component package and its example. It does not publish a package,
change a consuming application or claim a new remote CI result.

## Implementation

- Slider and switch use package drawing, gestures, focus and semantics. Stepper
  uses package press targets inside the existing shared capsule. Color-channel
  sliders use the same implementation with integer values and endpoint feedback.
- Date wheels use `ListWheelScrollView` and per-column controllers. Only SDK
  localization data is reused; no Cupertino widget or theme is instantiated.
  Material inline calendars and Flutter text editing remain in use.
- The activity indicator paints its own spokes and stops its ticker when hidden,
  paused, covered, backgrounded or under reduced motion.
- `LiquidGlassThemeData.feedback` independently permits package haptic and system
  sound requests. Normal iOS clicks add neither; Android clicks request a system
  click. Long presses confirm once, discrete selection changes request haptics,
  continuous sliders signal endpoints, and date wheels also request the iOS tick.
  Stepper repetition is silent after its initial long-press confirmation.
- Buttons, icons, grouped actions and navigation actions support optional long
  press, including long-only actions. Menus default to tap and long press. UIKit
  capsules own one recognizer per action, and Dart rejects stale bridge events.

The feedback switches govern package requests, not the feedback produced by
native system controls or the retained Material calendar. No audio resources,
private sound identifiers or production dependencies were added. SDK
`flutter_localizations` was added only to the package's development dependencies
for real locale tests. The existing material, colors and native tab behavior
remain in place.

## Regression and independent review

Tests cover tap/hold exclusivity, independent adjacent actions, long-only and
disabled/loading controls, stale native events, menu trigger policies, feedback
type/count and independent permissions, slider reset/cancel, controlled switch
rejection, silent stepper repetition and lifecycle cancellation. They also cover
RTL, large text, focus, semantics, custom colors and reduced motion/transparency.

Date cases cover leap years, month-end correction, bounds, minute grids,
UTC/local output, locale ordering and 12/24-hour choice, real wheel scrolling,
external reset and stale keyboard/semantic callbacks. The picker suites were
run under both `America/New_York` and `Australia/Lord_Howe` to exercise full-hour
and half-hour daylight-saving transitions.

Independent review found and fixed these concrete cases:

- A second pointer could revive a long press cancelled by leaving its target.
- An accepted slider value echo could be confused with an external reset.
- Stepper automatic repetition and continuous keyboard slider edits could send
  excessive selection feedback.
- A half-hour DST jump combined with a 20-minute interval could produce a value
  outside the minute grid. Rounding now searches actual minutes for the next
  valid local wall-clock minute, preserving repeated-hour occurrences.
- A queued date-wheel keyboard/semantic action could move its controller after
  backgrounding or route coverage even though the business callback was rejected.
- Android device integration exposed a missing terminal pointer event when a
  long press presented a menu. Interruption now retires the old pointer batch
  and recognizers, rejects obsolete callbacks and permits a new gesture. Ordinary
  pointer-exit cancellation remains latched until all pointers in that batch end.
- Rebuilding recognizers discarded keyboard focus. A stable focus node and a
  guarded, enabled default menu trigger now preserve focus across presentation;
  selecting and closing a menu allows it to reopen from Enter without refocusing.

## Device interaction observations

### Automated checks

Environment: Flutter 3.41.9, Dart 3.11.5, upstream 0.3.1, Xcode 27.0. Commands
below were run against this follow-up; device IDs and host paths are intentionally
not included in the public record.

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test` | Passed; 60 files unchanged. |
| `flutter analyze --no-pub` in root and example | Passed; no issues in either. |
| `flutter test --no-pub --reporter expanded` in root | 213 passed. |
| Same test command in example | 6 passed. |
| `flutter test --no-pub test/pickers_test.dart test/fallback_date_wheels_test.dart` | 32 passed in the local, New York and Lord Howe time zones. |
| `flutter test integration_test/components_test.dart -d <dedicated-device-id> --no-pub --reporter expanded` | Android 15 / API 35: 3 passed. |
| Same device command on iOS 18.6 | 3 passed. |
| Same device command on iOS 27.0 | 3 passed. |
| `git diff --check` | Passed. |

The Android emulator's default host graphics process failed while restarting.
The final run used the dedicated component AVD with software rendering and no
snapshot. This did not change package code or the global toolchain and does
not establish Android GPU performance. Each device suite covers a mixed nested
sheet and Unicode draft, fallback value/search/color editing, then long-press
menus, stepper repetition and a date-wheel gesture. Synthetic text input is not
physical keyboard/IME acceptance.

Final ordinary-example builds also passed (the integration-test entry point was
replaced by `lib/main.dart` before these outputs were generated):

- Android: `flutter build apk --debug --no-pub`, producing
  `example/build/app/outputs/flutter-apk/app-debug.apk`.
- iOS arm64 simulator: `flutter build ios --simulator --debug --config-only
  --no-pub`, `pod install --deployment`, then the existing `xcodebuild` path with
  `ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO`, producing
  `example/build/ios-parity/Build/Products/Debug-iphonesimulator/Runner.app`.

Formatting and source hygiene checks passed; the public-source scan found no
private project references, absolute host paths or credential-shaped strings.
Build files and local diagnostic logs are not added to source control. No
temporary gesture logging remains in production sources.

### Actual simulator input

Actual held input on the dedicated iOS 27 simulator verified a text button, icon
button, both adjacent shared-capsule actions and a long-only button. Five holds
produced five long-press callbacks, with no release click; a separate click
produced exactly one tap. Two separate native menu triggers opened on hold,
returned their own results, and a third trigger remained clickable afterwards.
The native tab bar returned after each menu closed.
The final ordinary build was reinstalled and its native button long press and
same-menu long-press/select/tap/reopen sequence were checked again successfully.

On the dedicated iOS 18.6 simulator, actual fallback input changed the slider
from 0.4 to 0.7 with one start/end pair, toggled the switch, repeated the stepper
and stopped on release, and scrolled the minute wheel to a new returned time.
Light appearance and a dark custom palette rendered the controls while retaining
the selected values. These observations are interaction checks, not frame-time
or physical-device measurements.

## Remaining acceptance boundaries

Simulator feedback channel calls do not establish physical vibration strength,
audibility or VoiceOver/TalkBack experience. Hardware, complete IME experience
and real iOS 26 compatibility remain pending. The installed newer runtime is
iOS 27, not iOS 26.

The previously recorded normal-duration native-slider input acceptance gap in
[the original validation record](component-validation.md#native-slider-acceptance-limitation)
remains open. This follow-up changes fallback sliders and does not claim that
the native slider acceptance gate has passed.

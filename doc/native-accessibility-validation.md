# Native accessibility patch validation

This records the 0.2.1 accessibility patch against 0.2.0. The previous package
archive remains unchanged; registry publication and commit-specific CI results
are tracked separately from these local execution records.

## Scope

- Native navigation buttons announce the supplied action label instead of an SF
  Symbol description. UIKit still owns the navigation bar and its button material.
  Visual configuration updates retain valid pending clicks; action replacement,
  disabling, route coverage and lifecycle changes invalidate stale interactions.
- A labeled native color well exposes its label and the system's localized color
  description. Its accessibility action presents a public UIKit color picker
  with an independent delegate; the physical color-well interaction continues
  to use UIKit's own delegate. Native palette selection remains controlled by
  the caller. Disabled, covered, detached and inactive wells reject activation.
- The fallback color sample exposes an actionable semantics node, in addition
  to its existing physical touch and keyboard input.

## Reproduction and automated evidence

The example's **Open accessibility probe** entry provides a synthetic surface
with business labels, theme changes, programmatic color resets, disabled state
and callback counters. Its example-only platform channel calls the public
`accessibilityActivate()` entry point; it does not synthesize a color change.

`NativeAccessibilityUITests` checks real system touches separately from that
accessibility action. It opens the system palette, selects one native black
swatch, and asserts one callback with opaque black. It then selects white through
the accessibility-opened system palette and checks exactly one additional
callback. Reopening and canceling must not add callbacks. A separate scenario reopens the catalog palette after native
tab recreation. System palette labels may use the device language rather than
the application's locale, so tests identify the supplied palette title and use
localized system action labels.

The existing `NativeSliderAcceptance` scheme includes both the slider and
accessibility XCTest classes. The CI native-interaction job requires an actual
iOS 26 runtime and creates its own simulator; it does not substitute iOS 27.

Local checks on Flutter 3.41.9 / Dart 3.11.5, Xcode 27.0:

| Check | Result |
| --- | --- |
| Root and example format / static analysis | Passed, no issues. |
| `flutter test --no-pub --reporter expanded` | 224 package tests passed. |
| Same test command from `example` | 7 example tests passed. |
| `flutter build apk --debug --no-pub` from `example` | Debug APK built. |
| Arm64 iOS simulator build and `NativeSliderAcceptance` XCTest on dedicated iOS 27.0 | All 4 tests passed: 3 accessibility/color scenarios and the existing 6-operation slider scenario. |
| `git diff --check` and local public-source scan | Passed. |

The iOS command, from `example/ios`, is:

```sh
xcodebuild -workspace Runner.xcworkspace -scheme NativeSliderAcceptance \
  -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=<dedicated-device-id>' \
  -derivedDataPath ../build/ios-ax \
  -resultBundlePath ../build/native-accessibility.xcresult \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -collect-test-diagnostics never \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test
```

The local runtime is iOS 27, not iOS 26. Commit-specific iOS 26 results are
reported by the separate `native-interaction` CI check; a simulator build alone
does not establish interaction success. The tab recreation test does not claim
to cover every preceding date-picker editing sequence in a consuming app.

## iOS 26 release-gate follow-up

Candidate `259404b` did not pass the iOS 26 gate in runs
[38109128019](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38109128019)
and [38109132088](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38109132088).
The palette assertion incorrectly required a navigation bar: the iOS 26 system
palette instead exposes `UIColorPicker` with a plain title and a lowercase
`close` action. The revised check requires that named system container and the
exact supplied title on both versions, preserving selection and callback checks.
All three revised accessibility tests passed locally on iOS 27.

One catalog attempt did not open the palette, while the other did. The slider
also reported the wrong final detent despite matching gesture counts and stable
input coordinates. These are unresolved release gates, not successful checks.
Candidate `e63d025` corrected the palette locator. Run
[38110718367](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38110718367)
passed every job; run
[38110714485](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38110714485)
passed the probe, label and slider tests but still failed the catalog's first
palette opening. Both runs' slider diagnostics contained valid start/change/end
sequences, including late UIKit editing notifications correctly ignored by the
existing state machine. This does not establish the cause of the earlier slider
failure, and its temporary tracing has now been removed for an unchanged strict
regression run.

The next diagnostic run samples public color-well visibility, hit testing and
presentation state in the example only, under an explicit DEBUG launch option.
It does not add gestures, open the picker, retry taps, or change production
controls. No retry or relaxed value/count assertion has been introduced. The
package remains unpublished pending an uninstrumented release-gate run.

## Limits

Simulator accessibility trees and activation tests do not establish the complete
VoiceOver experience on hardware. Real-device focus order, announcements,
gestures, haptics and rendering remain separate acceptance work. These local
validation runs do not modify consuming applications or publish packages.

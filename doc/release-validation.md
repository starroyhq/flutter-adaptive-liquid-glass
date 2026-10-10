# 0.2.0 release validation

This records the release follow-up to implementation checkpoints `8524992` and
`71b9883`. The earlier [component](component-validation.md) and
[interaction](interaction-validation.md) records preserve their original scope;
their unpublished status and open gates describe those checkpoints.

## Local baseline

- Flutter 3.41.9 / Dart 3.11.5; `native_liquid_glass` fixed at 0.3.1.
- Root analysis and 213 tests; example analysis and 6 tests passed.
- The 32 picker regressions passed in the local, New York and Lord Howe time
  zones, including full-hour and half-hour DST boundaries.
- Three Flutter integration scenarios passed on each dedicated Android 15,
  iOS 18.6 and iOS 27 simulator. The Android run used software rendering.
- Ordinary Android Debug APK and arm64 iOS simulator builds passed.

These baseline checks are detailed in the interaction record. Release preparation
adds native XCTest and CI configuration, plus the native slider duplicate-write
fix described below. No consuming application is changed.

## Normal-duration native slider input

The `NativeSliderAcceptance` scheme drives the ordinary component example using
XCTest system input. It explicitly requires the native renderer and finds the
system `Preview level` slider, alongside the example's Flutter value and
start/end labels. It does not use Flutter's synthetic pointer channel.

Each drag begins with a 0.2-second hold, moves with `XCUIGestureVelocity.slow`,
then holds for another 0.2 seconds before release. Four alternating gestures
exercise `0.4 -> 0.8 -> 0.2 -> 0.8 -> 0.2`. Assertions check direction, proximity
to the requested target, exactly one additional start and end per drag, and
equality between the last end callback and the displayed controlled value.

The local iOS 27 run passed. An initial test attempt missed the thumb because
Flutter's list was still settling after the revealing scroll. The test now holds
at the end of that scroll and waits for a stable accessibility frame before
resolving slider coordinates. No production callback debounce, event suppression
or timing heuristic was added.

The first remote iOS 26.5 run exposed a separate bridge bug: after reaching 0.8,
the screenshot showed starts/ends of `2 / 1` and a last end value of 0.8. The
binding setter opened a new gesture before checking whether a proposed value
actually changed. A repeated final binding write could therefore emit an
unmatched start. The bridge now normalizes and deduplicates a binding write
before opening a gesture. An explicit system editing-begin still represents a
legitimate no-change interaction. The target-value and exact-count XCTest
assertions remain intact; a retry must pass them before delivery.

The XCTest scheme is separate from the ordinary `Runner` scheme. Its test runner
requires iOS 26+, while the example application retains its iOS 16 deployment
target. See [the example instructions](../example/README.md) for commands.

This closes the normal-duration iOS 27 slider gate from the earlier checkpoint.
Very short desktop-injected gestures remain a separate runtime/input observation.
Simulator input does not establish the feel of dragging on a physical screen.

## Remote release gates

`Component checks` enforces both dependency lockfiles, formatting, static
analysis and both test suites. Separate jobs build the example Android APK and
arm64 iOS simulator application. The `native-interaction` job additionally:

- Requires an arm64 runner and an installed, available **iOS 26** runtime.
- Creates its own iPhone 17 Pro, verifies its runtime and runs
  `NativeSliderAcceptance` without parallel simulator clones.
- Preserves the XCTest result bundle for 14 days and removes only its own device.
- Fails if no iOS 26 runtime exists; it neither downloads nor substitutes iOS 27.

This file describes the gates, not an unexecuted CI success. The
[workflow runs](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/workflows/ci.yml)
show their commit, runtime summary and results. The
[versioned release](https://github.com/starroyhq/flutter-adaptive-liquid-glass/releases/tag/v0.2.0)
links the successful source run used for delivery.

`Publish release assets` only publishes a prepared draft after matching its
version tag to a successful push/manual CI run's exact commit. It verifies the
artifact archive SHA256 digests and transfers the APK and simulator archive on
the GitHub runner. No local artifact download/re-upload is needed. Source and
archive checks exclude local caches, logs, private references and credentials.

The exact upstream dependency constraint can generate a pub dry-run warning. It
is intentional for this release and is not relaxed to silence validation.

## Remaining physical and broader platform checks

- A complete interactive control sweep on iOS 26 beyond the native slider CI
  scenario; iOS 27 observations do not establish that wider iOS 26 result.
- Physical haptic strength and sound, complete VoiceOver/TalkBack and input-method
  composition/selection behavior.
- Real-device GPU, frame-time, power, memory and release-rendering measurements.
- Store/distribution signing of the example.

Publication does not mark these checks as passed. The package feedback switches
only govern requests made by the package, not feedback generated independently
by native system controls or the retained Material calendar.

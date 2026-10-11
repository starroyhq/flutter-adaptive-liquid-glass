# Native accessibility patch validation

This records the 0.2.1 accessibility patch against 0.2.0. The previous package
archive remains unchanged; registry publication and commit-specific CI results
are tracked separately from these local execution records.

The current candidate uses explicit native presentation ownership. Publication
is blocked by the cloud results recorded below. A temporary diagnostic build
compares first-use presentation on separate simulators; it is not a release.
Local results do not replace the iOS 26 CI gate.

## Scope

- Native navigation buttons announce the supplied action label instead of an SF
  Symbol description. UIKit still owns the navigation bar and its button material.
  Visual configuration updates retain valid pending clicks; action replacement,
  disabling, route coverage and lifecycle changes invalidate stale interactions.
- A labeled native color well exposes its label and the system's localized color
  description. Its physical and accessibility actions share an owned public
  UIKit color-picker presentation with an independent delegate. Unlabeled wells
  retain UIKit's default physical and accessibility interaction. Native palette
  selection remains controlled by the caller. Disabled, covered, detached and
  inactive wells reject activation.
- The platform component owns the presentation session, which retains its color
  picker through asynchronous presentation. Reverse references from the well and
  picker are weak, including the path through an iPad popover's source view.
  Cancellation does not reopen the well until dismissal or controller release is
  confirmed. Removing the platform component leaves a cancellation flag on any
  controller still held by UIKit, so a late appearance closes itself.
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
callback. Reopening and canceling must not add callbacks. A separate scenario
reopens the catalog palette after native tab recreation. Another removes the
source widget immediately after activation, requires no remaining palette and no
callback, then restores it and verifies one physical opening and a callback-free
close. System palette labels may use the device language rather than
the application's locale, so tests identify the supplied palette title and use
localized system action labels.

The existing `NativeSliderAcceptance` scheme includes both the slider and
accessibility XCTest classes: six color/accessibility cases plus one slider case,
for seven in total. The slider case retains four drags and two stationary presses
with strict value and callback-count assertions. The CI native-interaction job
requires an actual iOS 26 runtime and creates its own simulator; it does not
substitute iOS 27.

Local checks on Flutter 3.41.9 / Dart 3.11.5, Xcode 27.0. Package/example checks
were rerun after the ownership follow-up without temporary diagnostics. Final
native reruns are listed separately from earlier candidates' results.

| Check | Result |
| --- | --- |
| Root and example format / static analysis | Passed, no issues. |
| `flutter test --no-pub` | 224 package tests passed. |
| Same test command from `example` | 7 example tests passed. |
| `flutter build apk --debug --no-pub` from `example` | Debug APK built during patch validation. |
| Final uninstrumented arm64 iOS build and XCTest on dedicated iOS 26.5 | All 7 tests passed: 6 color/accessibility cases and 1 slider case. |
| Final uninstrumented arm64 iOS build and XCTest on dedicated iOS 27.0 | All 7 tests passed: 6 color/accessibility cases and 1 slider case. |
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
  -only-testing:RunnerUITests/NativeAccessibilityUITests \
  -only-testing:RunnerUITests/NativeSliderUITests \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test
```

Local coverage now includes iOS 27 and a separately installed iOS 26.5 runtime
(build 23F73), compiled with the installed Xcode 27 SDK. The cloud iOS 26.5
runtime (23F77) and Xcode 26.6 / SDK 26.5 are a separate environment.
Commit-specific cloud iOS 26 results are reported by the separate
`native-interaction` CI check; a simulator build alone
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
input coordinates. These were unresolved release gates at that candidate.
Candidate `e63d025` corrected the palette locator. Run
[38110718367](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38110718367)
passed every job; run
[38110714485](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38110714485)
passed the probe, label and slider tests but still failed the catalog's first
palette opening. Both runs' slider diagnostics contained valid start/change/end
sequences, including late UIKit editing notifications correctly ignored by the
existing state machine. This does not establish the cause of the earlier slider
failure. Temporary slider tracing was then removed before the unchanged strict
regression was rerun.

The subsequent diagnostic run sampled public color-well visibility, hit testing
and presentation state in the example only, under an explicit DEBUG launch option.
It did not add gestures, open the picker, retry taps, or change production
controls. No retry or relaxed value/count assertion was introduced.

On `bab4ca0`, the push run
[38112312471](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38112312471)
passed all four native cases; the PR run
[38112315968](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38112315968)
failed both physical palette openings. Both uninstrumented slider cases passed.
The failed color traces kept the wells attached, visible, enabled and hit-testable
at their centers, with no sustained presentation-state change. A 250 ms sample
cannot rule out a short intermediate state or prove delivery of a completed tap.
The following diagnostic compared a settled, single measured-center catalog tap
with the original probe element tap and observed control touch/action events
without replaying an action or weakening the palette/selection assertions.

On `6730b45`, both the push run
[38113678208](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38113678208)
and PR run
[38113680500](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38113680500)
failed the catalog's first opening while the probe, label and slider cases passed.
The failed wells received `touchDown`, `touchUpInside` and
`primaryActionTriggered` from their native control despite never presenting the
palette. The frame was stable, attached and enabled. These observations rule out
a missing completed tap in these attempts, but do not identify UIKit's internal
presentation failure.

The follow-up limited the presentation adaptation to wells with an explicit
`semanticLabel`. Their native well remains the visual and accessibility element;
one package-owned native trigger presents `UIColorPickerViewController` for both
touch and accessibility. It does not retry the system action or run two opening
paths. Omitting the label retained the system behavior. Temporary event tracing
and its DEBUG flag were removed for that candidate; strict palette, selection and
callback assertions were preserved. Duplicate activation, background cancellation,
and clearing a label during presentation received separate native coverage. That
candidate's rebuilt five color/accessibility scenarios passed on iOS 27; the
unchanged slider passed in the preceding full run. These results preceded the
ownership follow-up below.

On `e07b64c`, both the push run
[38115634422](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38115634422)
and PR run
[38115639993](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38115639993)
passed quality and both build jobs, but the catalog's first opening still failed.
The other five native cases passed. In the failed attempt the system palette
service briefly appeared and disappeared without a user close action; the
available logs did not identify the cancellation source. This remained a release
blocker at that stage. The unchanged candidate passed the catalog case on a newly
created local iOS 26.5 (23F73) simulator, followed by all six native cases. That local result
did not replace the failing cloud gate. The next diagnostic recorded the owned
presentation's entry checks and cancellation lifecycle under an explicit test
launch argument, without changing gestures, retries or assertions.

On `7bc8826`, the diagnostic PR run
[38117119312](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38117119312)
again failed only the first catalog opening. Its trace records a completed native
tap and a call to `present`, followed approximately three seconds later by picker
deinitialization while the session is still presenting. No package guard
rejection, cancellation, background event, appearance callback or presentation
completion preceded that deinitialization. A later system color-service launch
watchdog was also recorded; the logs do not establish causality between those
events. A synchronous local-variable lifetime extension alone cannot cover this
asynchronous presentation interval.

## Ownership follow-up

Candidate `e142e8c` gives the platform component explicit ownership of its
presentation session and controller. The well and controller reference the
session weakly; callbacks to the platform owner are also weak. A well retained by
a system popover cannot create another session after its platform owner is gone.

Cancelling an unfinished presentation releases the session's strong controller
reference while retaining the well's activation gate. If UIKit never adopted the
controller, its deinitialization completes cancellation; otherwise the session
observes the late controller until its actual dismissal. The controller keeps its
own cancellation flag, so it can close even after the source platform component
has been disposed. Normal visible presentations and their closing transitions
retain the controller until exit completes. Selection after cancellation does
not enter the controlled-value bridge.

The additional source-removal regression brings the native suite to seven cases.
All temporary visibility sampling, control-event targets, presentation tracing
and diagnostic launch/compiler flags have been removed. Tests still require a
single physical activation, the actual named system palette, exact selected
colors, and exact callback counts; no retries or relaxed assertions were added.
Final uninstrumented local results are recorded above. Publication requires a
successful iOS 26 CI run for the final commit, independently of the earlier local
and instrumented runs.

## First-use presentation investigation

Candidate `e142e8c` still failed the iOS 26 gate in push run
[38120009494](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38120009494)
and PR run
[38120013040](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/runs/38120013040).
Both passed quality and Android/iOS builds. Both failed the first catalog palette
opening; the push run also ended the second slider drag at 0.3 instead of 0.2.
The other five color/accessibility cases passed. The PR slider case passed.

The push recording shows the catalog remaining visible after the color-well tap,
with no visible palette through the failure. The absence is therefore not only
an accessibility-locator mismatch. System-service appearance events alone do not
prove that the application's picker appeared. Existing tests launch fresh app
processes but share a simulator; their differing color/alpha settings and order
prevent attributing the failure solely to a cold system service.

A temporary diagnostic workflow runs three independent iOS 26.5 simulators:

- The existing catalog case, with its unchanged single physical activation.
- A standalone probe with the catalog's exact starting color, alpha support and
  palette title, also opened once by physical touch.
- A separate pure UIKit app, without Flutter, with the same palette settings
  and no explicit access to the picker view before presentation.

DEBUG-only, explicitly enabled package logs record presentation ownership,
configuration, appearance and cancellation. The slider diagnostic buffers touch,
binding and editing events and emits them only after a gesture. It does not
change the value state machine, retry inputs or relax final-value assertions.
These hooks must be removed before the final release gate. The normal CI still
runs all seven existing native cases; separate diagnostic classes require their
own matched configuration or standalone host.

The new matched probe passed on a fresh local iOS 26.5 (23F73) simulator.
The pure UIKit local recording also showed a visible first palette and a black
selection. That system selection emitted both a continuous and a terminal
delegate callback with the same color. Its diagnostic fixture therefore records
raw callbacks separately from the package's deduplicated business callback and
requires closing to preserve the pre-close count. The original component tests
still require exactly one business callback. UIKit loaded the baseline picker
view within initialization even without an explicit view access; the three-arm
comparison cannot isolate view preloading as a cause. The corrected raw-count
fixture passed on the already-used local baseline device; that rerun validates
the fixture assertions, not another cold-start attempt.

## Limits

Simulator accessibility trees and activation tests do not establish the complete
VoiceOver experience on hardware. Real-device focus order, announcements,
gestures, haptics and rendering remain separate acceptance work. These local
validation runs do not modify consuming applications or publish packages.

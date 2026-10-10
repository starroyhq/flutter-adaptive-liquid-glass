# 0.2.0 candidate validation

This is an unpublished component coverage candidate. It does not replace the
published 0.1.1 package. No consuming application, production service, pub.dev
version or GitHub Release was changed during this work.

## Environment

- Flutter 3.41.9, Dart 3.11.5, pinned `native_liquid_glass` 0.3.1.
- Xcode 27.0 (27A266a); arm64 iOS simulator builds.
- Dedicated Android 15 / API 35, iOS 18.6 and iOS 27.0 simulators.
- No iOS 26 runtime was available. iOS 27 exercises the native implementation,
  but its result is **not** an iOS 26 compatibility result.

## Implementation and review

The [coverage matrix](component-coverage.md) maps all 21 capabilities to working
examples, rendering paths and behavior tests. Existing frosted materials remain
in use; no refraction shader or dynamic material fusion was introduced.

| Stage | Implementation and review outcome |
| --- | --- |
| Inventory and example | Four-page catalog, original material probe, original hybrid modal probe and explicit renderer/appearance controls. Existing component regression tests retained. |
| Basic controls | Icon constructor, grouped toolbar, slider, switch, stepper and status controls. Independent review found and fixed accepted-value echo races, missing drag-end callbacks, reduced-motion handling and native creation-time update loss. |
| Presentations | Typed menu/alert/sheet/popover routes, actual Flutter builders, nested coverage and exit handling. Fixed rapid duplicate submenu/back callbacks. Tests cover remove/replace, navigator ownership, cancellation and anchor removal. |
| Pickers and search | Local-calendar date/time selection with UTC representation preservation, continuous sRGB/alpha editing and Flutter text editing. Fixed accepted native echo feedback, active focus-node replacement and narrow large-text cancellation layout. |
| Integration | Constant children in nested Navigators now synchronize native suppression through coverage and ancestor transitions. Public documentation records native color restrictions and behavior differences. |

Status controls use small package-owned `UIActivityIndicatorView` / `UIProgressView`
bridges. The initial upstream adapters could lose changes arriving during platform
view creation, and their route suppression did not preserve all nested/exit
cases. The replacement retains the UIKit instances and coalesces atomic updates;
it does not recreate a platform view on each progress tick.

The native slider uses a system SwiftUI `Slider` hosted by a package-owned
controller. UIKit touch-up was not a reliable final-value boundary in the
available runtime. The bridge now follows the system editing callback, retains
its identity for accepted value echoes and invalidates stale callbacks on an
authoritative reset or window detachment. Hosting containment is balanced.

## Automated checks

Executed from the package root unless stated otherwise:

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test example/lib example/test example/integration_test` | Passed. |
| `flutter analyze --no-pub` | Passed, no issues. |
| `flutter test --no-pub --reporter expanded` | 158 tests passed. |
| `cd example && flutter analyze --no-pub` | Passed, no issues. |
| `cd example && flutter test --no-pub --reporter expanded` | 5 tests passed. |
| Picker suite under `TZ=America/New_York` | Passed, including the repeated DST hour and UTC representation case. |
| `git diff --check` | Passed. |

The two device integration scenarios cover mixed native/fallback nested sheets
with an editable Chinese/emoji draft, and actual fallback gestures, callback
results, search submission/clear/theme retention and a color editor round trip.
The second scenario intentionally forces fallback on every platform and uses
the SDK's synthetic text-input channel. A plain `TextField` reproduced a Flutter
3.41 test-driver issue: after submission disconnected the editor, a second
`enterText` could use a stale cached editor without reconnecting. Registering
one consistent test channel fixes that driver issue; assertions still verify
the actual controller immediately after input, after frames and after theme
changes. Production editing code was not changed for this test failure. Neither
scenario establishes physical keyboard/IME composition quality or native touch
behavior for every UIKit picker.

| Device command, run from `example` | Result |
| --- | --- |
| `flutter test integration_test/components_test.dart -d <dedicated-android-id> --no-pub --reporter expanded` | Android 15 / API 35: 2 tests passed. |
| Same command with the dedicated iOS 18.6 simulator ID | 2 tests passed. |
| Same command with the dedicated iOS 27.0 simulator ID | 2 tests passed. |

Final example builds use `flutter build apk --debug --no-pub` for Android and
`flutter build ios --simulator --debug --config-only --no-pub`,
`pod install --deployment`, then the existing CI's arm64 `xcodebuild` command
for iOS. Build output is local and excluded from the published source archive.
Both final builds passed, including the locked CocoaPods install. Outputs:

- Android: `example/build/app/outputs/flutter-apk/app-debug.apk`.
- iOS arm64 simulator: `example/build/ios-parity/Build/Products/Debug-iphonesimulator/Runner.app`.
- Packaged simulator app: `example/build/ios-simulator-0.2.0-candidate.tar.gz`.

## Interactive native checks

On the dedicated iOS 27 simulator, actual UI interactions verified:

- Native bottom tab selection and restoration after typed menu/alert results.
- Switch and stepper callbacks reaching the Flutter value labels.
- Compact date selection updating the displayed local date while retaining time.
- System color panel selection and alpha reaching the Flutter ARGB value;
  opacity input at 50% followed by a native drag to 98% produced `f92463b8`
  after the panel closed.
- Submenu selection, nested sheet expansion/scrolling/closing and a popover
  anchored inside a sheet. Flutter text, editors and native controls were visible
  together; the upper switch did not mutate the lower layer's value.
- Light/dark and a custom teal theme, including a dark alert with a returned result.

These observations are interaction checks, not GPU measurements or a guarantee
about every device, accessibility setting or transient animation frame.

### Native slider acceptance limitation

Automated desktop-to-simulator drags delivered a pointer down, one move and up
within about 6 ms. In iOS 27 this sometimes produced only an unchanged editing
cycle, and sometimes two system editing cycles for one injected drag. A separate
pure SwiftUI application, with no Flutter engine or package bridge, reproduced
the same two cycles: the value changed from 0.4 to 1.0 and the start/end counters
both became 2. This narrows the issue to the runtime/input path, but does not
prove which part is responsible or establish real-device behavior.

The package does not hide this with a timing threshold or discard legitimate
no-change editing cycles. An eager Flutter recognizer did not resolve it and
was removed; the normal tap/horizontal-drag policy remains. Disabled controls
leave parent scrolling available. Temporary logging and the standalone probe
are not included in the package.

Native slider values and final values were observed reaching Flutter, but a
clean, repeatable one-drag/one-edit-cycle acceptance result is **pending** with
normal-duration input and iOS 26 hardware/runtime. This is a release acceptance
gate, not a passed simulator check.

## Packaging and release boundary

`flutter pub publish --dry-run` produced the candidate archive and reported two
warnings: uncommitted source changes and the intentionally exact upstream 0.3.1
constraint. It did not upload a version. The exact constraint is retained by
design. The uncommitted-source warning describes the worktree at the time of
that dry run; a subsequent source commit does not publish the candidate.

The source/package candidate was locally checked for private project names,
absolute local paths and credential-shaped strings; no matches were found. Build
caches, generated local configuration and simulator logs are excluded. No private
names were added to public CI configuration as a scanning word list.

The existing CI still checks formatting, analysis and tests and builds Android
and iOS simulator artifacts. Its format check now includes integration sources.
The current candidate has not been pushed, so **no new remote CI success is
claimed**. Building an artifact does not establish device interaction success.

## Remaining external acceptance

- Native slider interaction with normal-duration input, including final values,
  reverse drags and callback counts; see the isolated runtime/input finding above.
- Real iOS 26 hardware/runtime compatibility and complete native interaction sweep.
- Physical iOS/Android GPU, frame timing, power and memory profiling.
- Full Chinese/Japanese keyboard composition and selection experience on devices.
- VoiceOver/TalkBack manual navigation, announcements, system large text and
  reduced-transparency settings across supported devices.
- Release-mode hardware rendering and store/distribution signing.

These gates remain pending; simulator and Widget results are not substitutes.

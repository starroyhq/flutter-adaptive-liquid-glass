# flutter_adaptive_liquid_glass 0.2.1

Unpublished candidate: the current cloud iOS 26 interaction gate fails. Do not
use the draft validation below as evidence of release readiness.

This patch fixes accessibility labels and activation while retaining native
UIKit navigation, Liquid Glass materials and system color selection.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.2.1
```

Run `flutter pub get` and rebuild the native app. Public Dart APIs, existing
fallback appearance, dependencies and minimum platform versions are unchanged.

## Fixes

- Native navigation actions announce their business label instead of an SF
  Symbol description. Label, title and theme updates preserve a valid pending
  click; replaced, disabled, covered and backgrounded actions reject stale events.
- Native color wells expose an explicit semantic label and UIKit's localized
  color value. Labeled wells share one owned system-picker presentation for
  physical and accessibility activation; unlabeled wells retain UIKit defaults.
  An independent delegate preserves controlled touch selection and avoids
  duplicate callbacks when closing. Native configuration updates preserve color,
  alpha, title and appearance settings.
- The platform component retains its presentation session and color-picker
  controller across UIKit's asynchronous handoff. Reverse references are weak.
  Cancellation keeps the activation gate closed until the old controller exits
  or is released; a late presentation also closes after its source is removed.
  Temporary diagnostic hooks must be removed after the ongoing cloud first-use
  investigation and before the final release gate.
- Fallback color wells expose a semantic tap action and reject stale activation
  after route coverage, backgrounding or disposal.

## Validation

The final implementation passed local format/static analysis, 224 package
tests and 7 example tests. The Android Debug APK and arm64 iOS simulator app
built during patch validation. The complete seven-case native suite passed
without diagnostics on dedicated iOS 26.5 and iOS 27 simulators after the
ownership follow-up.

The native suite now contains six color/accessibility cases and one unchanged
slider case. It covers labels/theme updates, physical and accessibility selection
with exact callback counts, tab recreation, duplicate activation/background
cancellation, clearing a label during presentation, and source removal followed
by restoration. The slider case checks four drags and two stationary presses.

All seven cases are required by the dedicated iOS 26 CI gate, alongside quality
and Android/iOS build jobs. Use the release's associated CI run for the final
tag's results; local or historical runs do not replace that gate. Full commands
and boundaries are recorded in
[native accessibility validation](native-accessibility-validation.md).

The tab recreation scenario does not establish compatibility with every
application-specific date-editing sequence. Physical-device VoiceOver/TalkBack,
focus and gesture experience, haptics, IME behavior and GPU performance remain
separate acceptance work.

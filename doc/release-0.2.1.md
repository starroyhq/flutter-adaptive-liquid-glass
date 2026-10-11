# flutter_adaptive_liquid_glass 0.2.1

This patch fixes native accessibility, palette lifecycle and slider editing
while retaining UIKit navigation, Liquid Glass materials and system color
selection. Publication is gated on the tagged source commit's successful CI;
historical diagnostic runs are not release results.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.2.1
```

Run `flutter pub get` and rebuild the native app. Public Dart APIs, existing
fallback appearance, dependencies and minimum platform versions are unchanged.

## Fixes

- Native sliders use `UISlider` values and tracking, preserving final detents
  and complete editing callbacks. Actual touch identities deduplicate a drag's
  trailing activation and allow a stationary press to complete once; values
  are never derived from touch coordinates or a delayed commit timer.
- Native navigation actions announce their business label instead of an SF
  Symbol description. Label, title and theme updates preserve a valid pending
  click; replaced, disabled, covered and backgrounded actions reject stale events.
  Coverage invalidates old events even if visibility is restored before the
  next Flutter frame.
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
  Temporary production diagnostic hooks and their test launch flags are removed.
- Native picker callbacks reject queued edits after color activation-mode
  changes, backgrounding and covered-route transitions. Ordinary labels, themes
  and accepted controlled-value echoes preserve valid edits.
- Native slider, switch and stepper bridges synchronously invalidate queued
  callbacks on backgrounding or route coverage, including coverage that begins
  and ends before the next Flutter frame.
- Programmatic dismissal releases an owned palette after its exit completes.
  A full-screen controller temporarily covering the palette preserves the
  existing session and controlled selection. Cancellation dismisses the verified
  owner's complete palette stack, including a still-presented child, before
  allowing activation again.
- Fallback color wells expose a semantic tap action and reject stale activation
  after route coverage, backgrounding or disposal.

## Validation

Local format/static analysis, all 245 package tests and all 7 example tests
pass. The Android Debug APK and arm64 iOS simulator app build. The complete
nine-case native suite passes without diagnostic hooks on dedicated iOS 26.5
and iOS 27 simulators. The associated release CI identifies the final tagged commit and
its build and interaction results.

The native suite now contains eight color/accessibility cases and one unchanged
slider case. It covers labels/theme updates, physical and accessibility selection
with exact callback counts, tab recreation, duplicate activation/background
cancellation, clearing a label during presentation, and source removal followed
by restoration. It also covers programmatic dismissal and temporary full-screen
coverage, including background cancellation while the full-screen child is still
presented. The slider case checks four drags and two stationary presses.

All nine cases are required by the dedicated iOS 26 CI gate, alongside quality
and Android/iOS build jobs. Use the release's associated CI run for the final
tag's results; local or historical runs do not replace that gate. Full commands
and boundaries are recorded in
[native accessibility validation](native-accessibility-validation.md).

The tab recreation scenario does not establish compatibility with every
application-specific date-editing sequence. Physical-device VoiceOver/TalkBack,
focus and gesture experience, haptics, IME behavior and GPU performance remain
separate acceptance work.

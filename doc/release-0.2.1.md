# flutter_adaptive_liquid_glass 0.2.1

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
- Fallback color wells expose a semantic tap action and reject stale activation
  after route coverage, backgrounding or disposal.

## Validation

Local package and example format/static checks passed, with 224 package tests
and 7 example tests. The Android Debug APK and arm64 iOS simulator app built.
Five color/accessibility XCTest cases passed after the final rebuild on a
dedicated iOS 27 simulator: labels/theme updates, physical and accessibility
selection with exact callback counts, reopening after tab recreation, duplicate
activation/background cancellation, and clearing a label during presentation.
The unchanged six-operation slider scenario passed in the preceding full run.

The complete six-case native suite is required by the dedicated iOS 26 CI gate, alongside
quality and Android/iOS build jobs. See the release's linked CI run for its
commit-specific results. Full commands and boundaries are recorded in
[native accessibility validation](native-accessibility-validation.md).

The tab recreation scenario does not establish compatibility with every
application-specific date-editing sequence. Physical-device VoiceOver/TalkBack,
focus and gesture experience, haptics, IME behavior and GPU performance remain
separate acceptance work.

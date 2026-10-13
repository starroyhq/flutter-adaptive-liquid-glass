# flutter_adaptive_liquid_glass 0.3.0

This minor release refines presentation layouts, clipping and fallback control
behavior, and adds opt-in content sizing for menus and popovers. Existing public
APIs remain available, with no new production dependencies or toolchain upgrade.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.3.0
```

Run `flutter pub get` and rebuild the native app. Flutter 3.41.2+, Dart 3.11+,
iOS 16+ and Android remain supported; native glass requires iOS 26+.
`native_liquid_glass` stays pinned to 0.3.1.

## Changes

- Clip Flutter content inside native glass surfaces so row highlights respect
  rounded corners.
- Place two alert actions side by side when text size permits; keep action-sheet
  cancellation in a separate group. Larger text retains a stacked layout.
- Stop native action sheets sliding through the bottom safe area on entry.
  Fading and the existing subtle scale remain; the separate cancel surface now
  retains its full glass height. Fallback action sheets still slide.
- Preserve fallback calendar focus and displayed month after accepted calendar
  taps unless normalization changes the selected day. Authoritative picker
  updates still reconcile normally.
- Preserve a slider thumb's grab offset when dragging from its edge.
- Anchor popover scaling to its attachment edge. Add optional `fitContent` to
  `showLiquidGlassPopover` and `LiquidGlassMenuButton`, leaving fixed-width sizing
  as the default.
- Clamp selection, slider and progress rendering for out-of-range values in
  release builds and use disabled opacity 0.48 for group actions and menu rows.

## Validation and release gate

Before the version bump, the exact production source at `35d3d95` passed static
analysis, all 255 package tests and all 299 consuming App tests. An iOS 26.5
consumer harness passed three system-input cases covering confirmation/input,
light/dark action-sheet cancel/delete, sequential and nested menus, long press,
native tab restoration, and actual pages with keyboard, attachments and drafts.
First-open native-composited screenshots in both appearances show a full cancel
surface at its unchanged 52pt frame; the previous thin strip no longer appears.
These local checks used synthetic data and are not physical-device acceptance.

The final release commit must pass one selected `Component checks` CI run:
package/example quality, Android example build, iOS simulator example build and
all ten unchanged iOS 26 native slider/accessibility cases. That same successful
run supplies the version tag's GitHub Release assets through `Publish release
assets`; local or historical builds do not replace this gate. Pub.dev publication
also requires a successful `flutter pub publish --dry-run` with reviewed files.

## Known validation limits

The independent first-use system color-palette failure recorded for 0.2.1 remains
unresolved in some hosted iOS 26.5 runs. It was also reproduced with a standalone
UIKit control. This release does not modify that presentation path or claim that
the failure is fixed or that physical devices are unaffected. See the
[existing validation record](native-accessibility-validation.md#release-decision-and-remaining-boundary).

The new native action-sheet transition avoids the observed persistent short
surface; these results do not establish a general upstream safe-area fix.
Physical-device VoiceOver/TalkBack, haptics, IME behavior and GPU performance
remain separate acceptance work.

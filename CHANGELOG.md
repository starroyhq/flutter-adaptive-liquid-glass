## 0.4.0

- Add `LiquidGlassActionBar`, the action row of a sheet or form. The last
  action is a prominent button at the trailing edge and any earlier ones share
  one glass capsule at the leading edge; they stack at the trailing edge when
  they do not fit on one line.
- `LiquidGlassButton` and `LiquidGlassButton.icon` take an optional `id`, the
  accessibility identifier of the native button (`button` as before when null).
- A disabled `prominent` `LiquidGlassButton` now drops its accent fill and is
  drawn like any other disabled button. On iOS 26 it was a solid accent capsule
  under a label too faint to read, and the fallback drew a gray pill. A loading
  button keeps its fill.
- Add opt-in `fitContent` to `showLiquidGlassSheet`. The sheet is as tall as its
  content, up to the large detent, rests on the bottom safe area and rides above
  the keyboard. There are no detents: the handle pulls the whole sheet down, and
  dismisses it past a quarter of its height or on a quick flick. The default
  sheet is unchanged.
- Draw the native `LiquidGlassSurface` material with a package-owned UIKit view
  (`UIVisualEffectView` with `UIGlassEffect`) instead of the provider's SwiftUI
  `LiquidGlassContainer`. The provider's container lays its shape out inside the
  window's safe area and does not refresh the insets it read at first layout, so
  a surface that is created below the screen and slid into place, as every sheet
  is, could end up shorter than its content, or stay missing until something
  resized it. On iOS 26.5 simulators the provider's panel ended 6-34 pt above its
  frame, or was absent from the first frames, depending on timing; the
  package-owned view ended at the expected edge in every measured run. Radius,
  tint, the fill behind the glass, route coverage and popup suppression are
  unchanged. See the [validation record](doc/native-surface-validation.md).

## 0.3.0

- Clip native-mode glass content to its rounded shape, so alert, menu and sheet
  rows no longer paint rectangular highlights outside the corners.
- Keep the fallback calendar mounted after an accepted date tap, preserving
  keyboard focus and the displayed month; remount only when a bound clamps the day.
- Fallback sliders keep the grab offset when the thumb is dragged from its edge.
- Two-action alerts lay out side by side; action sheets separate cancel actions.
- Popovers scale from their anchor edge. Add opt-in `fitContent` to
  `showLiquidGlassPopover` and `LiquidGlassMenuButton`.
- Release builds no longer paint selection, slider or progress values outside
  their track when an out-of-range value bypasses the debug assertions.
- Native action sheets retain fading and subtle scaling instead of sliding.
  The slide put the cancel group's glass over the bottom safe-area inset on first layout, and
  `native_liquid_glass` does not refresh that inset, leaving a thin strip.
- Use one disabled opacity (0.48) for group actions and menu rows.
- Publish with an explicitly accepted known limitation: the selected hosted
  iOS 26.5 run passed 9/10 native cases, failing first system-palette appearance.
  Analysis, unit tests and both platform builds passed. The failed run is retained;
  this release does not fix or hide that first-use issue. See the 0.3.0 release notes.

## 0.2.1

- Use system `UISlider` values and tracking for native slider edits. Preserve
  final detents and complete stationary presses exactly once, while cancelled
  touch identities cannot reopen an editing cycle.
- Give native navigation actions their explicit business labels instead of SF
  Symbol descriptions. Keep UIKit navigation and native button rendering.
- Invalidate queued navigation activations immediately when a route is covered,
  including coverage and restoration within the same Flutter frame.
- Expose a caller-supplied color-well label together with UIKit's localized color
  value, while retaining the native color picker and controlled callback contract.
- Explicitly present the system palette for labeled native color wells, using
  one owned activation path for touch and accessibility. Unlabeled wells retain
  UIKit's default interaction and accessibility behavior.
- Retain the owned palette across asynchronous presentation and keep its
  activation gate closed until cancellation or dismissal actually completes.
  A removed source cannot leave a late palette active or emit stale selections.
- Present an ordinary system color-picker controller, observing lifecycle through
  a noninteractive child instead of subclassing the system controller. Release
  temporary strong ownership once UIKit adopts the presentation.
- Release a palette after programmatic dismissal while preserving its session
  when a nested full-screen controller temporarily covers it.
- Reject queued native picker and value-control edits after backgrounding,
  covered-route transitions and authoritative interaction resets. Ordinary
  label/theme updates and accepted controlled-value echoes preserve valid edits.
- Add native accessibility example and XCTest regressions for labels, theme
  updates, actual palette selection and accessibility activation.
- Make the fallback color sample accessible through its semantic tap action,
  rejecting callbacks after route coverage, backgrounding or disposal.
- Document an unresolved first-use system palette failure in some hosted iOS
  26.5 runs, also reproduced by a standalone UIKit control. Passing lifecycle
  regressions do not establish that this separate first-use failure is fixed.

## 0.2.0

- Bind native slider editing callbacks to the actual touch sequence, preventing
  a late iOS 26 editing-begin from reopening an already completed drag. Normalize
  and deduplicate binding writes before opening a gesture; accessibility
  adjustments retain their own complete editing cycle. Preserve an early end
  notification until the binding write when iOS 26 reverses stationary-press
  editing callbacks.
- Replace Cupertino fallback controls with owned slider/switch rendering,
  repeating stepper buttons, localized date wheels and an activity painter.
- Add independent package haptic/sound permissions, platform feedback dispatch,
  long-only actions and default tap-or-long-press menu triggers. Native capsules
  cancel click-after-hold and stale lifecycle events; system tabs remain native.
- Preserve controlled input and date/time contracts through resets, calendar
  boundaries and DST changes, including half-hour DST jumps with a 20-minute
  interval. Reject stale wheel input after route coverage or backgrounding.
- Preserve the public 0.1.1 surface, button, navigation, selection and color
  APIs. New long-press callbacks are optional; feedback permissions default to
  enabled and can be disabled independently. The new menu trigger defaults to
  tap and long press, with explicit tap-only and hold-only alternatives.
- Expand the independent example into a 21-capability component catalog with
  Controls, Pickers, Popups and Search pages; retain the material and mixed-modal
  probes behind explicit compile-time flags.
- Add controlled sliders, switches and steppers with owned system bridges and
  Flutter fallbacks, disabled state, range handling and value reconciliation.
- Add activity/progress indicators using owned `UIActivityIndicatorView` and
  `UIProgressView` bridges. Apply updates after native creation and balance nested
  popup visibility without rebuilding UIKit instances for every progress update.
- Add an icon-button constructor, grouped toolbars, Flutter search editing and
  a controlled search scaffold.
- Add compact, inline and wheel date pickers with local-calendar display,
  UTC/local output preservation, bounds and minute-grid validation. Add controlled
  sRGB color picking with optional alpha and fallback HEX editing.
- Add independent nested menus and typed alert/action-sheet, sheet and popover
  routes, including keyboard constraints, scroll/drag coordination and anchor
  tracking.
- Add component/widget regressions and runnable device integration scenarios
  for mixed-content sheets, nesting, Unicode drafts and fallback controls.
- Preserve the pinned native provider, iOS 26 system tabs, custom color tokens
  and existing fallback material. Keep Flutter 3.41.9 / Dart 3.11.5 as the
  development/CI baseline and `native_liquid_glass` pinned to 0.3.1, with no added
  production dependencies. This release does not add a refraction shader or
  claim pixel parity.
- Document package feedback separately from feedback owned by native controls
  and the Material calendar. Add normal-duration native slider XCTest coverage
  and a dedicated iOS 26 CI gate. Physical-device acceptance and a complete
  interactive iOS 26 control sweep remain separate; see
  [release notes](doc/release-0.2.0.md) for the validation boundaries.

## 0.1.1

- Prepare the first pub.dev release with an MIT license, installation instructions,
  and Android/iOS platform metadata.
- Preserve the 0.1.0 component API and rendering behavior.

## 0.1.0

- Add adaptive surfaces, buttons, shared button groups, navigation bars, tabs,
  and segmented controls.
- Use native Liquid Glass and system tabs on iOS 26+, with Flutter fallback
  materials on older iOS and Android.
- Support light/dark appearance, custom color tokens, reduced motion and reduced
  transparency, and a shared animated selection capsule.
- Handle mixed Flutter/native popup composition and popup exit transitions.
- Include an independent Android/iOS example, widget tests, and build workflows.
- Release example builds on GitHub.

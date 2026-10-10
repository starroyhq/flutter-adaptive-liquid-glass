## 0.2.0

- Bind native slider editing callbacks to the actual touch sequence, preventing
  a late iOS 26 editing-begin from reopening an already completed drag. Normalize
  and deduplicate binding writes before opening a gesture; accessibility
  adjustments retain their own complete editing cycle.
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

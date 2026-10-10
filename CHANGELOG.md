## 0.2.0 — unreleased candidate

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
  and existing fallback material. This candidate does not add a refraction
  shader or claim pixel parity. Publication, CI results and physical-device
  acceptance are recorded separately from implementation.

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

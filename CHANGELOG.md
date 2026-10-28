## Unreleased
- A drag on the native slider that starts on the thumb now keeps the point
  where the finger pressed the thumb, so the thumb follows the finger. Before,
  the movement until Flutter's drag gesture passed its touch slop (about 18
  points) was lost and the thumb ended that far behind the finger. A press on
  the track away from the thumb still behaves as UIKit does. Vertical drags
  that start on a slider in a scrollable still scroll it.
- In debug builds a control whose mode resolves to native but which draws its
  Flutter rendering prints the reason once per process with `debugPrint`: a
  `loading` button, a button, button group or segmented control at a large
  text size, and a navigation bar with more than one leading or trailing
  action, a long press, an icon without an `sfSymbol` or large text. Release
  builds and the fallback and opaque modes print nothing.
- Documentation: the navigation bar keeps disabled actions native, and apps
  that use the standalone `material_ui` package need its compatibility bridge.

## 0.6.0

- The package no longer depends on `native_liquid_glass`, and so no longer
  brings its pods and packages (SVGKit, CocoaLumberjack, `flutter_svg`,
  `path_parsing` and others) into apps. The Flutter SDK is its only production
  dependency.
- On iOS 26 the tab bar, the segmented control, standalone icon buttons and the
  check for native support are package-owned: a `UITabBarController`, a
  `UISegmentedControl` and the package's glass capsule. Their API is unchanged,
  and so is their look except as noted below. The segmented control is as wide
  as the space it is given without the previous 32-point widening.
- A native icon-only `LiquidGlassButton(...)` without a long press now applies
  its `iconColor`, `iconSize` and `menuIndicator`, as the fallback already did.
- A native button outside a button group updates its native view in place when
  it is enabled or disabled or its emphasis or colors change, as an icon-only
  button without a long press did in 0.5.2. Text buttons and icon-only buttons
  with a long press got a new native view for these changes before. A new
  title, icon, size, long-press action or text direction still creates a new
  view.
- So does each action of a native `LiquidGlassButtonGroup`, and so of a
  `LiquidGlassToolbar`, the leading capsule of a `LiquidGlassActionBar` and a
  navigation bar's grouped actions: enabling or disabling one updates the
  shared capsule in place, and a press UIKit reported before the change is
  still rejected. Adding, removing or reordering actions, or a new label, icon
  or `showLabel`, still creates a new view.
- A native `LiquidGlassNavigationBar` keeps the system `UINavigationBar` when
  one of its actions is disabled, and updates that action in place. Before, a
  disabled action switched the whole bar to the Flutter title layout.
- An icon-only native button with a long press now looks like one without: a
  semibold symbol centred on its ink, or the trimmed Material glyph, in colors
  that do not change when pressed or disabled. Before, a long press gave it the
  capsule's regular-weight symbol. This includes the default trigger of an
  icon-only `LiquidGlassMenuButton`, which opens on a long press by default.
- Apps that also depend on `native_liquid_glass` no longer share its platform
  views or its `liquid-glass-lifecycle` channel with this package, so neither
  hides the other's native views.
- A native icon-only button without a long press now uses its `id` as the
  native accessibility identifier (`button` by default) and its `semanticLabel`
  as the native accessibility label.
- A fallback control shows a light highlight under a hovering mouse pointer.
  Its mouse cursor stays Flutter's default: the click cursor on the web and the
  basic arrow elsewhere.
- The native `LiquidGlassSegmentedControl` returns to its selected segment on
  the next frame when the parent does not adopt a choice, as the tab bar
  already did; so does a disabled one that still reports a choice. Before, a
  refused choice could stay shown.
- On iOS 26 a tab icon without an `sfSymbol` is drawn at the screen's pixel
  ratio and at about the size of the bar's symbols. Before, its bitmap was
  shown at a scale of 1 and covered the selected tab's capsule.
- Native buttons, button groups, toolbars, action bars and the navigation
  bar's capsules follow Flutter's `Directionality` instead of the device
  language. Right to left, a button's icon is to the right of its title, a
  group's first action is on the right, and an `IconData` with
  `matchTextDirection` is mirrored, as is a standalone icon's SF Symbol that
  flips for right-to-left layouts. A semantic SF Symbol such as
  `arrow.backward`, `arrow.forward` or `chevron.backward`, alone or beside a
  title, takes its right-to-left form; explicit symbols such as `arrow.left`,
  and symmetric ones, are unchanged.
- On iOS 26 the native `LiquidGlassTabBar` and `LiquidGlassSegmentedControl`
  follow Flutter's `Directionality` instead of the device language, and a new
  direction recreates them. Right to left, the first tab and segment are at the
  right and the tab bar's `trailingAction` at the left; indexes stay in logical
  order, as in the fallback.
- On iOS 26 the native tab bar's `UITabBarController` becomes a child of the
  view controller that shows the bar, found through the responder chain once
  the bar is in a window. Before, the plugin used the view controller its
  registrar returned at registration, which can still be nil when an implicit
  engine registers plugins under the UIScene life cycle; the tab bar controller
  then had no parent.
- With `native_liquid_glass` removed, the iOS home indicator follows the
  system default, so it can now appear where it stayed hidden before. This
  package does not control the home indicator. An app that wants iOS to hide
  it automatically can call
  `SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top])`:
  in Flutter 3.41 this makes `FlutterViewController` prefer an auto-hidden home
  indicator and keeps the status bar. On Android the same call also hides the
  navigation bar.
- The README's Validation section and the example's README note that building
  the bundled example with Swift Package Manager needs a checkout directory
  named `flutter_adaptive_liquid_glass`, and the installation section that an
  app built with Swift Package Manager needs an iOS Deployment Target of 16.0
  or later.
- `LiquidGlassTheme.maybeOf` returns null when there is no `LiquidGlassTheme`
  above the context.
- `showLiquidGlassPopover` accepts a `barrierColor`; the default scrim stays 8%
  black.
- `LiquidGlassColorPicker` accepts `hexLabelText`, `hexErrorText` and
  `channelSemanticFormatterCallback` to replace the English text of its
  fallback sheet. The defaults are unchanged.
- The `disableAnimations` argument of `LiquidGlassThemeData.resolve` is
  deprecated. It never affected the result.
- The README gains Performance and Known limitations sections.

## 0.5.2

- On iOS 26 an SF Symbol in a native button is now about as large as the
  matching Material icon in the fallback. Beside a title it takes the title's
  font, as UIKit buttons do; alone, or at a requested `iconSize`, it is sized at
  0.75 of the icon size, so a 22-point icon becomes a 16.5-point symbol.
  Icon-only buttons pass the same size to `native_liquid_glass`; bitmap icons
  keep their box. Symbols were sized as 22-point fonts before and looked about
  a third larger.
- A native `LiquidGlassSurface` whose route is covered, such as a sheet under
  an alert, keeps an opaque Flutter material in the system material's tone
  instead of leaving its content over the page. Native controls inside it
  still hide until the route above leaves.
- The native `LiquidGlassSegmentedControl` spans the width it is given.
  `native_liquid_glass` 0.3.1 insets its picker by 16 points on each side,
  which the package now offsets; touches still land only inside the control.
- Fallback slider and switch thumbs are white in both appearances, as on iOS,
  unless the palette sets `surfaceTint`.

## 0.5.1

- `LiquidGlassAction` takes `showLabel`, which shows the label after the icon
  in a `LiquidGlassButtonGroup`, and so in a `LiquidGlassToolbar` and the
  leading capsule of a `LiquidGlassActionBar`. It is off by default, so an
  action with an icon still shows only the icon there. On iOS 26 the native
  capsule item shows the label as its title beside the image. Navigation and
  tab bars keep showing an icon or a label, in the fallback as well.
- The example app's `GLASS_NEW_CONTROLS` page has a toolbar with labelled
  actions.

## 0.5.0

- `LiquidGlassButton` takes a `detail` shown after the label in a quieter
  colour, an `iconColor` and `iconSize` for marks such as a status dot, and
  `menuIndicator` for the platform's pop-up indicator. On iOS 26 they map to
  the native button's attributed title, image and indicator. The accessibility
  label joins the label and the detail. `LiquidGlassMenuButton` passes the same
  options to its default trigger.
- A native capsule title that does not fit now ends with an ellipsis instead of
  being cut mid-glyph; its accessibility label keeps the whole text.
- Add `LiquidGlassScrollEdgeEffect`, the iOS 26 scroll edge effect for Flutter
  scrollables, which the system applies to `UIScrollView` only. `soft` is a
  progressive blur fading into the page colour, `hard` an opaque band with a
  hairline. An edge shows only while content is beneath it; reduced
  transparency and high contrast use `hard`.
- `LiquidGlassNavigationBar` takes a `subtitle`, the navigation item's own
  subtitle on iOS 26 and a second line in the fallback.
- Alerts and sheets dim the page more deeply in a dark theme (48% black instead
  of 20%), and `showLiquidGlassAlert` and `showLiquidGlassSheet` take a
  `barrierColor`.
- `LiquidGlassTabBar` takes a `trailingAction`, a separate round button after
  the tabs such as search. On iOS 26 it is the native tab bar's search-style
  item; it never changes the selected tab.
- `LiquidGlassSearchScaffold` takes `searchPlacement`. The default `top` keeps
  the search field above the body; `tabBar` puts a search button after the tabs
  and, while searching, docks the field at the bottom above the keyboard with a
  close button, hiding the tabs.
- The example app has a `GLASS_NEW_CONTROLS` page showing these additions.

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

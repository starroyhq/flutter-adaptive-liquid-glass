# Component coverage

This matrix describes the current source API, its rendering paths and the
regression tests that exercise it. It is not a record of device or CI results.
The package covers 21 UI capabilities associated with the pinned
`native_liquid_glass` provider. Public APIs are package-owned; they are not a
one-to-one copy of the provider or of UIKit. Icon buttons are counted separately
and exposed through `LiquidGlassButton.icon`, without another widget class.

## Rendering paths

- **Native** means a system control, through the pinned provider or a small
  package-owned UIKit/SwiftUI bridge, when the resolved mode permits it on iOS 26+.
- **Hybrid** means Flutter owns layout, content, editing or routing while a
  native glass background or control supplies the supported system appearance.
- **Fallback** uses the existing frosted material and package-owned controls on
  older iOS and Android. It does not add refraction shaders, complex light
  effects or dynamic glass fusion.

Light, dark and system appearance are supported. Optional
`LiquidGlassThemeData.colors` overrides apply where each rendering path exposes
the relevant color role. Native materials retain UIKit's appearance; custom
fallback borders, shadows and selection fills do not replace system glass.
Reduced transparency and high contrast select opaque surfaces. Reduced motion
removes package-managed movement independently of material selection.

The native tab bar is an explicit exception to mode selection: iOS 26+ keeps
the system tab bar, including when the theme requests fallback or opaque
surfaces. Opaque mode or reduced transparency adds a solid backdrop. Other
fixed-height controls can use Flutter layout when large text or unsupported
action configurations require it.

## The 21 capabilities

The default example opens the **Component catalog**. Its tabs are **Controls**,
**Pickers**, **Popups** and **Search**. The **Appearance** action changes colors,
appearance and accessibility preferences. Example locations below refer to
[component_catalog.dart](../example/lib/component_catalog.dart) and
[catalog_popups.dart](../example/lib/catalog_popups.dart).

| # | Capability and public API | Native or hybrid path on iOS 26+ | Fallback and key contract | Catalog entry | Regression source |
| --- | --- | --- | --- | --- | --- |
| 1 | Surface / container: `LiquidGlassSurface` | Hybrid: provider glass container behind Flutter content; background ignores input | Bounded blur, protective fill and rim; `floating` / `control` styles, radius, padding and optional tint; opaque rendering removes blur | Controls → Surface and buttons | [surface_material_test.dart](../test/surface_material_test.dart), [color_theme_test.dart](../test/color_theme_test.dart) |
| 2 | Button: `LiquidGlassButton` | Package UIKit capsule for text buttons; Flutter loading state | Frosted button or prominent fill; two null callbacks disable; loading disables submission; optional independent long press | Controls → Surface and buttons | [fallback_test.dart](../test/fallback_test.dart), [flutter_adaptive_liquid_glass_test.dart](../test/flutter_adaptive_liquid_glass_test.dart) |
| 3 | Icon button: `LiquidGlassButton.icon` | Provider icon button, or package capsule for long press; optional SF Symbol | Same button interaction with required `semanticLabel` and fallback `IconData` | Controls → Surface and buttons → Add | [status_toolbar_test.dart](../test/status_toolbar_test.dart), [flutter_adaptive_liquid_glass_test.dart](../test/flutter_adaptive_liquid_glass_test.dart) |
| 4 | Shared action capsule: `LiquidGlassButtonGroup` | One package UIKit glass capsule containing plain buttons | One shared material, individual 48-point minimum targets, stable action IDs and per-action enabled state | Controls → Grouped toolbar | [button_group_test.dart](../test/button_group_test.dart) |
| 5 | Navigation bar: `LiquidGlassNavigationBar` | Package `UINavigationBar` bridge with explicit action labels when its configuration is supported; otherwise Flutter title with adaptive controls | Explicit leading/trailing actions; adjacent actions share a capsule; app owns navigation | Catalog page header; accessibility probe | [native_navigation_test.dart](../test/native_navigation_test.dart), [button_group_test.dart](../test/button_group_test.dart), [flutter_adaptive_liquid_glass_test.dart](../test/flutter_adaptive_liquid_glass_test.dart) |
| 6 | Tab bar: `LiquidGlassTabBar` | Provider system `UITabBarController` / `UITabBar`, retained on iOS 26+ | Shared moving selection capsule; 2–5 controlled items, optional badges, selected icons and labels | Catalog bottom tabs | [fallback_selection_test.dart](../test/fallback_selection_test.dart), [flutter_adaptive_liquid_glass_test.dart](../test/flutter_adaptive_liquid_glass_test.dart) |
| 7 | Segmented control: `LiquidGlassSegmentedControl<T>` | Provider segmented control | Shared moving selection capsule; unique typed values, controlled selection, nullable callback disables | Controls → Segmented control | [fallback_selection_test.dart](../test/fallback_selection_test.dart), [color_theme_test.dart](../test/color_theme_test.dart) |
| 8 | Activity indicator: `LiquidGlassActivityIndicator` | Package `UIActivityIndicatorView` bridge with atomic configuration and retained instances | Package-painted indicator; medium/large size, stopped visibility and semantic label; reduced motion uses a static indicator | Controls → Activity and progress | [status_toolbar_test.dart](../test/status_toolbar_test.dart), [native_status_test.dart](../test/native_status_test.dart) |
| 9 | Progress view: `LiquidGlassProgressView` | Package `UIProgressView` bridge with atomic configuration and retained instances | Determinate Flutter progress from 0 to 1; configurable height, active/track colors and semantic value; no extra glass layer | Controls → Activity and progress | [status_toolbar_test.dart](../test/status_toolbar_test.dart), [native_status_test.dart](../test/native_status_test.dart) |
| 10 | Slider: `LiquidGlassSlider` | System `UISlider` through a per-instance bridge; values come from native tracking, with touch identities preventing duplicate or stale editing cycles | Package-painted slider; controlled value/range, optional divisions, start/change/end callbacks and semantic formatter | Controls → Slider | [value_controls_test.dart](../test/value_controls_test.dart), [value_interaction_test.dart](../test/value_interaction_test.dart), [native_value_control_test.dart](../test/native_value_control_test.dart) |
| 11 | Switch: `LiquidGlassSwitch` | Package `UISwitch` bridge with per-instance channel | Package-painted switch; controlled boolean, nullable callback disables, semantic label | Controls → Switch | [value_controls_test.dart](../test/value_controls_test.dart), [value_interaction_test.dart](../test/value_interaction_test.dart), [native_value_control_test.dart](../test/native_value_control_test.dart) |
| 12 | Stepper: `LiquidGlassStepper` | Package `UIStepper` bridge with per-instance channel | Shared capsule with decrement/increment buttons and hold-to-repeat; controlled value, positive step, range and optional wrapping | Controls → Stepper | [value_controls_test.dart](../test/value_controls_test.dart), [value_interaction_test.dart](../test/value_interaction_test.dart), [native_value_control_test.dart](../test/native_value_control_test.dart) |
| 13 | Date picker: `LiquidGlassDatePicker` | Package `UIDatePicker` bridge; compact, inline or wheels preferences | Compact trigger opens a package sheet; Material inline calendar and/or package-owned wheels; controlled local-calendar selection with bounds, locale and minute interval | Pickers → Date picker | [pickers_test.dart](../test/pickers_test.dart), [fallback_date_wheels_test.dart](../test/fallback_date_wheels_test.dart) |
| 14 | Color picker: `LiquidGlassColorPicker` | Native `UIColorWell` appearance and system palette; explicitly labeled wells share an owned `UIColorPickerViewController` presentation path for touch and accessibility; unlabeled wells retain UIKit defaults | Color well opens a package sheet with RGB/alpha sliders and HEX input; controlled sRGB color; continuous changes, no second commit on close | Pickers → Color picker; accessibility probe | [pickers_test.dart](../test/pickers_test.dart), native `NativeAccessibilityUITests` |
| 15 | Search field: `LiquidGlassSearchField` | Hybrid: Flutter `TextField` in an adaptive glass surface | Same editor, clear/cancel actions, external or internally owned controller/focus; change and submit callbacks | Search → Search field | [search_test.dart](../test/search_test.dart) |
| 16 | Search scaffold: `LiquidGlassSearchScaffold` | Flutter layout, adaptive search field and native tab bar | Caller-owned body, results, selected tab and search-active state; retains body state while results are displayed; hides tabs while keyboard is visible | Search → Open search scaffold | [search_test.dart](../test/search_test.dart) |
| 17 | Toolbar: `LiquidGlassToolbar` | Flutter layout of package-native shared capsules | Explicit groups of `LiquidGlassAction`; separate groups retain spacing and scroll horizontally when constrained | Controls → Grouped toolbar | [status_toolbar_test.dart](../test/status_toolbar_test.dart) |
| 18 | Alert / action sheet: `showLiquidGlassAlert<T>` | Hybrid: Flutter `PopupRoute`, content and actions over adaptive native glass | Same typed-result route; alert/action-sheet styles, disabled/destructive/cancel actions and optional barrier dismissal | Popups → Alert / Action sheet | [presentation_test.dart](../test/presentation_test.dart) |
| 19 | Menu: `LiquidGlassMenuButton<T>` with `LiquidGlassMenuItem<T>` | Hybrid: Flutter menu content in a package glass popover | Independent triggers, nested items, selected/disabled/destructive states, selection/cancellation callbacks; tap/long-press trigger policy; unique item values within a menu tree | Popups → First / Second / Third menu | [menu_test.dart](../test/menu_test.dart) |
| 20 | Sheet: `showLiquidGlassSheet<T>` | Hybrid: Flutter content and route over adaptive native glass | Medium/large detents, drag handle, optional drag/dismiss, safe-area and keyboard constraints; builder receives primary scroll controller scope | Popups → Mixed sheet / Nest sheet | [presentation_test.dart](../test/presentation_test.dart) |
| 21 | Popover: `showLiquidGlassPopover<T>` | Hybrid: anchored Flutter route and content over adaptive native glass | Follows anchor during layout changes, flips/clamps to available space, dismisses when anchor disappears; typed result and optional barrier dismissal | Popups → Popover / Nest popover | [presentation_test.dart](../test/presentation_test.dart) |

## Value and editing contracts

Value controls are controlled widgets. Update the supplied value from the
callback to accept an edit. Native value and picker bridges apply complete
configuration updates, reject stale instance events and reapply the supplied
value after an unaccepted edit. Programmatic updates do not invoke business
callbacks. A null change callback disables the control.

Slider values use the declared range and, when supplied, equally spaced
`divisions`. Stepper increments that pass a bound clamp to that bound, or wrap
to the opposite bound when `wraps` is true. Fallback repetition stops on
release, cancellation, disabling, backgrounding, covered routes and disposal.

Date selection displays the device's local calendar values. Outputs retain the
input value's UTC/local representation; an explicit named time-zone API is not
provided. Date-only changes preserve the existing local time, while time-only
changes preserve the local date. Time modes use the minute grid and clear
seconds. Date-mode bounds compare calendar dates; time-mode bounds compare
instants and snap inward to selectable minutes. Invalid intervals and empty
ranges fail explicitly. Supported minute intervals are
`1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30`. Calendar-day reconstruction follows
Dart/platform local-time rules across daylight-saving transitions; this is not
an arbitrary time-zone scheduling API.

Color values are converted to sRGB. `supportsAlpha: false` exposes opaque
colors and removes alpha editing. The fallback accepts `RRGGBB` or `RRGGBBAA`
HEX values. Changes are delivered during editing; closing the picker does not
mean cancel/revert. Applications needing a transactional choice should maintain
a draft color and apply their own confirmation action.

Search preserves Flutter's complete `TextEditingValue`, including selection
and IME composing state. It has no implicit debounce, data source or network
request. The application decides when and how to search. `SearchScaffold` does
not create a Navigator or take ownership of the application's router; pass its
body from the existing application layout or router.

## Presentation and lifecycle foundation

Lifecycle and appearance are shared infrastructure, not additional entries in
the 21 UI capabilities:

- Install `LiquidGlassAppearance` with the application's selected `ThemeMode`
  so native controls follow manual light/dark appearance as well as system mode.
- Install a distinct `LiquidGlassNavigatorObserver` on each Navigator that
  presents glass popups. Dispose it when the owning Navigator is discarded.
  Popup helpers default to the root Navigator; `useRootNavigator` can select
  the nearer Navigator instead.
- Native backgrounds and controls on covered routes leave painting, input and
  accessibility composition while retaining their Flutter state. Coverage
  remains until the outgoing transition completes, including nested popup
  routes; route replacement, removal and observer disposal balance ownership.
- Alert, menu, sheet and popover content remains in Flutter. These helpers do
  not create a `UIAlertController`, `UIMenu`, `UISheetPresentationController`
  or UIKit popover controller to host arbitrary Flutter widgets. Consequently,
  their geometry and transitions are package behavior rather than a claim to
  reproduce every system presentation detail.

The infrastructure regression sources are
[appearance_test.dart](../test/appearance_test.dart),
[native_visibility_test.dart](../test/native_visibility_test.dart) and
[navigator_observer_test.dart](../test/navigator_observer_test.dart).
The catalog's cross-component checks live in
[component_catalog_test.dart](../example/test/component_catalog_test.dart).
The runnable mixed-popup integration scenario is
[components_test.dart](../example/integration_test/components_test.dart).
Automated widget checks do not establish native compositing correctness,
physical-device performance or complete screen-reader/IME behavior.

## Design references and scope

Apple's [Materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials)
distinguishes the floating control/navigation layer from reading content. This
package uses bounded glass surfaces and avoids adding a glass layer behind
every status indicator or content region.

Apple's [Pickers guidance](https://developer.apple.com/design/human-interface-guidelines/pickers)
informs the date/time modes and choice of compact, inline and wheel
presentations. The package exposes a deliberately bounded cross-platform API;
it does not cover every UIKit picker type or every platform presentation style.

Apple's [Search fields guidance](https://developer.apple.com/design/human-interface-guidelines/search-fields)
informs search, clear and placeholder affordances. Placement, suggestions,
filtering, result ranking and application navigation remain application
decisions. Search tokens, a native search-tab morph and automatic scroll-edge
effects are not part of the current API.

## Package-owned interaction follow-up

The fallback slider, switch, stepper buttons, date wheels and activity indicator
no longer instantiate Cupertino controls. SDK localization resources remain in
use for date labels and order. Feedback flags apply to package-generated events;
native controls and the Material calendar retain their system behavior.

Interaction regressions live in [feedback_test.dart](../test/feedback_test.dart),
[long_press_test.dart](../test/long_press_test.dart),
[native_capsule_test.dart](../test/native_capsule_test.dart),
[value_interaction_test.dart](../test/value_interaction_test.dart) and
[fallback_date_wheels_test.dart](../test/fallback_date_wheels_test.dart).

See [interaction validation](interaction-validation.md) for the current checks,
including long press, repeating controls, date boundaries and device limitations.

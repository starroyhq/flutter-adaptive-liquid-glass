# flutter_adaptive_liquid_glass 0.5.0

This minor release adds controls for apps that show status and switch context
often: richer buttons, the iOS 26 scroll edge effect for Flutter scrollables, a
navigation bar subtitle, a trailing tab bar action and a search field that docks
at the bottom. Existing public APIs remain available and every new parameter is
optional, with no new production dependencies or toolchain upgrade.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.5.0
```

Run `flutter pub get` and rebuild the native app. Flutter 3.41.2+, Dart 3.11+,
iOS 16+ and Android remain supported; native glass requires iOS 26+.
`native_liquid_glass` stays pinned to 0.3.1.

## Changes

- `LiquidGlassButton` takes a `detail` shown after the label in a quieter colour,
  an `iconColor` and `iconSize` for marks such as a status dot, and
  `menuIndicator` for the platform's pop-up indicator. On iOS 26 they map to the
  native button's attributed title, image and indicator. The accessibility label
  joins the label and the detail. `LiquidGlassMenuButton` passes the same options
  to its default trigger.
- A native capsule title that does not fit ends with an ellipsis instead of being
  cut mid-glyph; its accessibility label keeps the whole text.
- Add `LiquidGlassScrollEdgeEffect`, the iOS 26 scroll edge effect for Flutter
  scrollables, which the system applies to `UIScrollView` only. `soft` is a
  progressive blur fading into the page colour, `hard` an opaque band with a
  hairline. An edge shows only while content is beneath it; reduced transparency
  and high contrast use `hard`.
- `LiquidGlassNavigationBar` takes a `subtitle`, the navigation item's own
  subtitle on iOS 26 and a second line in the fallback.
- Alerts and sheets dim the page with 48% black in a dark theme instead of 20%.
  `showLiquidGlassAlert` and `showLiquidGlassSheet` take a `barrierColor`. This is
  a deliberate visual change.
- `LiquidGlassTabBar` takes a `trailingAction`, a separate round button after the
  tabs such as search. On iOS 26 it is the native tab bar's search-style item; it
  never changes the selected tab.
- `LiquidGlassSearchScaffold` takes `searchPlacement` and `searchLabel`. The
  default `top` keeps the search field above the body; `tabBar` puts a search
  button after the tabs and, while searching, docks the field at the bottom above
  the keyboard with a close button, hiding the tabs.
- The example app has a `GLASS_NEW_CONTROLS` page showing these additions.

## Validation

The source passed `dart format`, analysis of the package and the example, 304
package tests and 8 example tests.

The `GLASS_NEW_CONTROLS` example page was inspected from screenshots on an iOS
26.5 simulator with native glass and on iOS 18.6 with the fallback, in light and
dark appearance: buttons with a detail, status dot and menu indicator, a clipped
title ending with an ellipsis, the scroll edge effect over scrolled content, the
navigation bar subtitle, and the sheet and alert scrims. The tab bar with a
separate search button was inspected on iOS 26.5 only, where it is the system's
own round item; the fallback tab action and the docked search field are covered
by widget tests.

The gating `Component checks` run for the tagged commit, including the native
iOS 26.5 interaction job, is linked from the GitHub release.

## Known validation limits

The independent first-use system color-palette failure recorded for 0.2.1 remains
unresolved in some hosted iOS 26.5 runs. This release does not modify that
presentation path or claim that the failure is fixed or that physical devices are
unaffected. See the
[existing validation record](native-accessibility-validation.md#release-decision-and-remaining-boundary).

The scroll edge effect is drawn by Flutter and approximates the system effect; it
was compared with the system only by eye on simulators. Physical devices and
large text were not checked for the new controls.

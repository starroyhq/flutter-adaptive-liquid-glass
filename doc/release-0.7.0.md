# flutter_adaptive_liquid_glass 0.7.0

This release keeps the page's native Liquid Glass on screen while one of the
package's alerts, sheets, popovers or menus is open. Before, every popup
removed the page's native tab bar, buttons and segmented controls for as long
as it was open. Under other popups, such as Material and Cupertino sheets and
dialogs, the page's native controls now draw their Flutter rendering in place
instead of leaving gaps. A new `LiquidGlassOverlayGuard` protects app content
painted above the package's popups in its own `OverlayEntry`.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.7.0
```

Flutter 3.41.2+, Dart 3.11+, iOS 16+ and Android remain supported; native glass
requires iOS 26+ and builds with Xcode 26 or later. No new production
dependencies.

## Upgrading

1. Change the constraint to `^0.7.0`. In a 0.x version `^0.6.x` does not select
   0.7.0 automatically.
2. Run `flutter pub get`.
3. Perform a full native rebuild; the iOS plugin code changed.
4. If the app shows Flutter content in its own `OverlayEntry` that can appear
   above one of the package's popups, such as a toast, wrap that content in
   `LiquidGlassOverlayGuard`. Without the guard its edges can be clipped where
   the page's native glass is.

Existing APIs remain available and need no code changes. Keep a
`LiquidGlassNavigatorObserver` on every Navigator that presents popups; a
Navigator without one still hides the native views of every route that is not
current.

## Visible changes

- Native glass under the package's popups. `showLiquidGlassAlert`,
  `showLiquidGlassSheet`, `showLiquidGlassPopover`, `LiquidGlassMenu`, the menu
  buttons and the picker editors built on them keep the native views of the
  page below them on screen, dimmed by the barrier. The barrier still takes
  taps, so tapping a page control only closes the popup, and VoiceOver does not
  reach the page's controls.
- Flutter stand-ins under other popups. Popup routes that are not the
  package's own, such as Material or Cupertino sheets, dialogs and menus and
  custom `PopupRoute`s, still isolate the page below them. Each native control
  there now paints its Flutter rendering in its place, under the barrier, so
  the page no longer shows gaps. A stand-in can differ slightly from the
  native glass. Ordinary page transitions draw nothing in place of the page
  below, as before.
- Focus in a popup. While a text field, selectable text or `SelectionArea` in
  one of the package's popups has focus, the popup isolates the page, so the
  selection toolbar, its handles and the magnifier are not clipped by the
  page's native views. When the focus leaves, the native views return in the
  frame after the toolbar has gone. A package popup whose content resolves to
  fallback or opaque glass, for example under a local `LiquidGlassTheme`,
  always isolates.
- iOS fade timing. A native view that returns after a popup or a page above it
  has gone now appears at once instead of fading in over 0.25 s, with the
  control's Flutter rendering under it until it is back. A covered native view
  starts its 0.15 s UIKit fade-out after 0.3 s, by which time Flutter has
  already taken it out of composition, so a slow frame no longer leaves a gap.
  It still stops taking touches and leaves the accessibility tree at once.
- Nested Navigators. The page's native glass also stays where a shell
  Navigator's routes are reported to the root Navigator's observer as well, as
  `go_router`'s `ShellRoute` does. The observer works out which routes stay on
  screen per Navigator, so a popover above such a page no longer removes the
  page's native controls without drawing stand-ins. With a single Navigator
  the result is unchanged.

The rules are described in the README under
[Native rendering and overlays](../README.md#native-rendering-and-overlays).

## New API

- `LiquidGlassOverlayGuard`. While a guard is mounted, the package's popups
  isolate the page as other popups do, and the guarded content appears from
  the frame in which the page is isolated. A guard changes nothing while no
  package popup is open.

```dart
OverlayEntry(
  builder: (context) => LiquidGlassOverlayGuard(child: toast),
);
```

## Validation

The source passed `dart format`, analysis of the package and the example, 373
package tests (15 more than 0.6.1) and 11 example tests on Flutter 3.41.9, and
`flutter pub publish --dry-run` with 0 warnings.

In the iOS 27.0 simulator (iPhone 17 Pro, Xcode 27.1), on a page shaped like a
list screen with a standalone icon button, a segmented control, a text button
and a tab bar with a search tab:

- A row-menu popover and a package sheet keep the page's native glass intact.
- A Material sheet shows the page's Flutter stand-ins, and a dialog above it
  and the sheet after it closes are complete.
- The Flutter selection toolbar in a package sheet and alert is complete while
  the page is isolated. A toast in its own `OverlayEntry` loses its rounded
  corners without a guard and is complete with `LiquidGlassOverlayGuard`.
- Frame-by-frame checks of screen recordings show no frame in which neither the
  native view nor its stand-in is drawn while popups open and close.
- XCUITest `testPopupsKeepNativeControlsBeneathThemOutOfReach` finds no
  hittable page control under the package's popups, and taps at the controls'
  positions only close the popup.

The details, screenshots and a single profile-mode frame timing comparison on
a device are in
[Native glass under the package's popups](fallback-validation.md#native-glass-under-the-packages-popups).
iOS 26 was not run locally; the CI native interaction job covers it next to
iOS 27.0.

An app built with a `go_router` shell structure was checked on one physical
iPhone: with the popups checked open, the page's tab bar, buttons and
segmented control stayed on screen under the barrier, and a toast wrapped in
`LiquidGlassOverlayGuard` was complete above them.

CI runs for this release are listed under
[Component checks on fix/keep-native-glass-under-popups](https://github.com/starroyhq/flutter-adaptive-liquid-glass/actions/workflows/ci.yml?query=branch%3Afix%2Fkeep-native-glass-under-popups);
the gating run for the tagged commit, including both native interaction runs,
is linked from the GitHub release.

## Known limitations

- Flutter overlays of a package popup other than the text selection toolbar,
  such as a `Tooltip`, a `MenuAnchor` or an `OverlayPortal`, are clipped where
  they extend past the popup's surface over the page's native glass. Wrap such
  content in `LiquidGlassOverlayGuard`, or keep it inside the popup.
- The behaviour depends on how Flutter's iOS platform view composition slices
  the scene. The simulator checks above are repeated when the Flutter version
  changes.
- VoiceOver under the package's popups was checked only through XCUITest in
  the simulator; acceptance with VoiceOver on a device is still needed.
- On the iOS 26 CI job, the native slider case
  `testSlowForwardAndReverseDragsKeepOneEditingCycle` occasionally ends one
  step short (0.7 instead of 0.8). This release does not change the slider.

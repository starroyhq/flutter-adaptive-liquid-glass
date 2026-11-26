# flutter_adaptive_liquid_glass 0.9.0

On iOS 26 and later, standalone text and icon buttons use the UIKit glass
styles. The system supplies its pressed and disabled appearance and draws the
activity indicator while loading. Text buttons follow the app's text scale.

The default menu button now expands into a UIKit menu in native mode on
iOS 26 and later. UIKit handles nested menus and press-drag selection.

## Upgrading from 0.8.x

Change the dependency constraint to `^0.9.0` and run `flutter pub get`.
The `LiquidGlassButton` and `LiquidGlassButton.icon` constructor arguments
carry over. Perform a full native rebuild to pick up the UIKit changes. The
existing Flutter renderers serve Android, iOS 25 and earlier, and apps using
fallback or opaque mode.

Existing menu items keep their typed values and callbacks. Add `sfSymbol`
for an iOS menu icon, or pass PNG bytes as `iconPng`. Use `icon` to supply
a Flutter glyph. The native menu uses the trigger's UIKit presentation and
system sizing, so `Navigator.pop`, `useRootNavigator`, `width` and
`fitContent` no longer control that menu. For a Flutter route and custom
positioning or width, use the existing custom `builder`. Explicit tap-only
and long-press-only triggers also keep their Flutter popovers.

See the [button documentation](../README.md#button-details-subtitles-and-scroll-edges)
for layout and accessibility details.

## Button validation

On the iOS 27.1 iPhone Duo simulator, the example attaches a UIKit menu to
the actual standalone buttons. The system expands the menu from either
button, and selecting a menu item leaves the underlying button callback
untouched. The example also checks native loading, large text and the
existing shared capsule.

The default-menu example also passed XCUITest on iPhone Duo with iOS 27.1.
The tests open a real `LiquidGlassMenuButton`, cancel once by tapping outside,
select a nested action, and select an item with one press-and-drag gesture.

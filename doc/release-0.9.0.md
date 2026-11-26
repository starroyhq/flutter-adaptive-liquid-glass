# flutter_adaptive_liquid_glass 0.9.0

On iOS 26 and later, standalone text and icon buttons use the UIKit glass
styles. The system supplies its pressed and disabled appearance and draws the
activity indicator while loading. Text buttons follow the app's text scale.

The default menu button now expands into a UIKit menu in native mode on
iOS 26 and later. UIKit handles nested menus and press-drag selection.

The navigation bar groups multiple leading and trailing actions on shared
system glass. A navigation action can show a bitmap icon or a text or dot
badge, or open its own data-driven menu.

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

Inside a Flutter `ListView`, `GridView`, `SingleChildScrollView`, or a
horizontal scroller, the default native menu button gives UIKit the first
touch so the same gesture can select a menu item. A drag that starts on the
button will not scroll the surrounding list. Start the drag outside the
button, place the button outside the scrollable area (for example, in a fixed
header), or set `trigger: LiquidGlassMenuTrigger.tap` or
`LiquidGlassMenuTrigger.longPress` to use the Flutter popover.

Existing navigation actions continue to work with stable IDs. Use distinct
IDs across the bar. Pass `iconPng` for a PNG icon or `badge` for a label
(`''` is a dot, `null` clears it). Use `LiquidGlassNavigationMenu` with
`LiquidGlassMenuItem<String>` entries and `onSelected` on a menu action.
The menu takes the action's tap. Put `onPressed` and `onLongPress` on
separate actions. UIKit can collapse an action group when space is limited.
In the Flutter layout, groups that do not fit can scroll horizontally.
The bar still uses the Flutter layout at large text sizes or when an action
uses `onLongPress`.

See the [navigation example](../example/README.md#native-navigation-probe)
and the [button documentation](../README.md#button-details-subtitles-and-scroll-edges).

## Validation

On the iOS 27.1 iPhone Duo simulator, the example attaches a UIKit menu to
the actual standalone buttons. The system expands the menu from either
button, and selecting a menu item leaves the underlying button callback
untouched. The example also checks native loading, large text and the
existing shared capsule.

The default-menu example also passed XCUITest on iPhone Duo with iOS 27.1.
The tests open a real `LiquidGlassMenuButton`, cancel once by tapping outside,
select a nested action, and select an item with one press-and-drag gesture.

The navigation bar test verifies two UIKit groups, a text action and bitmap
icons, distinct menus, and changing and clearing a badge. It also switches
between left-to-right and right-to-left layout on the iOS 27.1 simulator.

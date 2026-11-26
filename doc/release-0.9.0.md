# flutter_adaptive_liquid_glass 0.9.0

On iOS 26 and later, standalone text and icon buttons use the UIKit glass
styles. The system supplies its pressed and disabled appearance and draws the
activity indicator while loading. Text buttons follow the app's text scale.

## Upgrading from 0.8.x

Change the dependency constraint to `^0.9.0` and run `flutter pub get`.
The `LiquidGlassButton` and `LiquidGlassButton.icon` constructor arguments
carry over. Perform a full native rebuild to pick up the UIKit changes. The
existing Flutter renderers serve Android, iOS 25 and earlier, and apps using
fallback or opaque mode.

See the [button documentation](../README.md#button-details-subtitles-and-scroll-edges)
for layout and accessibility details.

## Button validation

On the iOS 27.1 iPhone Duo simulator, the example attaches a UIKit menu to
the actual standalone buttons. The system expands the menu from either
button, and selecting a menu item leaves the underlying button callback
untouched. The example also checks native loading, large text and the
existing shared capsule.

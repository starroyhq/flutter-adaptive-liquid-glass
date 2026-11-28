# flutter_adaptive_liquid_glass 0.10.0

On iOS 26 and later, supported controls continue to use UIKit Liquid Glass.
Flutter fallback surfaces use an opaque fill, fine outline, rounded corners,
and a soft shadow. Scroll edges use a color fade or a hairline. Tab badges
sit beside their icons. The fallback segmented control is 36 logical pixels
at standard text sizes, iOS navigation titles center, and the switch and
slider use the same accents as their native versions.

## Upgrading from 0.9.x

Change the dependency constraint to `^0.10.0`, run `flutter pub get`, and perform
a full native rebuild. Explicit surface tints are now painted opaque in
fallback mode. Existing `blurSigma` and `LiquidGlassColors.highlight` values
remain accepted. Review foreground contrast against custom fills.

Pass `triggerChild` to `LiquidGlassMenuButton` for a custom button appearance
with native press and menu interaction. Keep the child purely visual. In
scrollable layouts, start the scroll outside the trigger or place the trigger
in a fixed header. Existing `builder(context, open)` and explicit single-gesture
triggers continue to use the Flutter popover.

Call `showLiquidGlassMenu` from an existing control and pass its context to
`anchorContext`. Either API can use the same items, including a section with
`displayInline: true`, item `subtitle`, a checkmark, disabled items, and
destructive actions. In native mode on iOS 26 and later, a transparent UIKit
button opens the system menu at the anchor and preserves editing focus.
Flutter menus handle older versions and other platforms.
[UIKit primary action](https://developer.apple.com/documentation/uikit/uicontrol/performprimaryaction%28%29)

For a passive toast, place its Flutter overlay clear of native bars and omit
`LiquidGlassOverlayGuard`. Keep the guard for content that must cover native
views outside an open package popup. The guard isolates the page while the
popup is open, and native controls temporarily switch to Flutter drawing.

## Example

The example includes a stable comparison screen for the fallback and the
system controls. Run from `example` on an iOS simulator:

```sh
flutter run -t lib/planar_fallback_probe.dart
```

Use iOS 18 to check the fallback and iOS 26 to check the native controls. Run
both with the simulator set to light and dark appearance.

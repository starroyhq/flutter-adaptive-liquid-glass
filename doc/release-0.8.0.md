# flutter_adaptive_liquid_glass 0.8.0

This release adds window geometry for Flutter layouts on iPhone Duo, iPad and
Android foldables. Apps can use size classes, display features and window
control margins when choosing pane layouts and placing their own controls.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.8.0
```

The package supports Flutter 3.41.2+, Dart 3.11+, iOS 16+ and Android. Native
glass requires iOS 26+ and builds with Xcode 26 or later. The Flutter SDK is the
only production dependency.

## Upgrading

1. Change the constraint to `^0.8.0`. Dart's `^0.7.x` constraints select only
   0.7 releases.
2. Run `flutter pub get` and perform a full native rebuild.
3. Wrap the app's navigator in `LiquidGlassWindowGeometryScope` in
   `MaterialApp.builder` to opt in. Read
   `LiquidGlassWindowGeometry.of(context)` below the scope.

## Layout data

- Read the window size and safe area in Flutter logical pixels. The safe area
  follows `MediaQuery.viewPadding` while the keyboard is visible.
- On supported iOS windows, use UIKit's horizontal and vertical size classes,
  its recommended vertical navigation edge and any reported reserved areas. The
  `windowControlMargins` on supported iPads represent guide-adjusted margins
  for arranging app chrome around the system window controls.
- Use `reservedRegions` when a layout needs the division or occlusion kind,
  active flag or reported fold posture. The scope passes Flutter's existing display
  features and active UIKit divisions to its descendants' `MediaQuery`, where
  standard Flutter layout widgets can read them.
- Android uses Flutter's display features. On older iOS versions, use the
  available Flutter and UIKit data. Unsupported native properties are
  `null`.

See [Window geometry](../README.md#window-geometry) for the API example and
property reference.

## Validation

On Flutter 3.41.9, format and static analysis pass for the package and example.
The package passes 377 tests, including native geometry updates, preservation of
the mounted widget tree and Flutter display features. The example passes 11
tests.

An iPhone Duo simulator running iOS 27.1 reports a 466×678 logical-pixel outer
screen, compact horizontal and regular vertical size classes, a trailing
vertical bar, and two reserved regions. The
[geometry smoke test](../example/integration_test/window_geometry_test.dart)
checks the native bridge. Inner-screen and half-fold placement remain for
device validation.

An iPad (A16) simulator on iPadOS 27.0 reports window control margins through
the native guide in its default window. Resized and Stage Manager windows
remain for device validation.

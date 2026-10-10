# flutter_adaptive_liquid_glass_example

Standalone iOS/Android showcase for `flutter_adaptive_liquid_glass`. Its dependency uses `path: ../`,
which resolves to the surrounding `flutter-adaptive-liquid-glass` package. The example
runs independently of any consuming app.

From the `flutter-adaptive-liquid-glass` package root:

```sh
cd example
flutter pub get
flutter run
```

Use the controls to compare system/light/dark appearance, rendering modes and
reduced transparency. iOS 26+ uses native Liquid Glass; older iOS and Android use
the Flutter fallback. Bottom tabs remain native on iOS 26+ in every rendering
mode. See the [package README](../README.md) for setup and validation boundaries.

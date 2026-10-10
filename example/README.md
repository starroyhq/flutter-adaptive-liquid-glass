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

The example keeps reading content on a neutral, solid canvas. Only the toolbar,
segmented control, floating composer and bottom tabs use glass. Adjacent search
and sliders actions share one capsule. Text and code blocks scroll behind these
controls so the material can be inspected against changing backgrounds.

The sliders action opens appearance and accessibility options:

- Compare **System**, **Light** and **Dark** without restarting the app.
- Select **Neutral**, **Blue** or **Green** independently of appearance. Neutral
  retains the original neutral theme; Blue and Green use `ColorScheme.fromSeed`
  and `LiquidGlassColors.fromColorScheme`, including separate dark schemes.
  These are example presets: the package accepts arbitrary colors and schemes.
- Compare rendering modes. On iOS 26+, `fallback` changes the other controls but
  bottom tabs always remain native. Use Android or older iOS to inspect fallback tabs.
- Enable **Reduce motion** to stop fallback selection travel and press scale while
  retaining glass. Disable it and rapidly select different tabs or segments to
  inspect the shared capsule's movement and retargeting.
- Enable **Reduce transparency** to replace background blur with a solid material.
  Test this separately from reduced motion and then with both enabled.

The settings sheet uses the same renderer policy as the preview, including native
segments on iOS 26+. Covered routes keep their Flutter content, but temporarily
stop painting native platform views until the overlay finishes its exit animation.
This prevents hidden background views from reserving composition slices in a modal.
The tab selection updates the visible selected-tab label; this is a component
showcase, not a routed multi-page app. The segments filter the sample rows.

Also check these interactions on a device or simulator:

1. Scroll through the list and solid code blocks. The background should be blurred
   only inside control bounds; foreground labels must remain sharp in both themes.
2. Tap each half of the shared toolbar capsule. Search opens a keyboard dialog;
   sliders opens the options sheet. Neither control should intercept taps while
   covered by a popup. Native content underneath the popup must not bleed through.
3. Enter Chinese, Japanese and emoji in the floating composer. The composer should
   rise above the keyboard, preserve Flutter editing and stay clear of the tabs.
   Tabs are hidden while the keyboard is visible; drag the list or use the keyboard
   dismissal button to restore them.
4. Increase system text size and inspect selection, labels, hit areas and scrolling.
   Repeat with the system's reduced-motion setting as well as the example toggle.
5. On iOS 26+, repeat selection, theme changes and popup presentation with the
   original native controls. A successful Flutter fallback test does not validate
   UIKit material composition.
6. Repeat scrolling and selection in Blue and Green, switching between light and
   dark without changing the palette. Verify prominent-button foregrounds and
   selected labels. Native controls use the supported public color mappings;
   custom fallback selection fills and rims do not replace UIKit's material.

For your own palette, see the [custom color API](../README.md#custom-colors), which
supports partial token overrides, `fromColorScheme` and local `copyWith` changes.
Validate text contrast with your chosen colors and actual backdrop content;
the package does not guarantee contrast for arbitrary custom colors.

The fallback has no refraction shader. Painting layers separate the background and
moving selection, but scrolling performance and GPU cost need device profiling.
These are acceptance steps, not a claim that every listed device check has passed.
See the [package README](../README.md) for setup and validation boundaries.
The current run is recorded in [fallback validation](../docs/fallback-validation.md).

## Mixed native/Flutter modal regression

```sh
flutter run --dart-define=GLASS_MODAL_PROBE=true
```

Open Dialog and Bottom Sheet, nest them, and close them in order. Every layer
interleaves Flutter text, an editable draft, a switch, native segments, a shared
capsule and a native surface. Use the three native toggles to isolate a control;
compile-time defaults can also be set with `GLASS_MODAL_SEGMENT`,
`GLASS_MODAL_CAPSULE` and `GLASS_MODAL_SURFACE`. They do not change the tab policy.
Verify all text stays visible, callbacks target only the front layer, selected
values survive returning to a previous layer, and the root tab bar returns.
Repeat with light/dark and Blue/Green. This probe needs an iOS 26+ runtime to
establish native composition behavior; widget tests validate only Dart behavior.

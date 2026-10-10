# flutter-adaptive-liquid-glass

Business-independent adaptive Liquid Glass controls for Flutter. The app owns navigation, editing,
authorization and state. The package owns bounded visual surfaces and controls.

Repository: [starroyhq/flutter-adaptive-liquid-glass](https://github.com/starroyhq/flutter-adaptive-liquid-glass).
The repository and checkout directory use hyphens. The Dart package name and
imports use `flutter_adaptive_liquid_glass`, following Dart's
[package naming rules](https://dart.dev/tools/pub/pubspec#name); hyphens are not
valid in a pubspec package name.

## Local checkout integration

The package lives in the standalone `flutter-adaptive-liquid-glass` directory and its Dart
package name is **`flutter_adaptive_liquid_glass`**. For a local consuming app,
keep the two directories beside each other:

```text
data/
  my_app/
  flutter-adaptive-liquid-glass/
    pubspec.yaml
    lib/
    example/
```

In `my_app/pubspec.yaml`, use the sibling path:

```yaml
dependencies:
  flutter_adaptive_liquid_glass:
    path: ../flutter-adaptive-liquid-glass
```

Run `flutter pub get` from the consuming app after changing the dependency path.
The package's independent example already uses `path: ../`, relative to its own
`example/pubspec.yaml`, and can run independently.

## Usage

```dart
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

MaterialApp(
  navigatorObservers: [LiquidGlassNavigatorObserver()],
  themeMode: appThemeMode,
  builder: (context, child) => LiquidGlassAppearance(
    mode: appThemeMode,
    child: LiquidGlassTheme(
      data: const LiquidGlassThemeData(mode: LiquidGlassMode.auto),
      child: child!,
    ),
  ),
);
```

Use `LiquidGlassSurface`, `LiquidGlassNavigationBar`, `LiquidGlassTabBar`,
`LiquidGlassButton`, `LiquidGlassButtonGroup` and `LiquidGlassSegmentedControl<T>`. All public arguments use
Flutter or package-owned types. SF Symbol names are optional platform hints;
also supply `IconData` for fallback rendering. Icon buttons require a semantic
label. Controls are controlled: the caller updates selection after callbacks.

Install `LiquidGlassAppearance` once at the app root using the same **ThemeMode**
as `MaterialApp`. Its small iOS plugin applies public UIKit appearance overrides
to the Flutter controller and its own window, so native buttons and containers
match manually selected light/dark themes. `system` explicitly clears overrides;
never substitute the resolved `Theme.of(context).brightness` for the selected mode.
Android and Dart-only embedders need no appearance channel. Adding this plugin
requires `flutter pub get` and a native rebuild, not only hot reload.

`LiquidGlassButtonGroup(actions: [...])` accepts one or more `LiquidGlassAction`s.
Adjacent actions share **one** `UIVisualEffectView(UIGlassEffect)` capsule on
iOS 26, containing plain UIKit buttons. They are not individual glass circles.
The fallback similarly has one surface, with tooltip/semantic labels and
`ValueKey(action.id)` on each action. Do not wrap groups in another glass surface.

Native text buttons use the same small UIKit bridge. `UIButton.Configuration`
and native title measurement own their layout, replacing the upstream SwiftUI
path that compressed Chinese titles even with an explicit platform-view width.
The Flutter estimate prevents first-frame collapse; UIKit's intrinsic content
width can enlarge it, never shrink it. Icon-only standalone controls continue to
use the pinned provider. Both paths retain native materials and app appearance.

## Custom colors

`LiquidGlassThemeData.colors` accepts a `LiquidGlassColors` object. Every color
field is optional: omitted values retain the package's current theme-derived
defaults. This is an arbitrary-color API, not a fixed collection of palettes.
Override only the tokens your app needs:

```dart
LiquidGlassTheme(
  data: const LiquidGlassThemeData(
    colors: LiquidGlassColors(
      accent: Color(0xff2459b7),
      onAccent: Colors.white,
      selection: Color(0xffe4edff),
      selectedForeground: Color(0xff152c56),
    ),
  ),
  child: controls,
);
```

| Token | Purpose |
| --- | --- |
| `surfaceTint` | Base tone of the glass surface; fallback material controls fill opacity |
| `foreground` | Ordinary control text and icons |
| `accent` / `onAccent` | Emphasized controls and their content |
| `selection` / `selectedForeground` | Selected capsule fill and selected content |
| `border` / `highlight` | Edge and rim highlight colors |
| `shadow` | Contact shadow color |

For a complete palette, derive colors from any Flutter `ColorScheme`. Use the
resolved light or dark scheme in the widget tree, so changing appearance also
updates the glass palette:

```dart
final scheme = Theme.of(context).colorScheme;
final glassData = LiquidGlassThemeData(
  colors: LiquidGlassColors.fromColorScheme(scheme),
);
```

The host can create its scheme with `ColorScheme.fromSeed`, use a hand-built
scheme or supply individual color tokens. The example's Neutral, Blue and Green
choices are demonstration presets only. Neutral keeps the original unbranded
appearance; the seed examples generate separate light and dark schemes.

Both theme data and colors support `copyWith`, preserving fields not supplied.
Use this for a local override without dropping accessibility preferences or the
rest of the palette:

```dart
final inherited = LiquidGlassTheme.of(context);
final local = inherited.copyWith(
  mode: LiquidGlassMode.fallback,
  colors: inherited.colors.copyWith(
    border: const Color(0x6654719d),
  ),
);
```

Fallback `selection`, `border`, `highlight` and `shadow` colors retain the alpha
you supply. `surfaceTint` is a base tone, not a replacement for the material's
opacity policy; opaque accessibility mode still removes transparency. Verify
custom foregrounds against the composed surface in both themes and against
changing backgrounds. Custom colors do not imply a contrast guarantee.

On iOS 26+, colors are forwarded through the available public native tint,
foreground and selected-item APIs. UIKit keeps its native material and
accessibility behavior. Custom selection fills, rims and shadows are fallback
painting controls; they do not replace system glass. The native bottom tab bar
does not accept a custom glass background. Native and fallback rendering are
therefore not expected to produce identical pixels for a custom palette.

## Rendering policy

| Preference | iOS 26+ | Other platforms |
| --- | --- | --- |
| `auto` / `native` | System Liquid Glass | Flutter approximation |
| `fallback` | Flutter approximation | Flutter approximation |
| `opaque` | Solid accessible surfaces | Solid accessible surfaces |

The table applies to surfaces, buttons, segmented controls and navigation bars.
**Bottom tabs always use the system `UITabBarController` / `UITabBar` on iOS 26+,**
including `fallback` and `opaque`. They retain UIKit selection, hit testing and
system accessibility materials. `opaque` or `reduceTransparency` places a solid
backdrop behind the native bar; no private accessibility APIs are called. Reduced
motion, high contrast and large text do not replace native tabs with painted tabs.
On older iOS and Android, bottom tabs follow the table.

`native` never forces an unsupported UIKit view. For the other controls,
`reduceTransparency` and `MediaQuery.highContrast` override the rendering preference
with opaque rendering. Reduced motion is separate: `reduceMotion` or
`MediaQuery.disableAnimations` stops fallback movement while retaining the chosen
material. Native controls continue to use system motion behavior. Large text
switches fixed-height native controls to flexible Flutter controls. The caller can
forward an explicit OS/application reduced-transparency preference through
`LiquidGlassThemeData`.

The fallback uses a translucent neutral fill, bounded background blur, a subtle
gradient rim and a contact shadow. Light and dark themes use separate material
strengths, derived from the host's `ColorScheme` without an imposed brand tint.
The optional color tokens above can customize that palette. Floating
surfaces use 60% fill alpha in light mode and 76% in dark mode; control surfaces
use 64% and 78%. This protective layer keeps text readable over contrasting
content. Pixel tests cover both neutral and default Material 3 themes over black
and white backgrounds, including the selected capsule, at a minimum 4.5:1 text
contrast. Custom themes and explicit tints must supply suitable foreground colors.
The dark fill's tone is slightly lifted so it remains visible on black. The gradient rim is 0.8 logical
pixels. The default blur is sigma 20. `LiquidGlassSurfaceStyle.floating` suits
bottom bars and floating content; `control` provides a tighter treatment for
buttons and action groups, with blur capped at sigma 8. Opaque/accessibility
surfaces have no background blur or shadow.

Fallback tabs and segmented controls each have **one shared selection capsule**
that travels between items with a 220ms damped curve, including right-to-left
layouts. A rapid second selection retargets the moving capsule. Content, selection
and glass background are separate painting layers; this structure alone does not
prove reduced GPU work while scrolling, which still requires device profiling.
Tab height can grow with larger text instead of truncating labels. Every action
retains at least a 48-point hit target. Press feedback uses a 120ms scale and
neutral highlight even in apps that disable Material splashes; reduced motion
disables both selection travel and press scale.

This Flutter material is an approximation: it does not implement refraction
shaders or claim to reproduce UIKit's physical glass rendering. iOS 26 native
surfaces, shared button capsules and system tabs retain their existing implementation.
Keep glass on toolbars/floating controls; use solid reading surfaces for code,
messages and forms. Text fields remain Flutter widgets inside a surface.

## Native dependency and overlays

`native_liquid_glass` is pinned to **0.3.1** (Flutter >=3.41.2, Dart >=3.11).
Its types do not appear in this package's public API.
Only ordinary tab destinations are exposed; the provider's
detached action-tab path, including dynamic prominent-tab lookup, is not used.

Install a separate `LiquidGlassNavigatorObserver` on every Navigator that presents
popup routes. Dispose it when discarding a Navigator. Covered routes retain their
native widgets' layout and state but exclude them from Flutter painting, hit testing
and semantics until the popup's exit transition completes. Merely making a UIKit
view transparent is insufficient: its platform-view rectangle can still participate
in composition and clip the Flutter content of a mixed native/Flutter popup.
The observer tracks nested coverage across navigator boundaries and balances
removal, replacement and disposal. Flutter children of `LiquidGlassSurface` remain
painted while only its native material is excluded. No plugin cache edits or
whole-page fallback are required. The provider's UIKit suppression and the owned
capsule's reference-counted listener remain in use as an additional occlusion guard.
Custom `OverlayEntry` presentations are not Navigator routes: stop painting the
underlying native controls while such an overlay is active. Changing themes does
not remove the native tab platform view. Verify system materials on iOS hardware.

`NavigationBar` falls back when an action is disabled or its IconData lacks an
SF Symbol, preserving enabled state and icons that the native navigation-bar
provider cannot express. Basic icon-only navigation should supply both.

## Validation

Run these commands from the `flutter-adaptive-liquid-glass` package root:

```sh
flutter pub get
flutter analyze
flutter test
cd example
flutter pub get
flutter run
```

The independent example contains iOS/Android host projects. Its sliders action
opens rendering mode, system/light/dark appearance, independent color palettes,
reduced-motion and reduced-transparency controls. Scroll content behind the shared toolbar capsule,
floating segmented control, Flutter composer and bottom tabs to inspect changing
backgrounds. The reading area uses a neutral canvas, plain rows and solid code
blocks. See [example acceptance steps](example/README.md) for the interactions.
CI/widget tests verify portable behavior;
iOS 26 Release rendering, VoiceOver, real keyboard/IME, scrolling beneath glass,
popup occlusion, rapid tab selection, old iOS and Android hardware remain device
acceptance gates. Do not treat widget tests as native rendering proof.

`publish_to: none` prevents accidental pub.dev publication; it does not control
the visibility of the GitHub repository. No pub.dev publication is part of
the application work. Review its public API and select the package's own license
before a separate open-source release. Upstream attribution is preserved in
`THIRD_PARTY_NOTICES.md`.

## Continuous integration

The `Component checks` workflow runs on pushes, pull requests and manual dispatch.
It pins Flutter 3.41.9, enforces the root/example lockfiles, formats and analyzes
both, and runs both test suites. After quality passes, separate jobs build the
example Debug APK (Java 17) and an arm64 iOS simulator application (macOS 26).
The iOS job generates Flutter configuration, enforces `Podfile.lock`, then invokes
`xcodebuild` directly to avoid the toolchain's combined-architecture parsing issue.
Only the APK and archived simulator `.app` are retained as artifacts for 14 days.
Build success does not establish native animation, IME, accessibility or GPU
performance. See the [validation record](docs/fallback-validation.md) for executed
checks and remaining device acceptance.

## GitHub releases

Prepare a version tag and a draft GitHub Release with reviewed notes, then run
`Publish release assets` manually with that tag and a successful `Component checks`
run ID for the same commit. The workflow verifies the package version, source
commit, workflow identity and artifact SHA256 digests before uploading the example
APK, simulator archive and `SHA256SUMS`, then publishing the draft.

Artifact transfer happens entirely on a GitHub runner; no local download or rebuild
is needed. The regular CI remains read-only. Only the manually dispatched publish
job has release write access. Existing release assets are not overwritten; if a
partial upload needs recovery, inspect the draft before retrying.

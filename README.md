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

`native` never forces an unsupported UIKit view. For the other controls, `reduceTransparency`,
`reduceMotion`, `MediaQuery.highContrast` and `MediaQuery.disableAnimations`
override the rendering preference with opaque rendering. Large text switches fixed-height
native controls to flexible Flutter controls. The caller can forward an explicit
OS/application reduced-transparency preference through `LiquidGlassThemeData`.

The fallback uses a single neutral translucent fill, a 0.5 logical-pixel hairline,
clipped blur and a small contact shadow. There are no decorative gradients or
painted highlights. `LiquidGlassSurfaceStyle.floating` is the default for bottom bars
and floating content; `control` uses a lighter shadow and limits blur to sigma 8.
The floating default is sigma 18. Buttons and action groups choose `control`
automatically. Colors come from the host's `ColorScheme`, without a brand tint.
Opaque/accessibility surfaces have no blur or shadow. Segmented controls use a
solid tonal track with a contrasting selected thumb. Fallback tabs use a neutral
selected pill, 20-point icons and 11-point labels; their 60-point base height can
grow with larger text rather than truncating labels. Every action retains at least
a 48-point hit target. Press feedback uses a 120ms scale and neutral highlight,
even in apps that disable Material splashes; reduced motion disables the scale.
This restrained material does not claim UIKit's physical refraction.
Keep glass on toolbars/floating controls; use solid reading surfaces for code,
messages and forms. Text fields remain Flutter widgets inside a surface.

## Native dependency and overlays

`native_liquid_glass` is pinned to **0.3.1** (Flutter >=3.41.2, Dart >=3.11).
Its types do not appear in this package's public API.
Only ordinary tab destinations are exposed; the provider's
detached action-tab path, including dynamic prominent-tab lookup, is not used.

Install a separate `LiquidGlassNavigatorObserver` on every Navigator that presents
popup routes. Dispose it when discarding a Navigator. Native surfaces also use
the provider's route suppression. The owned UIKit capsule listens to the same
reference-counted global suppression broadcasts and records their current state
from plugin registration. A new view beneath an already-open root dialog starts
hidden; popup-owned controls remain visible unless their own route is covered.
Native view disposal clears its method handler and suppression listener.
Custom `OverlayEntry` presentations are not
Navigator routes: hide the underlying native controls while such an overlay is
active; changing themes does not remove the native tab platform view. A color-only theme change is not proof that system
materials rendered correctly; verify on iOS hardware.

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

The independent example contains iOS/Android host projects and switches render
mode, system/light/dark theme and reduced transparency. It uses a neutral canvas
and plain content rows to inspect controls in an app-like context, not colored
demo cards. CI/widget tests verify portable behavior;
iOS 26 Release rendering, VoiceOver, real keyboard/IME, scrolling beneath glass,
popup occlusion, rapid tab selection, old iOS and Android hardware remain device
acceptance gates. Do not treat widget tests as native rendering proof.

`publish_to: none` prevents accidental pub.dev publication; it does not control
the visibility of the GitHub repository. No pub.dev publication is part of
the application work. Review its public API and select the package's own license
before a separate open-source release. Upstream attribution is preserved in
`THIRD_PARTY_NOTICES.md`.

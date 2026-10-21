# flutter-adaptive-liquid-glass

Business-independent adaptive Liquid Glass controls for Flutter. The app owns navigation, editing,
authorization and state. The package owns bounded visual surfaces and controls.

Repository: [starroyhq/flutter-adaptive-liquid-glass](https://github.com/starroyhq/flutter-adaptive-liquid-glass).
The repository and checkout directory use hyphens. The Dart package name and
imports use `flutter_adaptive_liquid_glass`, following Dart's
[package naming rules](https://dart.dev/tools/pub/pubspec#name); hyphens are not
valid in a pubspec package name.

Version **0.6.0** drops the `native_liquid_glass` dependency, so the Flutter SDK
is the only production dependency, and supports Swift Package Manager as well as
CocoaPods. The native tab bar, segmented control and icon-only buttons are now
package-owned UIKit bridges; native controls update in place, follow Flutter's
`Directionality` and fix several look and behaviour issues. It adds
`LiquidGlassTheme.maybeOf`, a popover `barrierColor` and replaceable color-sheet
text. See the [0.6.0 release notes](doc/release-0.6.0.md) and the
[upgrade notes](#upgrading-from-05x).

The **0.5.2** patch sizes native SF Symbols like the fallback's Material
icons, keeps a covered sheet's material under an alert, lets the native
segmented control span its width and draws fallback thumbs white. See the
[0.5.2 release notes](doc/release-0.5.2.md).

The **0.5.1** patch lets an action in a button group, a toolbar or the leading
capsule of an action bar show its label after its icon
(`LiquidGlassAction.showLabel`). See the
[0.5.1 release notes](doc/release-0.5.1.md).

Version **0.5.0** adds controls for status-heavy apps: a button `detail`, a
coloured `iconColor`/`iconSize` mark and a `menuIndicator`; the iOS 26 scroll
edge effect for Flutter scrollables (`LiquidGlassScrollEdgeEffect`); a navigation
bar `subtitle`; a tab bar `trailingAction` such as search; and a search field that
docks at the bottom (`LiquidGlassSearchScaffold.searchPlacement`). Native capsule
titles end with an ellipsis, and alerts and sheets dim the page more deeply in a
dark theme. See the [0.5.0 release notes](doc/release-0.5.0.md).

Version **0.4.0** draws the native `LiquidGlassSurface` material with a
package-owned UIKit view, so a sheet no longer ends short of its content or misses
its glass on first layout. It adds content-sized sheets
(`showLiquidGlassSheet(fitContent: true)`), the `LiquidGlassActionBar` action row
and an optional button `id`, and draws a disabled `prominent` button like any
other disabled button. See the [0.4.0 release notes](doc/release-0.4.0.md) and the
[native surface validation](doc/native-surface-validation.md).

Version **0.3.0** refines alert/action-sheet layouts, native content clipping,
fallback calendar and slider behavior, and out-of-range handling. Menus and
popovers gain opt-in `fitContent` sizing. Native action sheets no longer slide
through the bottom safe area, keeping the cancel group's glass full height.
See the [0.3.0 release notes](doc/release-0.3.0.md) for changes and validation scope.

Version **0.2.0** expands the package to 21 UI capabilities, with package-owned
frosted fallbacks, optional long-press actions and configurable interaction feedback.
See the [release notes](doc/release-0.2.0.md) and
[upgrade notes](#upgrading-from-011). The
[release validation record](doc/release-validation.md) separates native system-input
checks, platform coverage and remaining physical-device acceptance.

The **0.2.1** patch fixes native navigation action labels, color-well accessibility
and presentation, queued-event cancellation and native slider editing cycles.
Fallback color wells also expose semantic activation. See its
[release notes](doc/release-0.2.1.md) and
[native accessibility validation](doc/native-accessibility-validation.md).

**Known validation limit:** some hosted iOS 26.5 runs fail to display the system
color palette after its first real tap. A standalone UIKit app reproduces the
failure both with and without a Simulator window. The cause is unresolved;
0.6.0 does not claim to fix that first-use failure or prove hardware is unaffected.
The 0.3.0 selected native run passed 9/10 cases and reproduced this failure;
publication explicitly accepts that known limitation. See the
[0.3.0 release decision](doc/release-0.3.0.md#validation-and-accepted-release-limitation).
From 0.5.0 the native CI gate skips a palette case whose first palette does not
appear, keeps every later palette strict, and fails if every palette case was
skipped; see the
[gate decision](doc/native-accessibility-validation.md#first-use-skip-in-the-gate-from-050).

## Installation

```sh
flutter pub add flutter_adaptive_liquid_glass
```

Or add the version to your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.6.0
```

Requires Flutter 3.41.2 or later and Dart 3.11 or later. Supported platforms are
Android and iOS 16+. Native system glass is available on iOS 26+; older iOS and
Android use the Flutter fallback. Build native iOS glass with Xcode 26 or later.
With Swift Package Manager, set the app's iOS Deployment Target to 16.0 or later
(`flutter create` sets 15.0); otherwise Xcode reports a Target Integrity error
that the package product requires minimum platform version 16.0.
On iOS the plugin supports both Swift Package Manager and CocoaPods. Flutter uses
Swift Package Manager when it is enabled, the default from Flutter 3.44, and
CocoaPods otherwise. Development uses Flutter **3.41.9** / Dart **3.11.5**; CI
checks that pinned version and the current stable channel. The package has no
production dependency besides the Flutter SDK: every native control, including
the tab bar, the segmented control and icon buttons, is a package-owned UIKit
bridge. It does not require a global toolchain upgrade.

### Upgrading from 0.5.x

Change the constraint to `^0.6.0`; in a 0.x version `^0.5.x` does not select
0.6.0 automatically. Run `flutter pub get`, then perform a full native rebuild so
the removed `native_liquid_glass` pods and packages leave the app. With Swift
Package Manager, set the app's iOS Deployment Target to 16.0 or later. The
existing APIs remain available. Visible changes that need no code:

- A tab icon given only as `IconData` is drawn at the bar's symbol size and the
  screen's pixel ratio instead of covering the selected tab.
- An icon-only native button with a long press, including the default trigger
  of an icon-only `LiquidGlassMenuButton`, looks like one without.
- Native buttons, groups, the tab bar and the segmented control follow Flutter's
  `Directionality` instead of the device language.
- A navigation bar with a disabled action keeps the system navigation bar.
- The iOS home indicator follows the system default and can appear where it
  stayed hidden before; see the [0.6.0 release notes](doc/release-0.6.0.md).

The `disableAnimations` argument of `LiquidGlassThemeData.resolve` is deprecated;
it never affected the result. From 0.5.0 or 0.5.1, note also that 0.5.2 made
native symbols smaller and the segmented control wider, and fallback slider and
switch thumbs white in a dark theme; pass `iconSize` where a symbol must keep a
particular size.

### Upgrading from 0.4.x

Change the constraint to `^0.6.0`, run `flutter pub get`, and rebuild the native
app, reading the 0.5.x notes above as well. The existing APIs remain available and every new parameter is optional. Two
visible changes need no code: a native capsule title that does not fit ends with
an ellipsis instead of being clipped, and in a dark theme alerts and sheets dim
the page with 48% black instead of 20%; pass `barrierColor` to keep the old scrim.

### Upgrading from 0.3.x

Change the constraint to `^0.6.0`, run `flutter pub get`, and rebuild the native
app, reading the 0.5.x and 0.4.x notes above as well. The existing APIs remain available; sheet `fitContent`, `LiquidGlassActionBar`
and `LiquidGlassButton.id` are new and optional. Two visible changes need no code:
the native `LiquidGlassSurface` material is now a package-owned UIKit view with
the same radius, tint and fill, and a disabled `prominent` button is drawn like
any other disabled button instead of as a solid accent fill. Native buttons keep
the accessibility identifier `button` unless an `id` is given.

### Upgrading from 0.2.x

Change the constraint to `^0.6.0`, run `flutter pub get`, and rebuild the native
app, reading the 0.5.x, 0.4.x and 0.3.x notes above as well. The existing APIs and defaults remain
available; `fitContent` is opt-in.
Two-action alerts now use a horizontal row when text size permits, and action
sheets keep cancel actions in a separate group. Native action sheets retain
fading and subtle scaling without sliding; Flutter fallbacks continue to slide.

### Upgrading from 0.1.1

Change `^0.1.1` to `^0.6.0`, run `flutter pub get`, then perform a full native
rebuild. Dart's `^0.1.1` constraint does not select later minor versions automatically.
Keep the existing `LiquidGlassAppearance` and `LiquidGlassNavigatorObserver`
installation. Existing surfaces, buttons, shared capsules, tabs, segments,
appearance settings and color-token APIs remain available; their controlled
selection and callback contracts are retained.

New `onLongPress` callbacks are optional. Package haptic and sound permissions
default to enabled, so existing Flutter controls can now provide the platform
feedback described [below](#interaction-feedback-and-long-press). Applications
that need silent package interactions can set
`feedback: const LiquidGlassFeedbackData(haptics: false, sound: false)`.
This does not suppress feedback owned by native controls or the Material calendar.

The new `LiquidGlassMenuButton` default trigger supports both tap and long press.
Use `trigger: LiquidGlassMenuTrigger.tap` for tap-only menus, or `.longPress`
for hold-only menus. A custom menu builder continues to own its gestures.

### Local checkout integration

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

// Keep this observer in the owning State; dispose it with that State.
final glassObserver = LiquidGlassNavigatorObserver();

MaterialApp(
  navigatorObservers: [glassObserver],
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
and native title measurement own their layout, replacing the earlier SwiftUI
path that compressed Chinese titles even with an explicit platform-view width.
The Flutter estimate prevents first-frame collapse; UIKit's intrinsic content
width can enlarge it, never shrink it. Icon-only buttons use the same capsule
bridge in a standalone look, with or without a long-press action: a semibold
symbol, or the Material glyph trimmed to the icon size, in colors that do not
change when pressed or disabled. Their `id` is the native accessibility
identifier and their `semanticLabel` the native label. A button, and each
action of a button group, toolbar or action bar, keeps its native view when it
is enabled or disabled or its emphasis or colors change; a new title, icon or
long-press action, or added, removed or reordered actions, create a new one.
Native capsules, tab bars and segmented controls follow the ambient
`Directionality`, not the device language. Every path retains native materials
and app appearance.

## Component catalog

The package covers 22 UI capabilities. Icon buttons are a constructor variant;
alert and action sheet are two styles of the same helper, and
`LiquidGlassActionBar` composes the button and the shared capsule without a
rendering path of its own. See the
[component coverage matrix](doc/component-coverage.md) for individual rendering
paths, constraints and regression sources.

| Family | Public API |
| --- | --- |
| Surfaces and actions | `LiquidGlassSurface`, `LiquidGlassButton`, `LiquidGlassButton.icon`, `LiquidGlassButtonGroup`, `LiquidGlassActionBar` |
| Navigation and grouping | `LiquidGlassNavigationBar`, `LiquidGlassTabBar`, `LiquidGlassSegmentedControl<T>`, `LiquidGlassToolbar`, `LiquidGlassScrollEdgeEffect` |
| Values | `LiquidGlassSlider`, `LiquidGlassSwitch`, `LiquidGlassStepper` |
| Status | `LiquidGlassActivityIndicator`, `LiquidGlassProgressView` |
| Picking | `LiquidGlassDatePicker`, `LiquidGlassColorPicker` |
| Search | `LiquidGlassSearchField`, `LiquidGlassSearchScaffold` |
| Presentations | `LiquidGlassMenuButton<T>`, `showLiquidGlassAlert<T>`, `showLiquidGlassSheet<T>`, `showLiquidGlassPopover<T>` |

### Controlled values and search

Value controls do not own application state. Accept an edit by rebuilding with
the new value; a null `onChanged` disables the control. Programmatic updates do
not emit change callbacks. Native bridges reconcile unaccepted edits to the
value supplied by the caller.

```dart
LiquidGlassSlider(
  value: volume,
  divisions: 10,
  semanticLabel: 'Volume',
  onChanged: (value) => setState(() => volume = value),
);

LiquidGlassStepper(
  value: quantity,
  min: 1,
  max: 12,
  step: 1,
  semanticLabel: 'Quantity',
  onChanged: (value) => setState(() => quantity = value),
);
```

Sliders require a finite value in a finite, nonempty range and positive
`divisions`, when specified. Steppers require a positive `step`; passing a bound
clamps to it, or wraps to the opposite bound with `wraps: true`. The fallback
supports press-and-hold repetition. Progress is determinate, from 0 to 1.
Status indicators do not add another glass layer behind their content. On the
native path, package-owned bridges use `UIActivityIndicatorView` and
`UIProgressView`. Progress, animation and color updates retain the UIKit instance;
configuration is reapplied after creation and native visibility participates in
nested popup suppression.

`LiquidGlassToolbar(groups: [...])` takes groups of `LiquidGlassAction`. Each
group shares one capsule; distinct groups retain spacing and can scroll
horizontally when constrained. Supply stable action IDs and accessible labels.

`LiquidGlassSearchField` keeps editing in a Flutter `TextField`, including
selection and IME composing state. Supplied `TextEditingController` and
`FocusNode` objects remain caller-owned; dispose them in their owning State.
`onChanged` is immediate: debouncing, requests and results belong to the app.
Clear empties the draft and invokes `onChanged('')` and `onClear`; Cancel removes
focus and invokes `onCancelled` without clearing the draft.

`LiquidGlassSearchScaffold` accepts a caller-owned `body`, `searchResults`,
`searchController`, selected tab and controlled `searchActive` state. It retains
the body while results are shown and hides bottom tabs while the keyboard is
visible. It does not create a Navigator. Use your existing router or an
`IndexedStack` for independently retained tab pages.

### Date and color pickers

```dart
LiquidGlassDatePicker(
  value: scheduledAt,
  mode: LiquidGlassDatePickerMode.dateAndTime,
  style: LiquidGlassDatePickerStyle.compact,
  minuteInterval: 5,
  onChanged: (value) => setState(() => scheduledAt = value),
);

LiquidGlassColorPicker(
  selectedColor: accent,
  supportsAlpha: true,
  semanticLabel: 'Accent color',
  onChanged: (value) => setState(() => accent = value),
);
```

Date pickers support `date`, `time` and `dateAndTime` modes, with `compact`,
`inline` and `wheels` styles. Native rendering uses `UIDatePicker`; the compact
fallback opens a sheet containing the Material calendar and package-owned time
wheels. Wheel labels, date order and 12/24-hour formatting reuse SDK localization
resources; no Cupertino picker or theme is instantiated. Install your
app's `flutter_localizations` delegates for supported locales. A picker `locale`
override does not install localization delegates by itself.

All dates are displayed in the device's **local calendar**, including UTC input.
Callbacks preserve the input's UTC/local representation: UTC input returns UTC
output. Date-only edits preserve the existing local time, including seconds and
subseconds; time-only edits preserve the existing local date. Time modes clear
seconds and use a minute grid. Supported `minuteInterval` values are
`1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30`.

Date-only bounds compare local calendar dates. Time-mode lower bounds round up
and upper bounds round down to selectable minutes; time-only selection is also
limited to the input's local day. Empty ranges, unsupported intervals and local
years outside 1–9999 fail explicitly. Normalizing a displayed value does not emit
a callback. Calendar reconstruction follows Dart/platform local-time rules,
including daylight-saving transitions; this is not a named-time-zone API.

Colors are controlled **sRGB** values. The fallback sheet has RGB/alpha sliders
and HEX editing; native rendering uses `UIColorWell` and the system picker.
With an explicit `semanticLabel`, physical and accessibility activation share
one package-owned `UIColorPickerViewController` presentation. Unlabeled native
wells retain UIKit's default interaction and accessibility behavior.
HEX accepts `RRGGBB` or `RRGGBBAA`, optionally prefixed with `#`; alpha is last,
unlike Dart's integer `AARRGGBB` notation. Invalid HEX does not emit an edit.
The fallback sheet's English text can be replaced: `hexLabelText` and
`hexErrorText` replace the HEX field's label and error, and
`channelSemanticFormatterCallback` the values that screen readers announce for
the R, G, B and A sliders. Without `semanticLabel` or `title`, the fallback
well is labelled `Color`.
`supportsAlpha: false` hides alpha editing and emits opaque colors. Changes are
continuous; closing is not a rollback or a second commit. Maintain a separate
draft if the application needs explicit confirmation.

### Button details, subtitles and scroll edges

A button can carry a quieter detail after its label, a coloured mark and the
platform's pop-up indicator. On iOS 26 they map to the native button's title,
image and indicator, so the native press effect is kept; a native title that
does not fit ends with an ellipsis and its accessibility label stays whole.

```dart
LiquidGlassButton(
  label: 'Studio',
  detail: 'Online',
  sfSymbol: 'circle.fill',
  icon: Icons.circle,
  iconColor: Colors.green,
  iconSize: 10,
  menuIndicator: true,
  onPressed: openSwitcher,
);
```

`LiquidGlassMenuButton` passes the same options to its default trigger, and
`LiquidGlassNavigationBar(subtitle: ...)` shows a second line under the title,
the navigation item's own subtitle on iOS 26.

iOS 26 softens content where it scrolls beneath floating bars, but only for
`UIScrollView`. `LiquidGlassScrollEdgeEffect` draws that effect for Flutter
scrollables in every mode: a progressive blur fading into the page colour
(`soft`), or an opaque band with a hairline (`hard`, also used when
transparency is reduced). An edge appears only while content is beneath it.

```dart
Scaffold(
  extendBodyBehindAppBar: true,
  appBar: const LiquidGlassNavigationBar(title: 'Files', subtitle: 'Workspace'),
  body: LiquidGlassScrollEdgeEffect(
    top: MediaQuery.paddingOf(context).top + 80,
    bottom: 96,
    child: ListView(padding: listPadding, children: rows),
  ),
);
```

Alerts and sheets dim the page with 20% black in a light theme and 48% in a
dark one; pass `barrierColor` to choose another scrim.

`LiquidGlassTabBar(trailingAction: ...)` adds a separate round button after the
tabs, the native search-style item on iOS 26. With
`LiquidGlassSearchScaffold(searchPlacement: LiquidGlassSearchPlacement.tabBar)`
that button starts search, and the field docks at the bottom above the keyboard
with a close button until search ends.

### Menus and typed presentations

```dart
LiquidGlassMenuButton<String>(
  label: 'More',
  items: const [
    LiquidGlassMenuItem(value: 'copy', label: 'Copy', icon: Icons.copy),
    LiquidGlassMenuItem(
      value: 'organize',
      label: 'Organize',
      children: [
        LiquidGlassMenuItem(value: 'archive', label: 'Archive'),
        LiquidGlassMenuItem(
          value: 'delete',
          label: 'Delete',
          destructive: true,
        ),
      ],
    ),
  ],
  onSelected: handleAction,
);

final result = await showLiquidGlassSheet<String>(
  context: context,
  initialDetent: LiquidGlassSheetDetent.medium,
  builder: (sheetContext) => ListView(
    primary: true,
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Choose an option'),
      LiquidGlassButton(
        label: 'Done',
        onPressed: () => Navigator.of(sheetContext).pop('done'),
      ),
    ],
  ),
);
```

Menu values must be stable and unique across the whole item tree. Items expose
`enabled`, `destructive`, `selected`, `icon` and nested `children`. Opening takes
a snapshot of the tree; only leaf selection returns a value. Independent menu
buttons own their anchors and presentation state. `onCanceled` distinguishes a
dismissal from `onSelected`.

`showLiquidGlassAlert<T>` takes a list of `LiquidGlassAlertAction<T>` with
`label`, `value`, `enabled`, `destructive`, `cancel` and optional `icon`. Choose
`LiquidGlassAlertStyle.alert` or `.actionSheet`. Cancel actions return null,
regardless of their supplied value.

All presentation helpers return `Future<T?>`; cancellation returns null, and
`Navigator.of(popupContext).pop(value)` returns a typed result. They use Flutter
`PopupRoute` content over adaptive glass, rather than hosting arbitrary Flutter
widgets inside a UIKit alert or sheet controller. They default to the root
Navigator; use `useRootNavigator: false` for the nearest Navigator, and install a
`LiquidGlassNavigatorObserver` on the chosen Navigator.

Sheets accept an ordinary `WidgetBuilder`, medium/large `detents`, an
`initialDetent` included in that list, `enableDrag`, `showDragHandle` and
`barrierDismissible`. For coordinated content scrolling and detent dragging,
the builder's **one primary vertical scroll view** must use `primary: true` or
`PrimaryScrollController.of(sheetContext)`. An unrelated scroll controller cannot
coordinate sheet expansion. Non-scrolling content can still use the drag handle.
The route applies keyboard and safe-area constraints.

Pass `fitContent: true` for a sheet that is only as tall as its content, up to
the large detent, instead of one that opens at a detent; `detents` and
`initialDetent` do not apply. As in a modal bottom sheet, the content is laid out
with a bounded height and decides its own size, so use a `Column` with
`mainAxisSize: MainAxisSize.min` and give anything that can outgrow the sheet its
own scrolling (`ListView(shrinkWrap: true)`, or a `SingleChildScrollView` in a
`Flexible`). The builder still receives a `PrimaryScrollController`. There are no
intermediate stops: the handle pulls the whole sheet down, and releasing it a
quarter of the way down, or with a quick downward flick, dismisses the sheet.

```dart
final saved = await showLiquidGlassSheet<String>(
  context: context,
  fitContent: true,
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Rename session'),
        const TextField(),
        LiquidGlassActionBar(
          actions: [
            LiquidGlassAction(
              id: 'cancel',
              label: 'Cancel',
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
            LiquidGlassAction(
              id: 'save',
              label: 'Save',
              onPressed: () => Navigator.of(sheetContext).pop('saved'),
            ),
          ],
        ),
      ],
    ),
  ),
);
```

`LiquidGlassActionBar(actions: [...])` is the action row of a sheet or form. The
last `LiquidGlassAction` is the one the form exists for, so it becomes a
prominent button at the trailing edge; any earlier actions share one glass
capsule at the leading edge. When both do not fit on one line, as with large text
on a narrow screen, they stack at the trailing edge, and the capsule scrolls
sideways if it still cannot fit. A disabled `prominent` button, including the
bar's last action, is drawn like any other disabled button until it can be
pressed, rather than as a solid accent fill under a faded label. Action IDs
become widget keys and the accessibility identifiers of the native buttons, which
are platform views that Flutter finders cannot press; UI tests find them by
identifier. `padding` is the space around the buttons; the bar always keeps 8
points above, below and before the capsule for its shadow.

`showLiquidGlassPopover<T>` requires `anchorContext` and `builder`, and accepts
`width`, `maxHeight`, `gap`, `fitContent` and `barrierColor`, which replaces its
8% black scrim. Keep the anchor mounted while presented. The popover is exactly `width` wide unless `fitContent` is set; it then
takes the content's intrinsic width between 160 and `width` (`LiquidGlassMenuButton`
accepts the same flag). It scales from the anchor edge it is attached to. The
popover follows layout changes, flips/clamps within available keyboard-safe
space and dismisses when its anchor is removed. Nested presentation, replacement
and removal keep underlying native views hidden until the outgoing route's
transition finishes. Locally scoped themes are captured when opening; place a
live application-wide theme above the Navigator for global appearance updates.

## Interaction feedback and long press

The fallback slider, switch, stepper buttons, date wheels and activity indicator
are package-owned implementations. They use Flutter drawing, gestures, focus,
semantics and scrolling rather than Cupertino control widgets. Date wheels still
reuse the SDK's localized labels and date order. The inline Material calendar and
Flutter text editors remain in use; native iOS controls keep their system behavior.

```dart
LiquidGlassTheme(
  data: const LiquidGlassThemeData(
    feedback: LiquidGlassFeedbackData(haptics: true, sound: false),
  ),
  child: LiquidGlassButton(
    label: 'Preview',
    onPressed: openPreview,
    onLongPress: showDetails,
    longPressSemanticLabel: 'Show details',
  ),
);
```

Both feedback permissions default to `true`, following platform conventions;
they do not mean that every click vibrates. Android button activation uses its
system click sound, while ordinary iOS button clicks add no haptic or sound.
Recognized long presses use platform long-press feedback. Package-owned discrete
selections provide selection feedback; continuous sliders only give haptics at
endpoints. Date-wheel changes use selection feedback and an iOS system tick.
Stepper holds confirm once and then repeat silently every 100 ms. Programmatic
updates, unchanged selections and cancelled gestures do not generate new feedback.

`LiquidGlassFeedbackData.copyWith` independently changes haptic and sound
permissions. Use a nested theme to override a subtree. The flags govern only
feedback explicitly sent by this package: native system controls and the retained
Material calendar may provide feedback of their own. No custom audio assets,
private sound identifiers or device-setting overrides are used. Reduced motion
controls visual animation independently of these permissions.

Buttons, icon buttons and `LiquidGlassAction` accept `onLongPress` and an optional
`longPressSemanticLabel`. A long-only action is enabled; loading or two null
callbacks disables both interactions. Holding activates once, and releasing the
same gesture does not also click. Shared capsules keep independent action targets.
Only the stepper repeats. Scroll takeover, leaving the target, route coverage,
backgrounding and disposal cancel applicable pending gestures.

Alerts with exactly two actions place them side by side (a cancel action first)
unless text is large; action sheets show their cancel actions as a separate group.
`LiquidGlassMenuButton.trigger` accepts `LiquidGlassMenuTrigger.tap`, `.longPress`
or `.tapAndLongPress` (the default). A custom `builder` keeps the existing
`(context, open)` signature and owns its gestures. Each default trigger supports
only one open menu at a time, and remains usable after cancelling or selecting.

Native icon buttons with long-press actions use the package's UIKit capsule.
Navigation bars containing these actions combine the existing Flutter title
layout with native capsules. System iOS 26+ tabs are unchanged. Haptic strength,
audibility and assistive-technology experience still need physical-device
acceptance; test channel counts and simulator gestures are not substitutes.

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
scheme or supply individual color tokens. The component catalog's optional teal
palette and the material probe's Neutral, Blue and Green choices are demonstration
presets only. Neutral keeps the original unbranded appearance; seed examples
generate separate light and dark schemes.

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

The table applies to adaptive surfaces and controls. Search fields and popup
contents retain Flutter editing, layout and routing in every mode; their
backgrounds follow the material policy. Value controls use the applicable UIKit,
SwiftUI or package-owned Flutter control instead of adding a glass wrapper to
every element.
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

## Native rendering and overlays

Every native control is a package-owned UIKit bridge; no third-party native
package is involved. The tab bar is a system `UITabBarController` built with
`UITab`, with text and dot badges; a `trailingAction` is a `UISearchTab`, which
UIKit draws as the separate round button and which is the prominent tab on
iOS 27. The segmented control is a `UISegmentedControl` exactly as wide as the
control. Icon buttons use the same glass capsule as text buttons. The native
material behind `LiquidGlassSurface` is a UIKit view too, because a SwiftUI glass
container does not keep its shape in step with the safe area while a sheet slides
in. `liquidGlassNativeAvailable` is synchronous and valid on the first frame: it
is true when the target platform is iOS and the iOS major version is 26 or later.
It does not read `UIDesignRequiresCompatibility`.

Install a separate `LiquidGlassNavigatorObserver` on every Navigator that presents
popup routes. Dispose it when discarding a Navigator. Covered routes retain their
native widgets' layout and state but exclude them from Flutter painting, hit testing
and semantics until the popup's exit transition completes. Merely making a UIKit
view transparent is insufficient: its platform-view rectangle can still participate
in composition and clip the Flutter content of a mixed native/Flutter popup.
The observer tracks nested coverage across navigator boundaries and balances
removal, replacement and disposal. Flutter children of `LiquidGlassSurface` remain
painted while only its native material is excluded. No plugin cache edits or
whole-page fallback are required. As an additional occlusion guard, the observer
also tells the plugin when the first popup appears and the last one leaves, over
the package's own lifecycle channel, and native views beneath it hide in UIKit.
Custom `OverlayEntry` presentations are not Navigator routes: stop painting the
underlying native controls while such an overlay is active. Changing themes does
not remove the native tab platform view. Verify system materials on iOS hardware.

`NavigationBar` retains its existing Flutter layout conditions when an action
is disabled or its IconData lacks an SF Symbol. Basic icon-only navigation should
supply both. The supported native layout uses a package-owned `UINavigationBar`
bridge and announces each action's business label. UIKit retains the system
material and bar-button rendering.

## Performance

On iOS 26 each native control is its own platform view (`UiKitView`): every
button or button-group capsule, segmented control, slider, switch, stepper, date
picker, color well, progress or activity indicator and native
`LiquidGlassSurface` material, as well as the navigation bar and the tab bar.
Flutter composites each platform view separately, so many of them cost more GPU
time and memory than the same number of Flutter widgets. A list or settings page
with a switch on every row creates a UIKit switch for every row that is built.
The Flutter fallback has no platform views, but every fallback surface,
including the one behind each non-prominent button, segmented control, stepper
and color well, applies its own background blur. No hardware GPU, frame-time or
memory profile has been recorded for either path.

Keep glass on navigation and floating controls. Give a long list, a form or a
settings page the Flutter controls, keeping the app's colors and feedback:

```dart
LiquidGlassTheme(
  data: LiquidGlassTheme.of(context).copyWith(mode: LiquidGlassMode.fallback),
  child: ListView(children: settingsRows),
)
```

`LiquidGlassMode.opaque` costs less still: its solid surfaces have no blur. The
tab bar stays native on iOS 26 in every mode (see
[Rendering policy](#rendering-policy)). Profile pages that combine many native
controls in profile mode on a device.

## Known limitations

- Native glass needs iOS 26 or later; older iOS versions and Android use the
  Flutter approximation. The package declares only Android and iOS: web and
  desktop should take the fallback path but are neither declared nor tested.
- The package builds on Material. Presentations, search and pickers read
  `MaterialLocalizations`, so use a `MaterialApp` or install the Material
  localization delegates; a `CupertinoApp` alone is not enough. Fallback
  controls draw Material icons: keep `uses-material-design: true` in the app's
  pubspec.
- A few defaults are English: the fallback color sheet's HEX label, HEX error
  and channel values (see [Date and color pickers](#date-and-color-pickers)) and
  the slider's percentage value, which `semanticFormatterCallback` replaces.
- Some native controls switch to Flutter rendering without notice: buttons
  while `loading` and fixed-height controls at large text sizes, and the
  navigation bar unless it has at most one leading and one trailing action,
  without long presses and with an `sfSymbol` beside every icon. Native
  sliders, switches and steppers stay native at every text size.
- iPad, landscape and Split View have not been validated. The tab bar has no
  sidebar form, and sheets are at most 640 points wide.
- In simulator UI tests a slow drag on the native slider can end about 20 points
  behind the finger: the movement before Flutter's drag gesture passes its touch
  slop does not reach UIKit. Not yet confirmed on a device; a later release is
  planned to fix it.
- On iOS 26 the tab bar is empty for its first frame while its icons are
  prepared.
- `liquidGlassNativeAvailable` reads only the iOS major version and ignores
  `UIDesignRequiresCompatibility`. Custom `OverlayEntry` presentations do not
  hide native views (see [Native rendering and overlays](#native-rendering-and-overlays)).
- Some hosted iOS 26.5 simulator runs do not show the system color palette after
  its first real tap (see the note at the top). Physical haptics and sound, full
  VoiceOver/TalkBack and keyboard/IME acceptance, and hardware rendering and
  performance have not been verified (see [Validation](#validation)).

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

To build the example with Swift Package Manager (the default from Flutter
3.44), name the checkout directory `flutter_adaptive_liquid_glass`, for example
`git clone https://github.com/starroyhq/flutter-adaptive-liquid-glass flutter_adaptive_liquid_glass`.
Flutter adds the plugin's Swift package to the example's Xcode project as a
local override, and the two package identities must match; CI checks out the
repository the same way. Apps that use the package from pub.dev or through a
path dependency are not affected.

The independent example contains iOS/Android host projects and opens
`ComponentCatalogApp` by default, with Controls, Pickers, Popups and Search pages.
Its Appearance action changes rendering mode, system/light/dark appearance,
custom color, reduced motion and reduced transparency. The original material and
mixed-modal probes remain available through compile-time flags. See
[example acceptance steps](example/README.md), the
[coverage matrix](doc/component-coverage.md), the
[component validation record](doc/component-validation.md) and
[interaction validation record](doc/interaction-validation.md).
The recorded local checks include Android 15, iOS 18.6 and iOS 27 simulator
integration runs; they are separate from release CI and publication status.
Normal-duration native slider input is covered by the dedicated XCTest scheme.
The iOS 26 CI gate runs that scenario on an actual iOS 26 simulator; it does not
represent a complete interactive sweep of every control on that OS. Physical
haptic and sound behavior, full VoiceOver/TalkBack and keyboard/IME acceptance,
and hardware rendering/performance remain outside simulator validation. See the
[release validation record](doc/release-validation.md) for the executed scope.

## License

Released under the [MIT License](LICENSE). Attribution for adapted code is in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Continuous integration

The `Component checks` workflow is configured for pushes, pull requests and manual dispatch.
Its main jobs pin Flutter 3.41.9, enforce the root/example lockfiles, format and
analyze both, and run both test suites. After quality passes, separate jobs build the
example Debug APK (Java 17) and an arm64 iOS simulator application (macOS 26).
The iOS job generates Flutter configuration, enforces `Podfile.lock`, then invokes
`xcodebuild` directly to avoid the toolchain's combined-architecture parsing issue;
it builds the plugin through CocoaPods.
An additional arm64 job boots its own iOS 26 simulator and runs the
`NativeSliderAcceptance` XCTest scheme using normal-duration system input. It
requires an installed iOS 26 runtime rather than substituting a newer version.
Two more jobs follow the current stable channel. `quality-stable` analyzes and
tests both packages; it resolves dependencies without `--enforce-lockfile`
because the SDK packages that `flutter_test` pins change with every Flutter
release. `ios-simulator-stable` then builds the same arm64 simulator application
with Swift Package Manager, the default from Flutter 3.44, and fails unless the
plugin and its privacy manifest come from the Swift package. These jobs upload
no artifacts and, like the others, must pass for a release run.
The APK, archived simulator `.app` and native XCTest result bundle are retained
for 14 days. Build success does not establish native animation, IME,
accessibility or GPU performance. The separate Flutter integration scenarios
are runnable locally; CI formats/analyzes those sources but does not run that
suite on a device. Configuration is not evidence of a successful run for a
release commit. See the
[component validation record](doc/component-validation.md) and
[interaction validation record](doc/interaction-validation.md) for executed checks;
[fallback validation](doc/fallback-validation.md) preserves the earlier release's
validation record.

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

For 0.3.0 only, the maintainer accepted the recorded native first-use failure.
Its example artifacts are transferred manually from the successful build jobs
with the same identity and digest checks, plus published provenance. The normal
workflow and test assertions are unchanged. See the
[explicit release decision](doc/release-0.3.0.md#validation-and-accepted-release-limitation).

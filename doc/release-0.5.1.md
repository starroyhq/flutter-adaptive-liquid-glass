# flutter_adaptive_liquid_glass 0.5.1

This patch lets an action in a button group, a toolbar or the leading capsule of
an action bar show its label after its icon, as in a "Save" or "Share" toolbar.
The new parameter is optional and off by default, so existing groups look the
same. There are no new production dependencies or toolchain upgrades.

```yaml
dependencies:
  flutter_adaptive_liquid_glass: ^0.5.1
```

Run `flutter pub get` and rebuild the native app. Flutter 3.41.2+, Dart 3.11+,
iOS 16+ and Android remain supported; native glass requires iOS 26+.
`native_liquid_glass` stays pinned to 0.3.1.

## Changes

- `LiquidGlassAction` takes `showLabel`. In a `LiquidGlassButtonGroup`, and so
  in a `LiquidGlassToolbar` and the leading capsule of a `LiquidGlassActionBar`,
  an action that sets it shows its label after its icon; without it an action
  with an icon still shows only the icon and the label stays its accessibility
  label and tooltip. On iOS 26 the native capsule item gets the label as its
  title beside the image, the same button configuration a standalone
  `LiquidGlassButton` with an icon and a label uses. The fallback draws the icon,
  an 8-point gap and the label. The accessibility label is unchanged and the
  visible label is not announced twice.
- Navigation and tab bars keep showing an icon or a label, never both: the
  native bar items cannot show both, and the fallback navigation bar drops the
  option so both modes match.
- The example app's `GLASS_NEW_CONTROLS` page has a toolbar with labelled
  actions.

## Validation

The source passed `dart format`, analysis of the package and the example, 309
package tests (5 new: fallback layout and semantics, width, toolbar and action
bar, navigation bar, native creation parameters) and 8 example tests.
`pod install` for the example passed; `dart pub publish --dry-run` reported only
the known warning about the pinned `native_liquid_glass` version.

The `GLASS_NEW_CONTROLS` example page was inspected from screenshots on an iOS
26.5 simulator with native glass and on iOS 18.6 with the fallback, in light and
dark appearance: a group whose first action shows its label and whose second
stays icon-only, and a group of two labelled actions, each in its own toolbar
row.

The gating `Component checks` run for the tagged commit, including the native
iOS 26.5 interaction job, is linked from the GitHub release.

## Known validation limits

The independent first-use system color-palette failure recorded for 0.2.1 remains
unresolved in some hosted iOS 26.5 runs; this release does not touch that path.
Physical devices and large text were not checked for labelled actions; at large
text sizes a group uses the Flutter-drawn capsule on every platform, which widget
tests cover.

# flutter_adaptive_liquid_glass 0.9.1

Prominent glass buttons now carry their resolved Flutter foreground to UIKit.
A light accent such as `#f5f5f7` in a dark theme can pair with a dark
`ColorScheme.onPrimary`, including on icon-only and loading buttons.

## Upgrading from 0.9.0

Run `flutter pub upgrade flutter_adaptive_liquid_glass` and perform a full
native rebuild. A `^0.9.0` dependency constraint already admits 0.9.1.

An enabled or loading prominent button uses `LiquidGlassColors.onAccent`
when supplied and otherwise uses `ColorScheme.onPrimary`. To set the
foreground for a single button, pass `foregroundColor` to
`LiquidGlassButton` or `LiquidGlassButton.icon`. An `iconColor` still
overrides the color of the glyph. A disabled, non-loading button uses
the regular glass appearance with its neutral foreground.

UIKit still draws the glass and handles interactions. The same theme
foreground resolves on the Flutter fallback. Default menu buttons and
navigation actions use their regular glass appearance.

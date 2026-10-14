# Native surface and safe-area validation

This records why `LiquidGlassSurface` draws its native material with a
package-owned UIKit view, how the difference was measured, and what the
measurements do not establish. It is a validation record, not a claim about the
provider's behaviour on every device.

## Symptom

A sheet is created below the screen and slides up. When its panel used the
provider's `LiquidGlassContainer` (a `UIHostingController` around a SwiftUI
glass shape), the glass sometimes did not match the panel's frame:

- the shape ended short of the panel's bottom edge, so the buttons inside hung
  out of it;
- the shape was absent in the first frames, so the sheet's text overlapped the
  page behind it.

Both went away after the sheet's height next changed, for example when an error
line appeared. The accessibility tree showed the platform view's frame at its
full size throughout; only the drawn glass was short.

The provider's SwiftUI root keeps SwiftUI's default safe-area behaviour. Its
sibling `LiquidGlassButtonGroupSwiftUI.swift` calls `.ignoresSafeArea()`; the
container does not. The package already worked around the same effect for native
action sheets in 0.3.0 by not sliding them (see `35d3d95`).

## Method

A throwaway integration test in a consuming app opened real sheets through the
public presentation helpers on an iOS 26.5 simulator (iPhone 17 Pro, Xcode 27,
Flutter 3.41.9), light appearance, and the host took simulator screenshots of the
first settled frame. The bottom edge of the panel was read from the screenshot on
a column between the buttons and compared with its resting edge, 840 pt on this
device (the safe-area boundary). Runs were repeated with the machine idle and
with twelve busy processes competing for the CPU, because the shortfall depends
on timing.

## Results

| Panel material | Condition | Panel bottom edge (expected 840 pt) |
| --- | --- | --- |
| Provider container, content-sized sheet | idle | 823 pt (17 pt short) |
| Provider container, content-sized sheet | loaded | 806 pt (34 pt short); an autofocused sheet had no panel in 3 of 3 runs |
| Provider container, package `showLiquidGlassSheet` | idle, 3 runs on 26.5, 1 on 27.0 | 830-834 pt (6-10 pt short; hidden by the footer padding) |
| Provider container patched with `.ignoresSafeArea()` | loaded, 3 runs | 840 pt, all frames present |
| Provider container patched with `hc.safeAreaRegions = []` | loaded, 3 runs | 840 pt, all frames present |
| Package-owned UIKit view | loaded, 3 runs | 840 pt, all frames present |
| Package-owned UIKit view, content-sized sheet (`fitContent: true`) | idle, 1 run | 839.7 pt |
| Package-owned UIKit view, content-sized sheet (`fitContent: true`) | loaded, 3 runs | 839.7 pt, all frames present |
| Package-owned UIKit view, default `showLiquidGlassSheet` (medium detent) | 2 runs while other builds kept the machine busy | 839.7 pt |

The package-owned view also rendered correctly in dark appearance on iOS 26.5
and in light appearance on iOS 27.0. Its material, radius, tint and fill match
the provider's panel by eye; no pixel comparison was made.

The two provider patches were applied to scratch copies of `native_liquid_glass`
0.3.1 and are not part of this package. Either would remove the cause in the
provider.

## Change

`LiquidGlassSurface` on iOS 26+ now uses `AdaptiveLiquidGlassSurface`: a
`UIVisualEffectView` with `UIGlassEffect`, and a plain fill view behind it, both
carrying the corner radius. It is plain UIKit, as the shared capsule is, so the
material is sized from the view's own bounds. Route coverage still hides it from
Dart (`NativeVisibility`), and it follows the provider's global popup suppression
unless it lives inside the popup.

## Consumer acceptance harness

The change swaps the material under every `LiquidGlassSurface`: alerts, action
sheets, menus, popovers and sheets. The acceptance host of the AgentKib Flutter
app (`tool/glass_acceptance_app.dart`, app commit `d1c531d`) was run through its
XCUITest classes on the same iOS 26.5 simulator, with the app built against a
snapshot of this change instead of the hosted 0.3.0.

| Class | Result |
| --- | --- |
| `RemotePageUITests` (1 test) | passed |
| `RemoteEmptyTabUITests` (1 test) | passed |
| `GlassInteractionUITests` (6 tests) | first run: 1 passed and 5 failed, all on waits that timed out (a stable frame, a hittable tab, a screenshot) while other builds saturated the machine, with test durations of 158-1237 s; the 5 rerun on the same build with the machine quiet all passed (73-216 s) |

The hosted 0.3.0 was not run for comparison. The first run's failures are
attributed to the load only because the identical build passed on rerun.

## Limits

- Simulators only, one device size. Physical devices were not measured.
- The consumer harness ran on iOS 26.5 only. The fallback path is unchanged by
  this change and was not rerun through it.
- The shortfall was measured in light appearance; dark appearance was inspected
  but not measured numerically.
- The cause is described from the observed behaviour, the provider's source and
  two patches that remove it. It has not been confirmed with the provider's
  maintainer.
- The provider's other SwiftUI-hosted views (the icon button, for instance) were
  not measured for the same effect.

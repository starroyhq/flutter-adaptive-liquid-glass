# Third-party notices

## native_liquid_glass 0.3.1

Source: https://github.com/tienanh306201z/native_liquid_glass
Package: https://pub.dev/packages/native_liquid_glass/versions/0.3.1
Archive SHA-256: `1df94e5998f7eb5fe57a8fff5228f9c9b1650f26aa6d6799b2c78dcc73f5261a`

This package no longer depends on native_liquid_glass. Portions of the
following files are adapted from its 0.3.1 source, and each carries a notice
saying so:

- `lib/src/native_tab_bar.dart`: the tab bar's payload, badge, selection and
  rollback logic.
- `lib/src/native_segmented_control.dart`: the segmented control's incremental
  updates.
- `lib/src/native_icon_raster.dart`: drawing an `IconData` glyph as a PNG.
- `lib/src/native_platform.dart`: detecting iOS 26 from the operating system
  version.
- `lib/src/navigator_observer.dart`: counting nested popups before hiding
  native views.
- `ios/flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/AdaptiveLiquidGlassTabBar.swift`:
  the embedded `UITabBarController`, its `UITab` construction and appearance.
- `ios/flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/AdaptiveLiquidGlassSegmentedControl.swift`:
  the segmented control's channel methods and selection animation.
- `ios/flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/AdaptiveLiquidGlassVisibility.swift`:
  fading hidden views out and in.
- `ios/flutter_adaptive_liquid_glass/Sources/flutter_adaptive_liquid_glass/AdaptiveLiquidGlassCapsule.swift`:
  trimming transparent edges from a glyph bitmap.

```text
MIT License
Copyright (c) 2026 Tran Tien Anh - alvatran306201z
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

flutter_adaptive_liquid_glass is separately licensed under the MIT License in
the repository's LICENSE file.

import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

/// [native] prefers system glass but still falls back on unsupported platforms.
enum LiquidGlassMode { auto, native, fallback, opaque }

@immutable
class LiquidGlassThemeData {
  const LiquidGlassThemeData({
    this.mode = LiquidGlassMode.auto,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.blurSigma = 18,
  }) : assert(blurSigma >= 0 && blurSigma <= 40);

  final LiquidGlassMode mode;
  final bool reduceTransparency;
  final bool reduceMotion;
  final double blurSigma;

  /// System navigation remains a native UITabBar on iOS 26+. Accessibility
  /// changes its backdrop/material, never replaces its interaction model.
  LiquidGlassMode resolveTabBar({required bool nativeAvailable}) =>
      nativeAvailable
      ? LiquidGlassMode.native
      : resolve(nativeAvailable: false);

  /// Accessibility takes precedence over a forced rendering preference.
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) {
    if (mode == LiquidGlassMode.opaque ||
        reduceTransparency ||
        reduceMotion ||
        highContrast ||
        disableAnimations) {
      return LiquidGlassMode.opaque;
    }
    if (mode == LiquidGlassMode.fallback) return LiquidGlassMode.fallback;
    return nativeAvailable ? LiquidGlassMode.native : LiquidGlassMode.fallback;
  }
}

class LiquidGlassTheme extends InheritedWidget {
  const LiquidGlassTheme({
    super.key,
    this.data = const LiquidGlassThemeData(),
    required super.child,
  });

  final LiquidGlassThemeData data;

  static LiquidGlassThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>()?.data ??
      const LiquidGlassThemeData();

  /// Returns the effective strategy, never [LiquidGlassMode.auto].
  static LiquidGlassMode modeOf(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return of(context).resolve(
      nativeAvailable: native.NativeLiquidGlassUtils.supportsLiquidGlass,
      highContrast: media?.highContrast ?? false,
      disableAnimations: media?.disableAnimations ?? false,
    );
  }

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) => data != oldWidget.data;
}

/// Platform support, without exposing the native provider's types.
bool get liquidGlassNativeAvailable =>
    native.NativeLiquidGlassUtils.supportsLiquidGlass;

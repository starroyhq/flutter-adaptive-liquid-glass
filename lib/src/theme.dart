import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'colors.dart';
import 'feedback_data.dart';
export 'colors.dart';
export 'feedback_data.dart';

/// [native] prefers system glass but still falls back on unsupported platforms.
enum LiquidGlassMode { auto, native, fallback, opaque }

@immutable
class LiquidGlassThemeData {
  const LiquidGlassThemeData({
    this.mode = LiquidGlassMode.auto,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.blurSigma = 20,
    this.colors = const LiquidGlassColors(),
    this.feedback = const LiquidGlassFeedbackData(),
  }) : assert(blurSigma >= 0 && blurSigma <= 40);

  final LiquidGlassMode mode;
  final bool reduceTransparency;
  final bool reduceMotion;
  final double blurSigma;
  final LiquidGlassColors colors;
  final LiquidGlassFeedbackData feedback;

  LiquidGlassThemeData copyWith({
    LiquidGlassMode? mode,
    bool? reduceTransparency,
    bool? reduceMotion,
    double? blurSigma,
    LiquidGlassColors? colors,
    LiquidGlassFeedbackData? feedback,
  }) => LiquidGlassThemeData(
    mode: mode ?? this.mode,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    blurSigma: blurSigma ?? this.blurSigma,
    colors: colors ?? this.colors,
    feedback: feedback ?? this.feedback,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassThemeData &&
          mode == other.mode &&
          reduceTransparency == other.reduceTransparency &&
          reduceMotion == other.reduceMotion &&
          blurSigma == other.blurSigma &&
          colors == other.colors &&
          feedback == other.feedback;

  @override
  int get hashCode => Object.hash(
    mode,
    reduceTransparency,
    reduceMotion,
    blurSigma,
    colors,
    feedback,
  );

  /// System navigation remains a native UITabBar on iOS 26+. Accessibility
  /// changes its backdrop/material, never replaces its interaction model.
  LiquidGlassMode resolveTabBar({required bool nativeAvailable}) =>
      nativeAvailable
      ? LiquidGlassMode.native
      : resolve(nativeAvailable: false);

  /// Transparency and contrast govern material; reduced motion is handled by
  /// animated controls without changing their material or native renderer.
  /// [disableAnimations] is accepted for source compatibility and never
  /// affects the result.
  LiquidGlassMode resolve({
    required bool nativeAvailable,
    bool highContrast = false,
    bool disableAnimations = false,
  }) {
    if (mode == LiquidGlassMode.opaque || reduceTransparency || highContrast) {
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

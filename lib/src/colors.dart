import 'package:flutter/material.dart';

/// Optional component colors, independent of light/dark appearance.
///
/// Unspecified values inherit the host [ColorScheme] and the package's neutral
/// material defaults. Custom foreground/background pairs require contrast
/// checks; the package cannot infer the intent of arbitrary supplied colors.
@immutable
class LiquidGlassColors {
  const LiquidGlassColors({
    this.surfaceTint,
    this.foreground,
    this.accent,
    this.onAccent,
    this.selection,
    this.selectedForeground,
    this.border,
    this.highlight,
    this.shadow,
  });

  /// Creates a coordinated palette from a host or seed-generated color scheme.
  /// Pass the scheme for the current brightness when following system appearance.
  factory LiquidGlassColors.fromColorScheme(ColorScheme scheme) =>
      LiquidGlassColors(
        surfaceTint: scheme.surface,
        foreground: scheme.onSurface,
        accent: scheme.primary,
        onAccent: scheme.onPrimary,
        selection: scheme.primaryContainer,
        selectedForeground: scheme.onPrimaryContainer,
        border: scheme.outlineVariant.withValues(alpha: .55),
        highlight: Colors.white.withValues(
          alpha: scheme.brightness == Brightness.dark ? .30 : .76,
        ),
        shadow: scheme.shadow.withValues(
          alpha: scheme.brightness == Brightness.dark ? .20 : .10,
        ),
      );

  /// Material tint. Fallback controls set its alpha to their protective material
  /// strength; native glass interprets it as a system tint. A surface's explicit
  /// `tint` takes precedence. Native tab/nav bars retain their system background.
  final Color? surfaceTint;

  /// Normal text and icons. Does not override styles explicitly set by children.
  final Color? foreground;

  /// Prominent button fill and native control accent.
  final Color? accent;

  /// Text and icons on a prominent button.
  final Color? onAccent;

  /// Fallback selection capsule fill, including alpha. UIKit owns its own fill.
  final Color? selection;

  /// Selected fallback text/icons and the native tab bar's selected item color.
  /// Native segmented controls expose an accent, not separate selected text.
  final Color? selectedForeground;

  /// Fallback outline and the middle of the rim gradient, including alpha.
  /// High-contrast mode uses a stronger foreground-derived outline instead.
  final Color? border;

  /// Fallback rim highlight, including alpha. The trailing highlight is softer.
  final Color? highlight;

  /// Fallback contact shadow, including alpha. Opaque mode has no shadow.
  final Color? shadow;

  /// Keeps unspecified overrides. Use a new [LiquidGlassColors] to clear them.
  LiquidGlassColors copyWith({
    Color? surfaceTint,
    Color? foreground,
    Color? accent,
    Color? onAccent,
    Color? selection,
    Color? selectedForeground,
    Color? border,
    Color? highlight,
    Color? shadow,
  }) => LiquidGlassColors(
    surfaceTint: surfaceTint ?? this.surfaceTint,
    foreground: foreground ?? this.foreground,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    selection: selection ?? this.selection,
    selectedForeground: selectedForeground ?? this.selectedForeground,
    border: border ?? this.border,
    highlight: highlight ?? this.highlight,
    shadow: shadow ?? this.shadow,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassColors &&
          surfaceTint == other.surfaceTint &&
          foreground == other.foreground &&
          accent == other.accent &&
          onAccent == other.onAccent &&
          selection == other.selection &&
          selectedForeground == other.selectedForeground &&
          border == other.border &&
          highlight == other.highlight &&
          shadow == other.shadow;

  @override
  int get hashCode => Object.hash(
    surfaceTint,
    foreground,
    accent,
    onAccent,
    selection,
    selectedForeground,
    border,
    highlight,
    shadow,
  );
}

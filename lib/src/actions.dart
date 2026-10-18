import 'package:flutter/material.dart';

@immutable
class LiquidGlassAction {
  const LiquidGlassAction({
    required this.id,
    required this.label,
    this.icon,
    this.sfSymbol,
    this.showLabel = false,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
  });
  final String id;
  final String label;
  final IconData? icon;
  final String? sfSymbol;

  /// Shows [label] after the icon in a `LiquidGlassButtonGroup`, and so in a
  /// `LiquidGlassToolbar` and the leading capsule of a `LiquidGlassActionBar`.
  /// By default an action with an icon shows only the icon there and [label]
  /// is its accessibility label and tooltip. Navigation and tab bars show an
  /// icon or a label, never both, and ignore it.
  final bool showLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Describes the secondary action for accessibility; defaults to [label].
  final String? longPressSemanticLabel;
}

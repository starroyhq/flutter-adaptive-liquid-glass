import 'package:flutter/material.dart';

@immutable
class LiquidGlassAction {
  const LiquidGlassAction({
    required this.id,
    required this.label,
    this.icon,
    this.sfSymbol,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
  });
  final String id;
  final String label;
  final IconData? icon;
  final String? sfSymbol;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Describes the secondary action for accessibility; defaults to [label].
  final String? longPressSemanticLabel;
}

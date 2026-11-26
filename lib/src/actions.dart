import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'menu_data.dart';

@immutable
class LiquidGlassAction {
  const LiquidGlassAction({
    required this.id,
    required this.label,
    this.icon,
    this.sfSymbol,
    this.iconPng,
    this.badge,
    this.menu,
    this.showLabel = false,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
  }) : assert(
         menu == null || (onPressed == null && onLongPress == null),
         'A navigation menu owns the action’s gestures.',
       );
  final String id;
  final String label;
  final IconData? icon;
  final String? sfSymbol;

  /// A PNG icon for a navigation bar item. In native mode, [sfSymbol] is
  /// preferred when UIKit can resolve it. [icon] supplies a portable glyph
  /// when no PNG is provided.
  final Uint8List? iconPng;

  /// A navigation bar badge. An empty string displays a dot.
  final String? badge;

  /// Opens a menu from this navigation bar item on tap.
  final LiquidGlassNavigationMenu? menu;

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

/// The item data and selection callback for a navigation bar menu.
@immutable
class LiquidGlassNavigationMenu {
  const LiquidGlassNavigationMenu({
    required this.items,
    required this.onSelected,
    this.enabled = true,
  });

  final List<LiquidGlassMenuItem<String>> items;
  final ValueChanged<String> onSelected;
  final bool enabled;
}

import 'package:flutter/material.dart';

/// A tab, or the trailing action, of the native tab bar. Internal; not
/// exported by flutter_adaptive_liquid_glass.dart.
@immutable
class NativeTabItem {
  const NativeTabItem({
    required this.label,
    this.symbol,
    this.icon,
    this.selectedIcon,
    this.badge,
  });

  final String label;

  /// An SF Symbol for both states; otherwise [icon] and [selectedIcon] are
  /// drawn as bitmaps.
  final String? symbol;
  final IconData? icon;
  final IconData? selectedIcon;

  /// `null` shows no badge, an empty string a dot, other text a text badge.
  final String? badge;

  /// Everything whose change recreates the native view; badges update in place.
  int get structuralSignature => Object.hash(label, symbol, icon, selectedIcon);
}

NativeTabItem nativeTabItem({
  required String label,
  required IconData icon,
  IconData? selectedIcon,
  String? sfSymbol,
  String? badge,
}) => NativeTabItem(
  label: label,
  symbol: sfSymbol,
  // UIKit sizes SF Symbols consistently. Mixing a selected bitmap with an
  // unselected symbol can expand the bitmap over the complete native pill.
  icon: sfSymbol == null ? icon : null,
  selectedIcon: sfSymbol == null ? selectedIcon : null,
  badge: badge,
);

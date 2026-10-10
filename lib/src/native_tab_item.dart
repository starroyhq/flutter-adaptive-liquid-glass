import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

// Internal provider mapping, deliberately not exported by flutter_adaptive_liquid_glass.dart.
native.LiquidGlassTabItem nativeTabItem({
  required String label,
  required IconData icon,
  IconData? selectedIcon,
  String? sfSymbol,
  String? badge,
}) {
  return native.LiquidGlassTabItem(
    label: label,
    icon: sfSymbol != null
        ? native.NativeLiquidGlassIcon.sfSymbol(sfSymbol)
        : native.NativeLiquidGlassIcon.iconData(icon),
    // UIKit sizes SF Symbols consistently. Mixing a selected bitmap with an
    // unselected symbol can expand the bitmap over the complete native pill.
    selectedIcon: sfSymbol != null
        ? native.NativeLiquidGlassIcon.sfSymbol(sfSymbol)
        : selectedIcon == null
        ? null
        : native.NativeLiquidGlassIcon.iconData(selectedIcon),
    iosBadgeValue: badge,
  );
}

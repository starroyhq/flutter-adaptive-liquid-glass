import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fixed native dimensions prevent a compressed SwiftUI intrinsic-size reply
/// from replacing Flutter's measured width and ellipsizing CJK labels.
@immutable
class NativeButtonLayout {
  const NativeButtonLayout(this.width, this.labelStyle);
  final double width;
  final TextStyle labelStyle;
  static const height = 48.0;
  static const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  static const iconSize = 22.0;
  static const imagePadding = 8.0;

  factory NativeButtonLayout.measure({
    required String? label,
    required bool hasIcon,
    required bool usesSfSymbol,
    required TextScaler textScaler,
    required TextDirection direction,
  }) {
    final style = TextStyle(
      fontSize: textScaler.scale(17),
      fontWeight: FontWeight.w600,
    );
    if (label == null) return NativeButtonLayout(height, style);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    // SF Symbols have natural aspect ratios; the upstream SwiftUI path sizes
    // their font height, so wide symbols need more horizontal room than bitmaps.
    final iconWidth = hasIcon
        ? (usesSfSymbol ? 32.0 : iconSize) + imagePadding
        : 0.0;
    final width = math.max(
      height,
      (painter.width + padding.horizontal + iconWidth + 4).ceilToDouble(),
    );
    painter.dispose();
    return NativeButtonLayout(width, style);
  }
}

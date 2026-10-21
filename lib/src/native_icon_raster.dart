// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

final Map<String, Uint8List?> _pngCache = {};

/// Forgets the bitmaps drawn by [nativeIconPng], such as on hot reload.
void clearNativeIconPngCache() => _pngCache.clear();

/// The pixel ratio [nativeIconPng] draws at: the first view's, or 3.
double nativeIconPixelRatio() {
  final views = ui.PlatformDispatcher.instance.views;
  return views.isEmpty ? 3.0 : views.first.devicePixelRatio;
}

/// Draws [icon] for a native view: a white [glyphSize]-point glyph centred in
/// a [canvasSize]-point square, at [nativeIconPixelRatio], encoded as PNG.
/// The defaults are the capsule's padded square. Each glyph is drawn once per
/// size and pixel ratio; `null` when drawing fails.
Future<Uint8List?> nativeIconPng(
  IconData icon, {
  double canvasSize = 64,
  double glyphSize = 34,
}) async {
  final ratio = nativeIconPixelRatio();
  final key = [
    icon.codePoint,
    icon.fontFamily,
    icon.fontPackage,
    icon.matchTextDirection,
    ratio.toStringAsFixed(2),
    canvasSize,
    glyphSize,
  ].join('|');
  if (_pngCache.containsKey(key)) return _pngCache[key];
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: Colors.white,
          fontSize: glyphSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (canvasSize - painter.width) / 2,
        (canvasSize - painter.height) / 2,
      ),
    );
    final picture = recorder.endRecording();
    final side = (canvasSize * ratio).round();
    final image = await picture.toImage(side, side);
    picture.dispose();
    painter.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return _pngCache[key] = data?.buffer.asUint8List();
  } catch (_) {
    return _pngCache[key] = null;
  }
}

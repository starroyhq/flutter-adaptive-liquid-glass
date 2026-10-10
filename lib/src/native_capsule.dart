import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart' as native;

import 'native_button_layout.dart';
import 'theme.dart';
import 'native_visibility.dart';

@immutable
class NativeCapsuleItem {
  const NativeCapsuleItem({
    required this.id,
    required this.label,
    this.title,
    this.icon,
    this.sfSymbol,
    this.onPressed,
  });
  final String id, label;
  final String? title, sfSymbol;
  final IconData? icon;
  final VoidCallback? onPressed;
}

/// One platform view owns one glass effect and all its plain UIKit buttons.
class NativeCapsule extends StatefulWidget {
  const NativeCapsule({
    super.key,
    required this.items,
    this.grouped = false,
    this.prominent = false,
  });
  final List<NativeCapsuleItem> items;
  final bool grouped, prominent;
  @override
  State<NativeCapsule> createState() => _NativeCapsuleState();
}

class _NativeCapsuleState extends State<NativeCapsule>
    with native.LiquidGlassRouteSuppression {
  MethodChannel? _channel;
  @override
  MethodChannel? get suppressionChannel => _channel;
  final _icons = <int, Uint8List>{};
  int _generation = 0;
  double? _measuredWidth;
  int? _measurementSignature;
  int get _iconSignature => Object.hashAll(
    widget.items.map((item) => Object.hash(item.icon, item.sfSymbol)),
  );

  @override
  void initState() {
    super.initState();
    _prepareIcons();
  }

  @override
  void didUpdateWidget(covariant NativeCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = Object.hashAll(
      oldWidget.items.map((item) => Object.hash(item.icon, item.sfSymbol)),
    );
    if (old != _iconSignature) _prepareIcons();
  }

  Future<void> _prepareIcons() async {
    final epoch = ++_generation;
    _icons.clear();
    for (var index = 0; index < widget.items.length; ++index) {
      final item = widget.items[index], icon = widget.items[index].icon;
      if (item.sfSymbol != null || icon == null) continue;
      // Rasterize at the glyph's actual bounds, avoiding upstream's 64-point
      // padded bitmap which makes an IconData appear too small inside UIKit.
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      )..layout();
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder)..scale(3), Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (painter.width * 3).ceil(),
        (painter.height * 3).ceil(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      painter.dispose();
      if (!mounted || epoch != _generation) return;
      if (bytes != null) _icons[index] = bytes.buffer.asUint8List();
    }
    if (mounted && epoch == _generation) setState(() {});
  }

  Future<void> _created(int id, int signature) async {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('flutter_adaptive_liquid_glass/capsule/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'pressed') {
        for (final item in widget.items) {
          if (item.id == call.arguments) {
            item.onPressed?.call();
            break;
          }
        }
      }
      return null;
    });
    syncGlassRouteVisibility();
    final size = await channel.invokeMapMethod<String, Object?>(
      'intrinsicSize',
    );
    if (!mounted || _channel != channel || _measurementSignature != signature) {
      return;
    }
    final width = size?['width'];
    if (width is num && width.isFinite && width > 0) {
      setState(() => _measuredWidth = width.toDouble());
    }
  }

  @override
  void dispose() {
    ++_generation;
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context),
        fontSize = MediaQuery.textScalerOf(context).scale(17);
    final colors = theme.colorScheme;
    final glassColors = LiquidGlassTheme.of(context).colors;
    final params = <String, Object?>{
      'dark': theme.brightness == Brightness.dark,
      'grouped': widget.grouped,
      'foreground':
          (widget.prominent
                  ? glassColors.onAccent ?? colors.onPrimary
                  : glassColors.foreground ?? colors.onSurface)
              .toARGB32(),
      'tint': widget.prominent
          ? (glassColors.accent ?? colors.primary).toARGB32()
          : glassColors.surfaceTint?.toARGB32(),
      'fontSize': fontSize,
      'suppressed': ModalRoute.of(context)?.isCurrent == false,
      'popupOwner': ModalRoute.of(context) is PopupRoute,
      'items': [
        for (var i = 0; i < widget.items.length; ++i)
          {
            'id': widget.items[i].id,
            'label': widget.items[i].label,
            'title': widget.items[i].title,
            'symbol': widget.items[i].sfSymbol,
            'png': _icons[i],
            'enabled': widget.items[i].onPressed != null,
          },
      ],
    };
    final signature = Object.hash(
      theme.brightness,
      fontSize,
      widget.grouped,
      widget.prominent,
      params['foreground'],
      params['tint'],
      Object.hashAll(
        widget.items.map(
          (item) => Object.hash(
            item.id,
            item.title,
            item.label,
            item.icon,
            item.sfSymbol,
            item.onPressed != null,
          ),
        ),
      ),
      Object.hashAll(_icons.values),
    );
    if (_measurementSignature != signature) {
      _measurementSignature = signature;
      _measuredWidth = null;
    }
    final estimate = widget.items.fold<double>(
      widget.grouped ? 8 : 0,
      (sum, item) =>
          sum +
          NativeButtonLayout.measure(
            label: item.title,
            hasIcon: item.icon != null || item.sfSymbol != null,
            usesSfSymbol: item.sfSymbol != null,
            textScaler: MediaQuery.textScalerOf(context),
            direction: Directionality.of(context),
          ).width,
    );
    final width = _measuredWidth != null && _measuredWidth! > estimate
        ? _measuredWidth!
        : estimate;
    return SizedBox(
      width: width,
      height: 48,
      child: NativeVisibility(
        child: UiKitView(
          key: ValueKey(signature),
          viewType: 'flutter_adaptive_liquid_glass/capsule',
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _created(id, signature),
          gestureRecognizers: {
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
          },
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_button_layout.dart';
import 'native_icon_raster.dart';
import 'theme.dart';
import 'native_visibility.dart';
import 'feedback.dart';

/// Whether a native capsule event may still invoke its action.
bool nativeCapsuleActionAllowed(BuildContext context) =>
    LiquidGlassFeedback.canInteract(context);

@immutable
class NativeCapsuleItem {
  const NativeCapsuleItem({
    required this.id,
    required this.label,
    this.title,
    this.detail,
    this.icon,
    this.sfSymbol,
    this.iconColor,
    this.iconSize,
    this.menuIndicator = false,
    this.onPressed,
    this.onLongPress,
    this.longPressSemanticLabel,
  });
  final String id, label;
  final String? title, detail, sfSymbol;
  final IconData? icon;
  final Color? iconColor;
  final double? iconSize;
  final bool menuIndicator;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? longPressSemanticLabel;
}

/// One platform view owns one glass effect and all its plain UIKit buttons.
class NativeCapsule extends StatefulWidget {
  const NativeCapsule({
    super.key,
    required this.items,
    this.grouped = false,
    this.prominent = false,
    this.standaloneIcon = false,
  }) : assert(!standaloneIcon || (!grouped && items.length == 1));
  final List<NativeCapsuleItem> items;
  final bool grouped, prominent;

  /// A single icon-only button without a long press, drawn as the standalone
  /// glass icon button: a semibold symbol, or a glyph bitmap trimmed to the
  /// icon size, in colors that do not change when pressed or disabled. A
  /// bitmap icon reserves its space until the bitmap is drawn.
  final bool standaloneIcon;
  @override
  State<NativeCapsule> createState() => _NativeCapsuleState();
}

class _NativeCapsuleState extends State<NativeCapsule>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  Map<String, bool>? _interactionState;
  int _interactionEpoch = 0;
  int _viewGeneration = 0;
  int _lastEvent = 0;
  final _icons = <int, Uint8List>{};
  bool _iconsReady = false;
  int _generation = 0;
  double? _measuredWidth;
  int? _measurementSignature;
  int get _iconSignature => Object.hashAll(
    widget.items.map(
      (item) => Object.hash(item.icon, item.sfSymbol, item.iconSize),
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareIcons();
  }

  List<Route<dynamic>> _routes() {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return visited.toList();
  }

  bool get _covered => _routes().any(
    (route) =>
        (route.isActive && !route.isCurrent) ||
        nativeRouteCoverage.covers(route),
  );

  void _syncInteraction({bool force = false}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final state = {
      'suppressed': _covered,
      'interactionEnabled':
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
    };
    final changed = !mapEquals(_interactionState, state);
    if (changed) {
      _interactionState = state;
      ++_interactionEpoch;
    }
    final channel = _channel;
    if (channel != null && (changed || force)) {
      unawaited(
        channel.invokeMethod<void>('setSuppressed', {
          ...state,
          'epoch': _interactionEpoch,
        }),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncInteraction(force: true);
  }

  @override
  void didUpdateWidget(covariant NativeCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = Object.hashAll(
      oldWidget.items.map(
        (item) => Object.hash(item.icon, item.sfSymbol, item.iconSize),
      ),
    );
    // A standalone bitmap is a padded square, a capsule bitmap the glyph's own
    // bounds, so switching modes redraws the bitmap too.
    if (old != _iconSignature ||
        oldWidget.standaloneIcon != widget.standaloneIcon) {
      _prepareIcons();
    }
  }

  Future<void> _prepareIcons() async {
    final epoch = ++_generation;
    _icons.clear();
    _iconsReady = false;
    for (var index = 0; index < widget.items.length; ++index) {
      final item = widget.items[index], icon = widget.items[index].icon;
      if (item.sfSymbol != null || icon == null) continue;
      if (widget.standaloneIcon) {
        // The standalone button trims the padded glyph square natively.
        final png = await nativeIconPng(icon);
        if (!mounted || epoch != _generation) return;
        if (png != null) _icons[index] = png;
        continue;
      }
      // Rasterize at the glyph's actual bounds, avoiding a 64-point padded
      // bitmap which makes an IconData appear too small inside UIKit.
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: item.iconSize ?? 22,
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
    if (mounted && epoch == _generation) setState(() => _iconsReady = true);
  }

  Future<void> _created(int id, int signature, int generation) async {
    if (!mounted ||
        signature != _measurementSignature ||
        generation != _viewGeneration) {
      return;
    }
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('flutter_adaptive_liquid_glass/capsule/$id');
    _channel = channel;
    _lastEvent = 0;
    channel.setMethodCallHandler((call) async {
      if (!mounted ||
          _channel != channel ||
          generation != _viewGeneration ||
          signature != _measurementSignature ||
          !nativeCapsuleActionAllowed(context)) {
        return null;
      }
      if (call.method != 'pressed' && call.method != 'longPressed') return null;
      final arguments = call.arguments;
      if (arguments is! Map || arguments['epoch'] != _interactionEpoch) {
        return null;
      }
      final sequence = arguments['sequence'];
      if (sequence is! int || sequence <= _lastEvent) return null;
      _lastEvent = sequence;
      for (final item in widget.items) {
        if (item.id != arguments['id']) continue;
        final longPress = call.method == 'longPressed';
        final callback = longPress ? item.onLongPress : item.onPressed;
        if (callback == null) break;
        if (longPress) {
          LiquidGlassFeedback.longPress(context);
        } else {
          LiquidGlassFeedback.tap(context);
        }
        callback();
        break;
      }
      return null;
    });
    _syncInteraction(force: true);
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
    ++_viewGeneration;
    WidgetsBinding.instance.removeObserver(this);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      nativeRouteCoverage,
      for (final route in _routes().whereType<TransitionRoute>())
        route.secondaryAnimation,
    ]),
    builder: (context, _) => _buildCapsule(context),
  );

  Widget _buildCapsule(BuildContext context) {
    _syncInteraction();
    final theme = Theme.of(context),
        fontSize = MediaQuery.textScalerOf(context).scale(17);
    final colors = theme.colorScheme;
    final glassColors = LiquidGlassTheme.of(context).colors;
    final params = <String, Object?>{
      'dark': theme.brightness == Brightness.dark,
      'grouped': widget.grouped,
      'standaloneIcon': widget.standaloneIcon,
      'foreground':
          (widget.prominent
                  ? glassColors.onAccent ?? colors.onPrimary
                  : glassColors.foreground ?? colors.onSurface)
              .toARGB32(),
      'tint': widget.prominent
          ? (glassColors.accent ?? colors.primary).toARGB32()
          : glassColors.surfaceTint?.toARGB32(),
      'fontSize': fontSize,
      ..._interactionState!,
      'epoch': _interactionEpoch,
      'popupOwner': _routes().any((route) => route is PopupRoute),
      'items': [
        for (var i = 0; i < widget.items.length; ++i)
          {
            'id': widget.items[i].id,
            'label': widget.items[i].label,
            'title': widget.items[i].title,
            'detail': widget.items[i].detail,
            'symbol': widget.items[i].sfSymbol,
            'iconColor': widget.items[i].iconColor?.toARGB32(),
            'iconSize': widget.items[i].iconSize,
            'menuIndicator': widget.items[i].menuIndicator,
            'png': _icons[i],
            'enabled':
                widget.items[i].onPressed != null ||
                widget.items[i].onLongPress != null,
            'tapEnabled': widget.items[i].onPressed != null,
            'longPressEnabled': widget.items[i].onLongPress != null,
            'longPressLabel':
                widget.items[i].longPressSemanticLabel ?? widget.items[i].label,
          },
      ],
    };
    final signature = Object.hash(
      theme.brightness,
      fontSize,
      widget.grouped,
      widget.prominent,
      widget.standaloneIcon,
      params['foreground'],
      params['tint'],
      Object.hashAll(
        widget.items.map(
          (item) => Object.hash(
            item.id,
            item.title,
            item.detail,
            item.label,
            item.icon,
            item.sfSymbol,
            item.iconColor,
            item.iconSize,
            item.menuIndicator,
            item.onPressed != null,
            item.onLongPress != null,
            item.longPressSemanticLabel,
          ),
        ),
      ),
      Object.hashAll(_icons.values),
    );
    if (_measurementSignature != signature) {
      ++_viewGeneration;
      _measurementSignature = signature;
      _measuredWidth = null;
    }
    final generation = _viewGeneration;
    final estimate = widget.items.fold<double>(
      widget.grouped ? 8 : 0,
      (sum, item) =>
          sum +
          NativeButtonLayout.measure(
            label: item.title,
            detail: item.detail,
            hasIcon: item.icon != null || item.sfSymbol != null,
            usesSfSymbol: item.sfSymbol != null,
            iconSize: item.iconSize,
            menuIndicator: item.menuIndicator,
            textScaler: MediaQuery.textScalerOf(context),
            direction: Directionality.of(context),
          ).width,
    );
    final width = _measuredWidth != null && _measuredWidth! > estimate
        ? _measuredWidth!
        : estimate;
    if (widget.standaloneIcon && !_iconsReady) {
      final item = widget.items.single;
      // Reserve the button's space until its bitmap is drawn.
      if (item.sfSymbol == null && item.icon != null) {
        return SizedBox(width: width, height: 48);
      }
    }
    return SizedBox(
      width: width,
      height: 48,
      child: NativeVisibility(
        child: UiKitView(
          key: ValueKey(signature),
          viewType: 'flutter_adaptive_liquid_glass/capsule',
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) => _created(id, signature, generation),
          gestureRecognizers: {
            Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            if (widget.items.any((item) => item.onLongPress != null))
              Factory<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(),
              ),
          },
        ),
      ),
    );
  }
}

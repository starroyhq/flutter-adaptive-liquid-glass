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
///
/// A capsule keeps its view when an action's enabled state, or the capsule's
/// emphasis or colors, change: they reach the live view through its `update`
/// method, item by item in order. Adding, removing or reordering actions, or
/// changing what an action shows, creates a new view.
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

  /// A single icon-only button, with or without a long press, drawn as the
  /// standalone glass icon button: a semibold symbol, or a glyph bitmap
  /// trimmed to the icon size, in colors that do not change when pressed or
  /// disabled. A bitmap icon reserves its space until the bitmap is drawn.
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

  /// The enabled state and colors of the actions: as the view was created
  /// with them, as last sent, and the enabled part of what was last sent.
  List<Object?>? _createdDynamic, _dynamicSent, _enabledSent;
  Map<String, Object?>? _latestDynamic;

  /// The view generation whose channel is [_channel].
  int _channelGeneration = -1;

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

  bool get _covered => _routes().any(nativeRouteHidden);

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
    _channelGeneration = generation;
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
    // Catch up with changes made while the view was being created.
    if (!listEquals(_createdDynamic, _dynamicSent)) {
      _createdDynamic = _dynamicSent;
      _sendUpdate();
    }
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

  /// Sends the latest enabled state and colors to the live view, with the
  /// interaction epoch that its events must carry from now on.
  void _sendUpdate() {
    final channel = _channel, state = _latestDynamic;
    if (channel == null || state == null) return;
    unawaited(
      channel
          .invokeMethod<void>('update', {...state, 'epoch': _interactionEpoch})
          .catchError((Object _) {}),
    );
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
    // UIKit lays out the actions, and each icon beside its title, in this
    // direction rather than the device language's.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final params = <String, Object?>{
      'dark': theme.brightness == Brightness.dark,
      'rtl': rtl,
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
            // Flutter draws the glyph left to right; the native view mirrors it.
            'mirror':
                rtl && (widget.items[i].icon?.matchTextDirection ?? false),
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
    // The enabled state of each action, emphasis and colors do not affect
    // layout: they are left out of the signature and reach the live view in
    // place. A long press stays structural: it adds a native recognizer.
    final enabledState = [
      for (final item in widget.items) ...[
        item.onPressed != null,
        item.onLongPress != null,
      ],
    ];
    final dynamicState = [
      params['foreground'],
      params['tint'],
      for (final item in widget.items) item.iconColor?.toARGB32(),
      ...enabledState,
    ];
    _latestDynamic = {
      'foreground': params['foreground'],
      'tint': params['tint'],
      'items': [
        for (final item in widget.items)
          {
            'iconColor': item.iconColor?.toARGB32(),
            'enabled': item.onPressed != null || item.onLongPress != null,
            'tapEnabled': item.onPressed != null,
            'longPressEnabled': item.onLongPress != null,
          },
      ],
    };
    final signature = Object.hash(
      theme.brightness,
      rtl,
      fontSize,
      widget.grouped,
      widget.standaloneIcon,
      Object.hashAll(
        widget.items.map(
          (item) => Object.hash(
            item.id,
            item.title,
            item.detail,
            item.label,
            item.icon,
            item.sfSymbol,
            item.iconSize,
            item.menuIndicator,
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
      // A new view is created with the state of this build.
      _createdDynamic = _dynamicSent = dynamicState;
      _enabledSent = enabledState;
    } else if (!listEquals(_dynamicSent, dynamicState)) {
      if (!listEquals(_enabledSent, enabledState)) {
        // A press UIKit reported before this change must not reach the new
        // callbacks, as when a disabled button is enabled again.
        ++_interactionEpoch;
        _enabledSent = enabledState;
      }
      _dynamicSent = dynamicState;
      // A view still being created catches up once its channel exists.
      if (_channelGeneration == _viewGeneration) _sendUpdate();
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

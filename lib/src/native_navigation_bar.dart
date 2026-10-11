import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'feedback.dart';
import 'native_visibility.dart';

/// Internal UINavigationBar bridge. UIKit owns the bar, its glass and buttons;
/// Flutter supplies stable business labels instead of SF Symbol descriptions.
class NativeNavigationBar extends StatefulWidget {
  const NativeNavigationBar({
    super.key,
    required this.title,
    required this.tintColor,
    required this.leading,
    required this.actions,
  });

  final String title;
  final Color tintColor;
  final List<LiquidGlassAction> leading, actions;

  @override
  State<NativeNavigationBar> createState() => _NativeNavigationBarState();
}

class _NativeNavigationBarState extends State<NativeNavigationBar>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  Map<String, Object?> _configuration = {};
  Future<void> _pending = Future<void>.value();
  int _epoch = 0;
  int _lastEvent = 0;
  List<Route<dynamic>> _coverageRoutes = const [];
  bool _routeCovered = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nativeRouteCoverage.addListener(_coverageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverageRoutes = _routes();
    _coverageChanged();
  }

  void _coverageChanged() {
    final covered = _coverageRoutes.any(nativeRouteCoverage.covers);
    if (_routeCovered == covered) return;
    _routeCovered = covered;
    // Coverage may begin and end before the next frame. Invalidate queued
    // activations synchronously so restoring visibility cannot revive them.
    if (covered) ++_epoch;
    if (!mounted || _syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      // A same-frame cover/uncover leaves visual props unchanged, but UIKit
      // still needs the advanced epoch before accepting a new activation.
      if (mounted) _sync(force: true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  List<Route<dynamic>> _routes() {
    Route<dynamic>? route = ModalRoute.of(context);
    final routes = <Route<dynamic>>{};
    while (route != null && routes.add(route)) {
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return routes.toList();
  }

  Map<String, Object?> _props() {
    final routes = _routes();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    List<Map<String, Object?>> items(List<LiquidGlassAction> actions) => [
      for (final action in actions)
        {
          'id': action.id,
          'label': action.label,
          'sfSymbol': action.sfSymbol,
          'enabled': action.onPressed != null,
        },
    ];
    return {
      'title': widget.title,
      'tintColor': widget.tintColor.toARGB32(),
      'dark': Theme.of(context).brightness == Brightness.dark,
      'rtl': Directionality.of(context) == TextDirection.rtl,
      'leading': items(widget.leading),
      'actions': items(widget.actions),
      'popupOwner': routes.any((route) => route is PopupRoute),
      'suppressed': routes.any(
        (route) =>
            (route.isActive && !route.isCurrent) ||
            nativeRouteCoverage.covers(route),
      ),
      'interactionEnabled':
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
    };
  }

  bool _sameConfiguration(Map<String, Object?> next) {
    if (_configuration.length != next.length) return false;
    for (final key in next.keys) {
      final value = next[key], previous = _configuration[key];
      if (value is List<Map<String, Object?>>) {
        if (previous is! List<Map<String, Object?>> ||
            value.length != previous.length) {
          return false;
        }
        for (var i = 0; i < value.length; ++i) {
          if (!mapEquals(value[i], previous[i])) return false;
        }
      } else if (value != previous) {
        return false;
      }
    }
    return true;
  }

  bool _sameInteractionConfiguration(Map<String, Object?> next) {
    for (final key in ['suppressed', 'interactionEnabled', 'popupOwner']) {
      if (next[key] != _configuration[key]) return false;
    }
    for (final key in ['leading', 'actions']) {
      final items = next[key] as List<Map<String, Object?>>;
      final previous = _configuration[key];
      if (previous is! List<Map<String, Object?>> ||
          items.length != previous.length) {
        return false;
      }
      for (var i = 0; i < items.length; ++i) {
        if (items[i]['id'] != previous[i]['id'] ||
            items[i]['enabled'] != previous[i]['enabled']) {
          return false;
        }
      }
    }
    return true;
  }

  void _sync({bool force = false}) {
    final props = _props();
    final changed = !_sameConfiguration(props);
    if (changed) {
      // A theme or accessibility-label update must not discard an activation
      // already sent by UIKit for the same enabled action. Only changes that
      // invalidate that interaction advance its epoch; visual props still sync.
      if (!_sameInteractionConfiguration(props)) ++_epoch;
      _configuration = props;
    }
    final channel = _channel;
    if (channel == null || (!changed && !force)) return;
    final payload = {...props, 'epoch': _epoch};
    // Preserve ordering when theme, labels and route coverage change together.
    _pending = _pending
        .then((_) async {
          if (!mounted || _channel != channel) return;
          await channel.invokeMethod<void>('configure', payload);
        })
        .catchError((Object error, StackTrace stack) {
          if (!mounted || _channel != channel) return;
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'flutter_adaptive_liquid_glass',
              context: ErrorDescription('updating the native navigation bar'),
            ),
          );
        });
  }

  void _created(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel(
      'flutter_adaptive_liquid_glass/navigation-bar/$id',
    );
    _channel = channel;
    _lastEvent = 0;
    channel.setMethodCallHandler((call) async {
      if (!mounted ||
          _channel != channel ||
          call.method != 'pressed' ||
          !LiquidGlassFeedback.canInteract(context)) {
        return;
      }
      final event = call.arguments;
      if (event is! Map || event['epoch'] != _epoch) return;
      final sequence = event['sequence'];
      if (sequence is! int || sequence <= _lastEvent) return;
      _lastEvent = sequence;
      for (final action in [...widget.leading, ...widget.actions]) {
        if (action.id != event['id']) continue;
        final callback = action.onPressed;
        if (callback == null) return;
        LiquidGlassFeedback.tap(context);
        callback();
        return;
      }
    });
    _sync(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nativeRouteCoverage.removeListener(_coverageChanged);
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      nativeRouteCoverage,
      for (final route in _routes().whereType<TransitionRoute>())
        route.secondaryAnimation,
    ]),
    builder: (context, _) {
      _sync();
      return SizedBox(
        height: 64,
        child: NativeVisibility(
          child: UiKitView(
            viewType: 'flutter_adaptive_liquid_glass/navigation-bar',
            creationParams: {..._configuration, 'epoch': _epoch},
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
            gestureRecognizers: {
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
            },
          ),
        ),
      );
    },
  );
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'actions.dart';
import 'feedback.dart';
import 'menu_data.dart';
import 'native_icon_raster.dart';
import 'native_visibility.dart';

/// Internal UINavigationBar bridge. UIKit owns the bar, its glass and buttons;
/// Flutter supplies stable business labels instead of SF Symbol descriptions.
class NativeNavigationBar extends StatefulWidget {
  const NativeNavigationBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.tintColor,
    required this.leading,
    required this.actions,
  });

  final String title;
  final String? subtitle;
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
  final _icons = <IconData, Uint8List?>{};
  final _pendingIcons = <IconData>{};
  final _menus = <String, _NavigationMenu>{};
  int _menuRevision = 0;

  Iterable<LiquidGlassAction> get _actions sync* {
    yield* widget.leading;
    yield* widget.actions;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nativeRouteCoverage.addListener(_coverageChanged);
    _prepareActions();
  }

  @override
  void didUpdateWidget(covariant NativeNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareActions();
  }

  void _prepareActions() {
    final icons = <IconData>{
      for (final action in _actions)
        if (action.iconPng == null && action.icon != null) action.icon!,
    };
    _icons.removeWhere((icon, _) => !icons.contains(icon));
    for (final icon in icons) {
      if (!_icons.containsKey(icon) && _pendingIcons.add(icon)) {
        unawaited(_prepareIcon(icon));
      }
    }

    final menus = {
      for (final action in _actions)
        if (action.menu != null) action.id: action.menu!.items,
    };
    _menus.removeWhere((id, _) => !menus.containsKey(id));
    for (final entry in menus.entries) {
      final previous = _menus[entry.key];
      if (previous != null && sameMenuItems(previous.items, entry.value)) {
        continue;
      }
      final menu = _NavigationMenu(
        snapshotMenuItems(entry.value, <String>{}),
        ++_menuRevision,
      );
      _menus[entry.key] = menu;
      if (menu.items.isNotEmpty) unawaited(_prepareMenu(entry.key, menu));
    }
  }

  Future<void> _prepareIcon(IconData icon) async {
    final png = await nativeIconPng(icon, canvasSize: 22, glyphSize: 18);
    _pendingIcons.remove(icon);
    if (!mounted ||
        !_actions.any(
          (action) => action.iconPng == null && action.icon == icon,
        )) {
      return;
    }
    setState(() => _icons[icon] = png);
  }

  Future<void> _prepareMenu(String id, _NavigationMenu menu) async {
    final payload = await prepareNativeMenu(menu.items);
    if (!mounted || _menus[id] != menu) return;
    setState(() {
      menu.payload = payload;
      menu.revision = ++_menuRevision;
    });
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
    final canOpenMenu =
        _menus.isNotEmpty && LiquidGlassFeedback.canInteract(context);
    List<Map<String, Object?>> items(List<LiquidGlassAction> actions) => [
      for (final action in actions) _item(action, canOpenMenu),
    ];
    return {
      'title': widget.title,
      'subtitle': widget.subtitle,
      'tintColor': widget.tintColor.toARGB32(),
      'dark': Theme.of(context).brightness == Brightness.dark,
      'rtl': Directionality.of(context) == TextDirection.rtl,
      'leading': items(widget.leading),
      'actions': items(widget.actions),
      'popupOwner': routes.any((route) => route is PopupRoute),
      'suppressed': routes.any(nativeRouteHidden),
      'interactionEnabled':
          lifecycle == null || lifecycle == AppLifecycleState.resumed,
    };
  }

  Map<String, Object?> _item(LiquidGlassAction action, bool canOpenMenu) {
    final menu = _menus[action.id];
    final png = action.iconPng;
    final bitmap = png == null ? _icons[action.icon] : Uint8List.fromList(png);
    return {
      'id': action.id,
      'label': action.label,
      'sfSymbol': action.sfSymbol,
      if (bitmap != null) ...{
        'png': bitmap,
        'template': png == null,
        'mirror': png == null && (action.icon?.matchTextDirection ?? false),
      },
      if (action.badge != null) 'badge': action.badge,
      'enabled': menu == null
          ? action.onPressed != null
          : canOpenMenu && action.menu!.enabled && menu.payload != null,
      if (menu != null)
        'menu': {
          'revision': menu.revision,
          'items': menu.payload?.items ?? const <Map<String, Object?>>[],
        },
    };
  }

  bool _sameItem(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final next = a[key], previous = b[key];
      if (key == 'png') {
        if (!listEquals(next as Uint8List?, previous as Uint8List?)) {
          return false;
        }
      } else if (key == 'menu') {
        if (!mapEquals(next as Map?, previous as Map?)) return false;
      } else if (next != previous) {
        return false;
      }
    }
    return true;
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
          if (!_sameItem(value[i], previous[i])) return false;
        }
      } else if (value != previous) {
        return false;
      }
    }
    return true;
  }

  bool _sameInteractionConfiguration(Map<String, Object?> next) {
    if (_menus.isNotEmpty && next['rtl'] != _configuration['rtl']) return false;
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
            items[i]['enabled'] != previous[i]['enabled'] ||
            (items[i]['menu'] as Map?)?['revision'] !=
                (previous[i]['menu'] as Map?)?['revision']) {
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
          (call.method != 'pressed' && call.method != 'menuSelected') ||
          !LiquidGlassFeedback.canInteract(context)) {
        return;
      }
      final event = call.arguments;
      if (event is! Map || event['epoch'] != _epoch) return;
      final sequence = event['sequence'];
      if (sequence is! int || sequence <= _lastEvent) return;
      _lastEvent = sequence;
      for (final action in _actions) {
        if (action.id != event['id']) continue;
        if (call.method == 'menuSelected') {
          final menu = _menus[action.id], model = action.menu;
          if (menu == null ||
              model == null ||
              !model.enabled ||
              event['revision'] != menu.revision) {
            return;
          }
          final value = menu.payload?.values[event['itemId']];
          if (value != null) model.onSelected(value);
          return;
        }
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

class _NavigationMenu {
  _NavigationMenu(this.items, this.revision);

  final List<LiquidGlassMenuItem<String>> items;
  int revision;
  NativeMenuPayload<String>? payload;
}

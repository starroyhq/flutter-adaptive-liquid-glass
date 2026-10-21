// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_icon_raster.dart';
import 'native_tab_item.dart';
import 'native_visibility.dart';

/// The system tab bar on iOS 26+: a `UITabBarController` in a platform view.
///
/// The view appears once the bitmaps of [NativeTabItem.icon] tabs are drawn.
/// Badge and selection changes reach the live view; changes to the tabs, the
/// selected color, the brightness or the text direction recreate it. The
/// tabs follow Flutter's text direction rather than the device language: in
/// a right-to-left context the first tab is at the right. Only user
/// selection is reported, and a selection the parent does not adopt is
/// reverted.
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.selectedItemColor,
    required this.onTabSelected,
    this.action,
    this.onActionPressed,
  });

  final List<NativeTabItem> items;
  final int currentIndex;
  final Color selectedItemColor;
  final ValueChanged<int> onTabSelected;

  /// The separate round button after the tabs, which never selects a tab.
  final NativeTabItem? action;
  final VoidCallback? onActionPressed;

  /// The platform view type registered by the iOS plugin.
  static const viewType = 'flutter_adaptive_liquid_glass/tab-bar';

  /// The bar's height, below a transparent band of [glassOverflow] into which
  /// its glass may extend without being clipped.
  static const height = 72.0;
  static const glassOverflow = 20.0;

  /// The side of a tab's bitmap, in points, with the glyph filling it. A
  /// Material glyph's ink is about 0.8 of its size, so its ink is about as
  /// tall as the bar's symbols, whose ink is about 24 points.
  static const iconSize = 30.0;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  MethodChannel? _channel;
  List<Map<String, Object?>>? _tabs;
  Map<String, Object?>? _action;
  int _payloadVersion = 0;
  int _payloadRequest = 0;
  late int _structure;
  late List<String?> _badges;
  int? _lastNativeSelectedIndex;
  ({bool suppressed, bool popupOwner})? _routeState;

  static int _structureOf(NativeTabBar bar) => Object.hashAll([
    for (final item in bar.items) item.structuralSignature,
    bar.action?.structuralSignature,
  ]);

  /// Tabs first, then the action.
  static List<String?> _badgesOf(NativeTabBar bar) => [
    for (final item in bar.items) item.badge,
    if (bar.action != null) bar.action!.badge,
  ];

  @override
  void initState() {
    super.initState();
    _structure = _structureOf(widget);
    _badges = _badgesOf(widget);
    unawaited(_preparePayloads());
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structure = _structureOf(widget), badges = _badgesOf(widget);
    if (structure != _structure) {
      _structure = structure;
      _badges = badges;
      unawaited(_preparePayloads());
    } else if (!listEquals(badges, _badges)) {
      // Recreating the view for a new count would flicker.
      _badges = badges;
      _invoke('updateBadges', badges);
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (_lastNativeSelectedIndex == widget.currentIndex) {
        // The native bar selected this tab itself.
        _lastNativeSelectedIndex = null;
      } else {
        _invoke('setSelectedIndex', widget.currentIndex);
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    clearNativeIconPngCache();
    unawaited(_preparePayloads());
  }

  @override
  void dispose() {
    ++_payloadRequest;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  Future<void> _preparePayloads() async {
    final request = ++_payloadRequest;
    Future<Map<String, Object?>> payload(NativeTabItem item) async {
      final symbol = item.symbol, icon = item.icon;
      if (symbol != null || icon == null) {
        return {
          'label': item.label,
          'symbol': symbol,
          'selectedSymbol': symbol,
        };
      }
      const size = NativeTabBar.iconSize;
      return {
        'label': item.label,
        'png': await nativeIconPng(icon, canvasSize: size, glyphSize: size),
        'selectedPng': await nativeIconPng(
          item.selectedIcon ?? icon,
          canvasSize: size,
          glyphSize: size,
        ),
        // UIKit shows the bitmaps at the pixel ratio they were drawn at.
        'scale': nativeIconPixelRatio(),
      };
    }

    final action = widget.action;
    final tabs = await Future.wait(widget.items.map(payload));
    final actionPayload = action == null ? null : await payload(action);
    if (!mounted || request != _payloadRequest) return;
    setState(() {
      _tabs = tabs;
      _action = actionPayload;
      ++_payloadVersion;
    });
  }

  void _invoke(String method, [Object? arguments]) {
    final channel = _channel;
    if (channel == null) return;
    // A failed update must never break tab interaction.
    unawaited(
      channel.invokeMethod<void>(method, arguments).catchError((Object _) {}),
    );
  }

  Future<void> _handle(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'tabSelected':
        final index = call.arguments;
        if (index is! int) return;
        _lastNativeSelectedIndex = index;
        widget.onTabSelected(index);
        // Revert the native selection when the parent did not adopt it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.currentIndex == index) return;
          _lastNativeSelectedIndex = null;
          _invoke('setSelectedIndex', widget.currentIndex);
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      case 'actionPressed':
        widget.onActionPressed?.call();
    }
  }

  void _created(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('${NativeTabBar.viewType}/$id');
    channel.setMethodCallHandler(_handle);
    _channel = channel;
    // The selection or the route may have changed since the view was created.
    _invoke('setSelectedIndex', widget.currentIndex);
    _syncRoute(force: true);
  }

  void _syncRoute({bool force = false}) {
    final state = nativeRouteState(context);
    if (!force && state == _routeState) return;
    _routeState = state;
    _invoke('setSuppressed', {
      'suppressed': state.suppressed,
      'popupOwner': state.popupOwner,
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      nativeRouteCoverage,
      for (final route in nativeRouteChain(
        context,
      ).whereType<TransitionRoute<dynamic>>())
        route.secondaryAnimation,
    ]),
    builder: (context, _) {
      _syncRoute();
      return LayoutBuilder(builder: _buildBar);
    },
  );

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    final tabs = _tabs, action = _action, route = _routeState!;
    if (tabs == null || (widget.action != null && action == null)) {
      return const SizedBox();
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: constraints.hasBoundedWidth
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width,
      height: NativeTabBar.height + NativeTabBar.glassOverflow,
      child: UiKitView(
        key: ValueKey(
          Object.hash(_payloadVersion, widget.selectedItemColor, dark, rtl),
        ),
        viewType: NativeTabBar.viewType,
        creationParams: {
          'tabs': [
            for (var i = 0; i < tabs.length; ++i)
              {
                ...tabs[i],
                'badge': i < widget.items.length ? widget.items[i].badge : null,
              },
          ],
          if (action != null && widget.action != null)
            'action': {...action, 'badge': widget.action!.badge},
          'currentIndex': widget.currentIndex,
          'selectedItemColor': widget.selectedItemColor.toARGB32(),
          'brightness': dark ? 'dark' : 'light',
          'rtl': rtl,
          'glassOverflow': NativeTabBar.glassOverflow,
          'suppressed': route.suppressed,
          'popupOwner': route.popupOwner,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
        gestureRecognizers: {
          Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        },
      ),
    );
  }
}

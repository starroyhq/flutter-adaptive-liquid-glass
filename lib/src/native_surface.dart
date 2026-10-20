import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';

/// The native glass material behind a `LiquidGlassSurface` on iOS 26+.
///
/// This is a package-owned UIKit view rather than a SwiftUI glass
/// container. A SwiftUI-hosted glass shape lays itself out inside the window's
/// safe area and does not refresh the insets it read when its platform view
/// first laid out. A sheet is created below the screen and slides up, so the
/// material could end up short by the bottom inset, or be missing until
/// something resized it. UIKit sizes the material from the view's own bounds.
///
/// The view is a decorative background: it ignores input and is excluded from
/// accessibility. Updates are sent over a per-view channel and never recreate
/// the platform view.
class NativeSurface extends StatefulWidget {
  const NativeSurface({
    super.key,
    required this.radius,
    required this.dark,
    this.tint,
    this.backgroundColor,
  });

  final double radius;
  final bool dark;
  final Color? tint;

  /// Drawn behind the glass in the same rounded shape.
  final Color? backgroundColor;

  /// The platform view type registered by the iOS plugin.
  static const viewType = 'flutter_adaptive_liquid_glass/surface';

  @override
  State<NativeSurface> createState() => _NativeSurfaceState();
}

class _NativeSurfaceState extends State<NativeSurface> {
  MethodChannel? _channel;
  Map<String, Object?>? _created;

  static Map<String, Object?> _configurationOf(NativeSurface surface) => {
    'radius': surface.radius,
    'dark': surface.dark,
    'tint': surface.tint?.toARGB32(),
    'backgroundColor': surface.backgroundColor?.toARGB32(),
  };

  /// Whether the surface lives in a popup, which the package's global
  /// suppression of covered glass must not hide.
  bool _inPopup(BuildContext context) {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      if (route is PopupRoute) return true;
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return false;
  }

  void _platformViewCreated(int id) {
    _channel = MethodChannel('${NativeSurface.viewType}/$id');
    // The widget may have changed between the first build and the native view
    // existing; catch up once.
    if (!mapEquals(_created, _configurationOf(widget))) unawaited(_configure());
  }

  Future<void> _configure() async {
    final channel = _channel;
    if (channel == null) return;
    final configuration = _configurationOf(widget);
    _created = configuration;
    try {
      await channel.invokeMethod<void>('configure', configuration);
    } on MissingPluginException {
      // Hosts without the iOS plugin render the Flutter content alone.
    }
  }

  @override
  void didUpdateWidget(NativeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(_configurationOf(oldWidget), _configurationOf(widget))) {
      unawaited(_configure());
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuration = _configurationOf(widget);
    _created ??= configuration;
    return UiKitView(
      viewType: NativeSurface.viewType,
      creationParams: {...configuration, 'popupOwner': _inPopup(context)},
      creationParamsCodec: const StandardMessageCodec(),
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      onPlatformViewCreated: _platformViewCreated,
    );
  }
}

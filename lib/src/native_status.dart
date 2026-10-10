import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_visibility.dart';

/// Passive UIKit status views. Flutter owns the sole accessibility node.
class NativeStatus extends StatefulWidget {
  const NativeStatus({
    super.key,
    required this.kind,
    required this.height,
    this.width,
    this.progress = 0,
    this.animating = false,
    this.style = 'medium',
    this.color,
    this.trackColor,
  });

  final String kind, style;
  final double height, progress;
  final double? width;
  final bool animating;
  final Color? color, trackColor;

  @override
  State<NativeStatus> createState() => _NativeStatusState();
}

class _NativeStatusState extends State<NativeStatus> {
  MethodChannel? _channel;
  Map<String, Object?> _desired = {};
  Map<String, Object?>? _acknowledged;
  bool _writing = false;

  List<Route<dynamic>> _ancestorRoutes() {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return visited.toList();
  }

  Map<String, Object?> _configuration() {
    var popupOwner = false;
    var suppressed = false;
    for (final route in _ancestorRoutes()) {
      // A popped route remains visible through its own reverse transition.
      // A nested Navigator must also respect its ancestor's active coverage.
      suppressed |= route.isActive && !route.isCurrent;
      popupOwner |= route is PopupRoute;
    }
    return {
      'kind': widget.kind,
      'progress': widget.progress,
      'animating': widget.animating,
      'style': widget.style,
      'height': widget.height,
      'color': widget.color?.toARGB32(),
      'trackColor': widget.trackColor?.toARGB32(),
      'dark': Theme.of(context).brightness == Brightness.dark,
      'rtl': Directionality.of(context) == TextDirection.rtl,
      'popupOwner': popupOwner,
      'suppressed': suppressed,
    };
  }

  void _created(int id) {
    if (!mounted) return;
    _channel = MethodChannel('flutter_adaptive_liquid_glass/status/$id');
    // creationParams may precede several Dart updates while UIKit is creating.
    // Only an acknowledged configure call can establish synchronized state.
    _acknowledged = null;
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_writing || _channel == null) return;
    _writing = true;
    try {
      while (mounted &&
          _channel != null &&
          !mapEquals(_acknowledged, _desired)) {
        final channel = _channel!;
        final configuration = _desired;
        await channel.invokeMethod<void>('configure', configuration);
        if (!mounted) return;
        if (_channel == channel) _acknowledged = configuration;
        // Coalesce changes received during the await into the latest complete
        // configuration instead of queuing every intermediate progress tick.
      }
    } catch (error, stack) {
      if (mounted) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'flutter_adaptive_liquid_glass',
            context: ErrorDescription('updating a native status indicator'),
          ),
        );
      }
    } finally {
      _writing = false;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    // Ancestor ModalRoute lookups use the ancestor Navigator's context, so a
    // constant child is not itself subscribed to those inherited scopes.
    // Observe transitions and explicit coverage to synchronize native state.
    animation: Listenable.merge([
      nativeRouteCoverage,
      for (final route in _ancestorRoutes().whereType<TransitionRoute>())
        route.secondaryAnimation,
    ]),
    builder: (context, child) => _buildStatus(context),
  );

  Widget _buildStatus(BuildContext context) {
    final next = _configuration();
    if (!mapEquals(_desired, next)) {
      _desired = next;
      unawaited(_flush());
    }
    return NativeVisibility(
      child: IgnorePointer(
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: UiKitView(
            viewType: 'flutter_adaptive_liquid_glass/status',
            creationParams: _desired,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _created,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel = null;
    super.dispose();
  }
}

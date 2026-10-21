// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_visibility.dart';

/// The system segmented control on iOS 26+: a `UISegmentedControl` exactly
/// as wide as the space it is given.
///
/// Changes reach the live view one property at a time. Only a user's choice
/// is reported; a choice the parent does not adopt is reverted on the next
/// frame, as the tab bar does.
class NativeSegmentedControl extends StatefulWidget {
  const NativeSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.enabled,
    required this.color,
    required this.onValueChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final bool enabled;
  final Color? color;
  final ValueChanged<int> onValueChanged;

  /// The platform view type registered by the iOS plugin.
  static const viewType = 'flutter_adaptive_liquid_glass/segmented-control';

  /// The height reserved for the control, which UIKit centres in it.
  static const height = 48.0;

  @override
  State<NativeSegmentedControl> createState() => _NativeSegmentedControlState();
}

class _NativeSegmentedControlState extends State<NativeSegmentedControl> {
  MethodChannel? _channel;
  int? _lastSelectedIndex;
  bool? _lastEnabled;
  int? _lastColor;
  ({bool suppressed, bool popupOwner})? _routeState;

  /// What the platform view was created with, from its first build.
  ({List<String> labels, int selectedIndex, bool enabled, int? color})?
  _creation;

  @override
  void didUpdateWidget(NativeSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.labels, oldWidget.labels)) {
      _invoke('updateSegments', {'labels': widget.labels});
    }
    _syncProperties();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  void _invoke(String method, Object? arguments) {
    final channel = _channel;
    if (channel == null) return;
    unawaited(
      channel.invokeMethod<void>(method, arguments).catchError((Object _) {}),
    );
  }

  void _syncProperties() {
    if (_channel == null) return;
    if (_lastSelectedIndex != widget.selectedIndex) {
      _lastSelectedIndex = widget.selectedIndex;
      _invoke('setSelectedIndex', {
        'index': widget.selectedIndex,
        'animated': true,
      });
    }
    if (_lastEnabled != widget.enabled) {
      _lastEnabled = widget.enabled;
      _invoke('setEnabled', {'enabled': widget.enabled});
    }
    final color = widget.color?.toARGB32();
    if (_lastColor != color) {
      _lastColor = color;
      _invoke('setColor', {'color': color});
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (!mounted || call.method != 'valueChanged') return;
    final index = call.arguments;
    if (index is! int) return;
    _lastSelectedIndex = index;
    widget.onValueChanged(index);
    // Revert the native selection when the parent did not adopt it. A parent
    // that rebuilt without adopting it has already reverted it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.selectedIndex == index ||
          _lastSelectedIndex != index) {
        return;
      }
      _lastSelectedIndex = widget.selectedIndex;
      _invoke('setSelectedIndex', {
        'index': widget.selectedIndex,
        'animated': true,
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _created(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel('${NativeSegmentedControl.viewType}/$id');
    channel.setMethodCallHandler(_handle);
    _channel = channel;
    final creation = _creation!;
    _lastSelectedIndex = creation.selectedIndex;
    _lastEnabled = creation.enabled;
    _lastColor = creation.color;
    // Catch up with changes made since the view was created.
    if (!listEquals(creation.labels, widget.labels)) {
      _invoke('updateSegments', {'labels': widget.labels});
    }
    _syncProperties();
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
      final route = _routeState!;
      final color = widget.color?.toARGB32();
      _creation ??= (
        labels: widget.labels,
        selectedIndex: widget.selectedIndex,
        enabled: widget.enabled,
        color: color,
      );
      return SizedBox(
        height: NativeSegmentedControl.height,
        child: UiKitView(
          viewType: NativeSegmentedControl.viewType,
          creationParams: {
            'labels': widget.labels,
            'selectedIndex': widget.selectedIndex,
            'enabled': widget.enabled,
            'color': color,
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
    },
  );
}

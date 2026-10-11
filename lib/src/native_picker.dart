import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';
import 'native_visibility.dart';

/// Private bridge: one UIKit control and one ordered, atomic configuration
/// channel per mounted picker. Theme changes never recreate the platform view.
class NativePicker extends StatefulWidget {
  const NativePicker({
    super.key,
    required this.kind,
    required this.configuration,
    required this.onChanged,
    required this.height,
    this.width,
  });

  final String kind;
  final Map<String, Object?> configuration;
  final ValueChanged<Object?> onChanged;
  final double height;
  final double? width;

  @override
  State<NativePicker> createState() => _NativePickerState();
}

class _NativePickerState extends State<NativePicker>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  Map<String, Object?>? _desired;
  Map<String, Object?>? _sent;
  bool _writing = false;
  bool _scheduled = false;
  int _revision = 0;
  Map<String, Object?> _configuration = {};
  Object? _lastProposedValue;
  bool _proposalPending = false;
  bool _applicationActive = true;
  List<Route<dynamic>> _coverageRoutes = const [];
  bool _routeCovered = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _applicationActive =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    nativeRouteCoverage.addListener(_coverageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coverageRoutes = _ancestorRoutes();
    _coverageChanged();
  }

  void _invalidateInteraction() {
    ++_revision;
    _lastProposedValue = null;
    _proposalPending = false;
  }

  void _coverageChanged() {
    final covered = _coverageRoutes.any(nativeRouteCoverage.covers);
    if (_routeCovered == covered) return;
    _routeCovered = covered;
    // An overlay can be added and removed without Flutter rendering a frame.
    // Observe its start directly so restoring visibility cannot revive an edit.
    if (covered) _invalidateInteraction();
    _scheduleFlush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_applicationActive == active) return;
    _applicationActive = active;
    if (!active) {
      // Invalidate queued native edits immediately, even when pause and resume
      // both happen before Flutter can produce another frame.
      _invalidateInteraction();
    }
    _scheduleFlush();
  }

  List<Route<dynamic>> _ancestorRoutes() {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return visited.toList();
  }

  Future<void> _created(int id) async {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel(
      'flutter_adaptive_liquid_glass/${widget.kind}_picker/$id',
    );
    _channel = channel;
    _sent = null;
    channel.setMethodCallHandler((call) async {
      if (mounted &&
          _channel == channel &&
          call.method == 'changed' &&
          widget.configuration['enabled'] == true &&
          LiquidGlassFeedback.canInteract(context)) {
        final payload = call.arguments;
        if (payload is Map && payload['revision'] == _revision) {
          _lastProposedValue = payload['value'];
          _proposalPending = true;
          widget.onChanged(payload['value']);
          // UIKit updates optimistically. Reapply the caller's controlled value
          // after the next frame, whether it accepts or rejects the edit.
          _sent = null;
          _scheduleFlush();
        }
      }
      return null;
    });
    await _flush();
  }

  void _scheduleFlush() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _updateConfiguration();
        _flush();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _flush() async {
    if (_writing || _channel == null) return;
    _writing = true;
    try {
      while (mounted && _channel != null && !mapEquals(_sent, _desired)) {
        final channel = _channel!;
        final configuration = _desired!;
        await channel.invokeMethod<void>('setConfiguration', configuration);
        if (!mounted || channel != _channel) return;
        _sent = configuration;
      }
    } on PlatformException catch (error) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          library: 'flutter_adaptive_liquid_glass',
          context: ErrorDescription(
            'updating the native ${widget.kind} picker',
          ),
        ),
      );
    } finally {
      _writing = false;
    }
  }

  void _updateConfiguration() {
    var suppressed = false;
    var popupOwner = false;
    for (final ancestor in _ancestorRoutes()) {
      suppressed |=
          (ancestor.isActive && !ancestor.isCurrent) ||
          nativeRouteCoverage.covers(ancestor);
      popupOwner |= ancestor is PopupRoute;
    }
    final configuration = <String, Object?>{
      ...widget.configuration,
      'dark': Theme.of(context).brightness == Brightness.dark,
      'rtl': Directionality.of(context) == TextDirection.rtl,
      'suppressed': suppressed,
      'popupOwner': popupOwner,
    };
    final echo =
        _lastProposedValue != null &&
        _lastProposedValue == configuration['value'];
    final interactionChanged = const [
      'mode',
      'style',
      'minimumDate',
      'maximumDate',
      'minuteInterval',
      'locale',
      'enabled',
      'rtl',
      'suppressed',
      'supportsAlpha',
    ].any((key) => configuration[key] != _configuration[key]);
    final activationModeChanged =
        widget.kind == 'color' &&
        (configuration['semanticLabel'] == null) !=
            (_configuration['semanticLabel'] == null);
    final reset =
        _configuration.isEmpty ||
        interactionChanged ||
        activationModeChanged ||
        (configuration['value'] != _configuration['value'] && !echo) ||
        (_proposalPending && !echo);
    if (reset) {
      ++_revision;
      _lastProposedValue = null;
    }
    _proposalPending = false;
    _configuration = configuration;
    // Accepted echoes acknowledge UIKit's optimistic value without resetting a
    // wheel/color drag or invalidating events already queued by that gesture.
    _desired = {
      ...configuration,
      'revision': _revision,
      'valueIsEcho': !reset && echo,
    };
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      nativeRouteCoverage,
      for (final route in _ancestorRoutes().whereType<TransitionRoute>())
        route.secondaryAnimation,
    ]),
    builder: (context, child) => _buildPicker(context),
  );

  Widget _buildPicker(BuildContext context) {
    _updateConfiguration();
    if (!mapEquals(_sent, _desired)) _scheduleFlush();
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: NativeVisibility(
        child: UiKitView(
          viewType: 'flutter_adaptive_liquid_glass/${widget.kind}_picker',
          creationParams: _desired,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _created,
          gestureRecognizers: {
            Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nativeRouteCoverage.removeListener(_coverageChanged);
    final channel = _channel;
    _channel = null;
    channel?.setMethodCallHandler(null);
    // Platform-view disposal owns the UIKit lifetime; no global channel or
    // retained callback is shared with another picker.
    super.dispose();
  }
}

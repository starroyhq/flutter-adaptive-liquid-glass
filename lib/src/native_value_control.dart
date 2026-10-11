import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';
import 'native_visibility.dart';

/// Internal bridge shared by the three controlled native value controls.
class NativeValueControl extends StatefulWidget {
  const NativeValueControl({
    super.key,
    required this.kind,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.step = 1,
    this.wraps = false,
    this.accent,
    this.semanticLabel,
    this.semanticValue,
    this.onChangeStart,
    this.onChangeEnd,
  });

  final String kind;
  final double value, min, max, step;
  final int? divisions;
  final bool enabled, wraps;
  final Color? accent;
  final String? semanticLabel, semanticValue;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart, onChangeEnd;

  @override
  State<NativeValueControl> createState() => _NativeValueControlState();
}

class _NativeValueControlState extends State<NativeValueControl>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  Map<String, Object?> _configuration = {};
  Future<void> _pending = Future<void>.value();
  int _revision = 0;
  bool _reconcileScheduled = false;
  double? _lastProposedValue;
  bool _proposalPending = false;
  int? _activeGesture;
  int _lastGesture = 0;
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
    _activeGesture = null;
    _lastProposedValue = null;
    _proposalPending = false;
    // Keep the gesture watermark: an old start relabeled with a newer revision
    // must not reopen a gesture invalidated by lifecycle or route coverage.
  }

  void _coverageChanged() {
    final covered = _coverageRoutes.any(nativeRouteCoverage.covers);
    if (_routeCovered == covered) return;
    _routeCovered = covered;
    // A popup can open and finish before Flutter builds. Invalidate on entry,
    // rather than allowing a later message to revive its interrupted gesture.
    if (covered) _invalidateInteraction();
    _scheduleReconcile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_applicationActive == active) return;
    _applicationActive = active;
    if (!active) _invalidateInteraction();
    _scheduleReconcile();
  }

  void _scheduleReconcile() {
    if (!mounted || _reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (mounted) _send(force: true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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

  Map<String, Object?> _props() => {
    'kind': widget.kind,
    'value': widget.value,
    'min': widget.min,
    'max': widget.max,
    'divisions': widget.divisions,
    'step': widget.step,
    'wraps': widget.wraps,
    'enabled': widget.enabled,
    'accent': widget.accent?.toARGB32(),
    'semanticLabel': widget.semanticLabel,
    'semanticValue': widget.semanticValue,
    'rtl': Directionality.of(context) == TextDirection.rtl,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'popupOwner': _popupOwner(),
    'suppressed': _routeSuppressed(),
  };

  bool _routeSuppressed() {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      // A nested Navigator can keep its own page current while an ancestor
      // popup/page is covered. UIKit must cancel tracking in that case too.
      // Inactive popped routes retain their native control during the exit.
      if ((route.isActive && !route.isCurrent) ||
          nativeRouteCoverage.covers(route)) {
        return true;
      }
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return false;
  }

  bool _popupOwner() {
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      if (route is PopupRoute) return true;
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return false;
  }

  void _send({bool force = false}) {
    final props = _props();
    final changed = !mapEquals(props, _configuration);
    if (!force && !changed) return;
    final echo = _lastProposedValue == widget.value;
    final interactionChanged = const [
      'kind',
      'min',
      'max',
      'divisions',
      'step',
      'wraps',
      'enabled',
      'rtl',
      'suppressed',
    ].any((key) => props[key] != _configuration[key]);
    final reset =
        _configuration.isEmpty ||
        interactionChanged ||
        (props['value'] != _configuration['value'] && !echo) ||
        (_proposalPending && !echo);
    if (reset) {
      _invalidateInteraction();
    }
    _proposalPending = false;
    _configuration = props;
    // Revision identifies an authoritative interaction generation, not a
    // parent accepting onChanged. Echoes must not invalidate queued end events
    // or rewind UIKit while the user's finger is still moving.
    final payload = {
      ...props,
      'revision': _revision,
      'valueIsEcho': !reset && echo,
    };
    final channel = _channel;
    if (channel == null) return;
    _pending = _pending.then((_) async {
      if (!mounted || channel != _channel) return;
      try {
        await channel.invokeMethod<void>('configure', payload);
      } on MissingPluginException {
        if (mounted && channel == _channel) rethrow;
      } on PlatformException {
        if (mounted && channel == _channel) rethrow;
      }
    });
    // Report a live bridge failure and leave the queue usable for later updates.
    _pending = _pending.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_adaptive_liquid_glass',
          context: ErrorDescription('updating a native value control'),
        ),
      );
    });
  }

  Future<void> _handle(MethodCall call) async {
    if (!mounted ||
        call.method != 'valueEvent' ||
        !_applicationActive ||
        !LiquidGlassFeedback.canInteract(context)) {
      return;
    }
    final event = call.arguments;
    if (event is! Map || event['revision'] != _revision) return;
    final raw = event['value'];
    if (raw is! num || !raw.isFinite || !widget.enabled) return;
    final value = raw.toDouble().clamp(widget.min, widget.max);
    final phase = event['phase'];
    if (widget.kind == 'slider') {
      final gesture = event['gestureId'];
      if (gesture is! int || gesture <= 0) return;
      if (phase == 'start') {
        if (gesture <= _lastGesture) return;
        _lastGesture = gesture;
        _activeGesture = gesture;
        widget.onChangeStart?.call(value);
        return;
      }
      if (gesture != _activeGesture) return;
      if (phase == 'end' || phase == 'cancel') _activeGesture = null;
    } else if (phase != 'change') {
      return;
    }
    switch (phase) {
      case 'change':
        _lastProposedValue = value;
        _proposalPending = true;
        widget.onChanged(value);
      case 'end':
        widget.onChangeEnd?.call(value);
      case 'cancel':
        // Cancellation restores the controlled value without reporting a commit.
        break;
      default:
        return;
    }
    // The parent may reject an edit without rebuilding. Re-apply its value after
    // callbacks and the next frame so UIKit cannot retain an unaccepted edit.
    _scheduleReconcile();
  }

  void _created(int id) {
    _channel?.setMethodCallHandler(null);
    final channel = MethodChannel(
      'flutter_adaptive_liquid_glass/value-control/$id',
    );
    _channel = channel;
    _lastGesture = 0;
    _activeGesture = null;
    channel.setMethodCallHandler((call) async {
      if (mounted && _channel == channel) await _handle(call);
    });
    _send(force: true);
  }

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
      for (final route in _ancestorRoutes().whereType<TransitionRoute>())
        route.secondaryAnimation,
    ]),
    builder: (context, child) => _buildControl(context),
  );

  Widget _buildControl(BuildContext context) {
    _send();
    return NativeVisibility(
      child: SizedBox(
        height: 48,
        width: switch (widget.kind) {
          'switch' => 76,
          'stepper' => 104,
          _ => null,
        },
        child: UiKitView(
          key: ValueKey(widget.kind),
          viewType: 'flutter_adaptive_liquid_glass/value-control',
          creationParams: {..._configuration, 'revision': _revision},
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _created,
          gestureRecognizers: {
            if (widget.kind != 'slider' || widget.enabled) ...{
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              if (widget.kind != 'stepper')
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
              if (widget.kind == 'stepper')
                Factory<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(),
                ),
            },
          },
        ),
      ),
    );
  }
}

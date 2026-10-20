import 'dart:async';

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'native_visibility.dart';
import 'theme.dart';

/// Keeps the hit region still while giving fallback controls tactile feedback.
/// Explicit colors also work when the embedding app disables Material splashes.
class FallbackPressable extends StatefulWidget {
  const FallbackPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.scaleOnPress = true,
    this.onLongPress,
    this.longPressSemanticLabel,
    this.feedbackOnTap = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool scaleOnPress;
  final VoidCallback? onLongPress;
  final String? longPressSemanticLabel;
  final bool feedbackOnTap;

  @override
  State<FallbackPressable> createState() => _FallbackPressableState();
}

class _FallbackPressableState extends State<FallbackPressable>
    with WidgetsBindingObserver {
  bool _pressed = false;
  bool _pointerSequence = false, _cancelled = false;
  int _sequence = 0;
  int? _pointer;
  final _pointers = <int>{};
  bool _blocked = false;
  int _interactionGeneration = 0;
  final _focusNode = FocusNode();

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nativeRouteCoverage.addListener(_checkInteraction);
  }

  void _cancel() {
    _cancelled = true;
    if (_pressed && mounted) setState(() => _pressed = false);
  }

  void _checkInteraction() {
    final blocked = !_enabled || !LiquidGlassFeedback.canInteract(context);
    if (blocked && !_blocked) {
      // A popup or lifecycle interruption may remove the original hit-test
      // path before its terminal pointer event arrives. Retire both the local
      // pointer and InkWell's recognizers; stale callbacks cannot act after
      // this control becomes available again. A pointer merely leaving its
      // bounds still uses _cancel, preserving multi-touch cancellation.
      ++_interactionGeneration;
      ++_sequence;
      _pointer = null;
      _pointers.clear();
      _pointerSequence = false;
      _cancelled = true;
      setState(() => _pressed = false);
    }
    _blocked = blocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _checkInteraction();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkInteraction();
  }

  bool _canInvoke(int generation) =>
      mounted &&
      generation == _interactionGeneration &&
      _enabled &&
      (!_pointerSequence || !_cancelled) &&
      LiquidGlassFeedback.canInteract(context);

  void _endPointer(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.isNotEmpty) {
      _cancel();
      return;
    }
    // InkWell resolves the gesture after Listener receives the same pointer up.
    // Retain its cancellation until that dispatch ends, not until another frame.
    final sequence = _sequence;
    scheduleMicrotask(() {
      if (mounted && sequence == _sequence && _pointers.isEmpty) {
        _pointerSequence = false;
        _pointer = null;
      }
    });
  }

  @override
  void didUpdateWidget(FallbackPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkInteraction();
  }

  @override
  void dispose() {
    nativeRouteCoverage.removeListener(_checkInteraction);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _interactionGeneration;
    final colors = LiquidGlassTheme.of(context).colors;
    final reduced =
        LiquidGlassTheme.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) {
        if (!_enabled || !LiquidGlassFeedback.canInteract(context)) {
          return;
        }
        _pointers.add(event.pointer);
        if (_pointer != null) {
          // Keep a multi-touch batch cancelled until every participating
          // pointer ends. InkWell may start tracking a second pointer once
          // the first exceeds slop, even before the first pointer lifts.
          _cancel();
          return;
        }
        _pointer = event.pointer;
        ++_sequence;
        _pointerSequence = true;
        _cancelled = false;
      },
      onPointerMove: (event) {
        if (event.pointer != _pointer) return;
        final box = context.findRenderObject();
        if (box is RenderBox &&
            !(Offset.zero & box.size).contains(event.localPosition)) {
          _cancel();
        }
      },
      onPointerCancel: (event) {
        if (!_pointers.contains(event.pointer)) return;
        _cancel();
        _endPointer(event.pointer);
      },
      onPointerUp: (event) {
        if (_pointers.contains(event.pointer)) _endPointer(event.pointer);
      },
      child: Semantics(
        onLongPressHint: widget.longPressSemanticLabel,
        child: InkWell(
          key: ValueKey(generation),
          focusNode: _focusNode,
          borderRadius: widget.borderRadius,
          enableFeedback: false,
          onTap: widget.onTap == null
              ? null
              : () {
                  if (!_canInvoke(generation)) return;
                  if (widget.feedbackOnTap) LiquidGlassFeedback.tap(context);
                  widget.onTap?.call();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  if (!_canInvoke(generation)) return;
                  LiquidGlassFeedback.longPress(context);
                  widget.onLongPress?.call();
                },
          onHighlightChanged: (pressed) {
            if (!mounted || generation != _interactionGeneration) return;
            if (_pressed != pressed) setState(() => _pressed = pressed);
          },
          splashFactory: NoSplash.splashFactory,
          // InkWell's adaptive default shows the click cursor only on the web.
          mouseCursor: WidgetStateMouseCursor.clickable,
          // A hovering pointer gets a lighter highlight than a press or focus.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            final active =
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused);
            if (!active && !states.contains(WidgetState.hovered)) {
              return Colors.transparent;
            }
            return (colors.foreground ??
                    Theme.of(context).colorScheme.onSurface)
                .withValues(alpha: active ? .06 : .04);
          }),
          child: AnimatedScale(
            scale: _pressed && !reduced && widget.scaleOnPress ? .97 : 1,
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

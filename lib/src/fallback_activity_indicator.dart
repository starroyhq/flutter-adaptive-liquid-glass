import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'native_visibility.dart';

/// Package-owned activity drawing; no platform picker/indicator widget involved.
class FallbackGlassActivityIndicator extends StatefulWidget {
  const FallbackGlassActivityIndicator({
    super.key,
    required this.animating,
    required this.color,
    required this.radius,
  });

  final bool animating;
  final Color color;
  final double radius;

  @override
  State<FallbackGlassActivityIndicator> createState() =>
      _FallbackGlassActivityIndicatorState();
}

class _FallbackGlassActivityIndicatorState
    extends State<FallbackGlassActivityIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    nativeRouteCoverage.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(FallbackGlassActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();

  void _sync() {
    if (!mounted) return;
    if (widget.animating &&
        _tickerEnabled &&
        LiquidGlassFeedback.canInteract(context)) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void dispose() {
    nativeRouteCoverage.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.radius * 2),
      painter: FallbackActivityPainter(
        animation: _animation,
        color: widget.color,
        animating: widget.animating,
      ),
    ),
  );
}

class FallbackActivityPainter extends CustomPainter {
  FallbackActivityPainter({
    required this.animation,
    required this.color,
    required this.animating,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool animating;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2;
    final phase = animating ? (animation.value * 12).floor() % 12 : 0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .16;
    final center = size.center(Offset.zero);
    for (var i = 0; i < 12; i++) {
      final distance = (phase - i) % 12;
      final opacity = animating ? 1 - distance / 14 : (i < 9 ? .65 : .16);
      paint.color = color.withValues(alpha: color.a * opacity);
      final angle = i * math.pi / 6 - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * radius * .5,
        center + direction * radius * .86,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FallbackActivityPainter oldDelegate) =>
      color != oldDelegate.color ||
      animating != oldDelegate.animating ||
      animation != oldDelegate.animation;
}

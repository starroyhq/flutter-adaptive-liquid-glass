import 'package:flutter/widgets.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';

void main() {
  runApp(
    WidgetsApp(
      color: const Color(0xFFF4F7FA),
      builder: (context, child) =>
          const LiquidGlassWindowGeometryScope(child: _WindowGeometryPage()),
    ),
  );
}

class _WindowGeometryPage extends StatelessWidget {
  const _WindowGeometryPage();

  @override
  Widget build(BuildContext context) {
    final geometry = LiquidGlassWindowGeometry.of(context);
    final controlMargins = geometry.windowControlMargins;
    return ColoredBox(
      color: const Color(0xFFF4F7FA),
      child: Stack(
        children: [
          for (final region in geometry.reservedRegions)
            Positioned.fromRect(
              rect: region.bounds.inflate(1),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x204167A6),
                    border: Border.all(color: const Color(0xFF4167A6)),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Color(0xFF1A2839),
                fontSize: 16,
                height: 1.35,
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('Window geometry', style: _headingStyle),
                  const SizedBox(height: 4),
                  Text(
                    '${_number(geometry.size.width)} × '
                    '${_number(geometry.size.height)} logical pixels',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Vertical bar: ${geometry.verticalBarEdge?.name ?? '—'}',
                  ),
                  Text(
                    'Size classes: '
                    '${geometry.horizontalSizeClass?.name ?? '—'} horizontal, '
                    '${geometry.verticalSizeClass?.name ?? '—'} vertical',
                  ),
                  Text('Safe area: ${_insets(geometry.safeArea)}'),
                  if (controlMargins != null)
                    Text('Window controls: ${_insets(controlMargins)}'),
                  Text('Display features: ${geometry.displayFeatures.length}'),
                  const SizedBox(height: 20),
                  Text(
                    'Reserved regions (${geometry.reservedRegions.length})',
                    style: _sectionStyle,
                  ),
                  for (final region in geometry.reservedRegions) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${region.kind.name} · ${region.isActive ? 'active' : 'inactive'}'
                      ' · ${region.posture.name}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'x ${_number(region.bounds.left)}, '
                      'y ${_number(region.bounds.top)} · '
                      '${_number(region.bounds.width)} × '
                      '${_number(region.bounds.height)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
  );

  static const _sectionStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static String _number(double value) =>
      value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

  static String _insets(EdgeInsets insets) =>
      'top ${_number(insets.top)}, right ${_number(insets.right)}, '
      'bottom ${_number(insets.bottom)}, left ${_number(insets.left)}';
}

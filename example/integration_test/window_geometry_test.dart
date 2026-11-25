import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const expectDuoOuterScreen = bool.fromEnvironment('GLASS_EXPECT_DUO_OUTER');

  testWidgets(
    'subscribed Flutter view receives native UIKit geometry',
    (tester) async {
      LiquidGlassWindowGeometry? observed;
      Size? mediaSize;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => LiquidGlassWindowGeometryScope(
            child: Builder(
              builder: (context) {
                observed = LiquidGlassWindowGeometry.of(context);
                mediaSize = MediaQuery.sizeOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 80; attempt++) {
        if (observed?.horizontalSizeClass != null &&
            observed?.verticalSizeClass != null &&
            (!expectDuoOuterScreen || observed?.verticalBarEdge != null)) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      final geometry = observed!;
      expect(geometry.horizontalSizeClass, isNotNull);
      expect(geometry.verticalSizeClass, isNotNull);
      expect(geometry.size, mediaSize);
      expect(geometry.size.isEmpty, isFalse);
      if (expectDuoOuterScreen) {
        expect(
          geometry.horizontalSizeClass,
          LiquidGlassWindowSizeClass.compact,
        );
        expect(geometry.verticalBarEdge, isNotNull);
      }
      debugPrint(
        'UIKit geometry: ${geometry.size.width}×${geometry.size.height}, '
        '${geometry.horizontalSizeClass?.name}/'
        '${geometry.verticalSizeClass?.name}, '
        'vertical edge ${geometry.verticalBarEdge?.name}, '
        'reserved regions ${geometry.reservedRegions.length}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    skip: defaultTargetPlatform != TargetPlatform.iOS,
  );
}

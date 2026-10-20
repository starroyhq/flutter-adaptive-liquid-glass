import 'package:flutter/foundation.dart';
import 'package:flutter_adaptive_liquid_glass/flutter_adaptive_liquid_glass.dart';
import 'package:flutter_adaptive_liquid_glass/src/native_platform.dart';
import 'package:flutter_test/flutter_test.dart';

bool _supported(
  String version, {
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.iOS,
  bool isIOS = true,
}) => liquidGlassSupportedFor(
  isWeb: isWeb,
  targetPlatform: platform,
  isIOS: isIOS,
  operatingSystemVersion: version,
);

void main() {
  test('iOS 26 and later have native glass', () {
    expect(_supported('Version 26.5 (Build 23F73)'), isTrue);
    expect(_supported('Version 26.0 (Build 23A341)'), isTrue);
    expect(_supported('Version 27.1 (Build 24B94)'), isTrue);
  });

  test('earlier iOS and an unreadable version do not', () {
    expect(_supported('Version 18.6 (Build 22G86)'), isFalse);
    expect(_supported(''), isFalse);
    expect(_supported('Version unknown'), isFalse);
  });

  test('another target platform, a non-iOS host and the web do not', () {
    const version = 'Version 26.5 (Build 23F73)';
    expect(_supported(version, platform: TargetPlatform.android), isFalse);
    expect(_supported(version, platform: TargetPlatform.macOS), isFalse);
    expect(_supported(version, isIOS: false), isFalse);
    expect(_supported(version, isWeb: true), isFalse);
  });

  testWidgets(
    'a test host is not native, even when it targets iOS',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      expect(liquidGlassNativeAvailable, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

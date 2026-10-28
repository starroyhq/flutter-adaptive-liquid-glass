import 'package:flutter/foundation.dart';

final Set<String> _reported = {};

/// In debug builds, explains once per process why a control whose resolved
/// mode is native draws its Flutter rendering instead. Call it only when the
/// resolved mode is [LiquidGlassMode.native]; release and profile builds
/// never print.
void reportNativeFallback(String control, String reason, String fix) {
  assert(() {
    if (_reported.add('$control\u0000$reason')) {
      debugPrint(
        'flutter_adaptive_liquid_glass: $control uses Flutter rendering '
        'instead of native glass: $reason. $fix',
      );
    }
    return true;
  }());
}

/// Forgets the reasons already printed, so each test starts clean.
@visibleForTesting
void debugResetNativeFallbackReports() => _reported.clear();

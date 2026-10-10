import 'package:flutter/foundation.dart';

/// Allows the feedback explicitly produced by this package.
///
/// System controls and the retained Material calendar may provide their own
/// feedback. These options do not override device settings or mute those controls.
@immutable
class LiquidGlassFeedbackData {
  const LiquidGlassFeedbackData({this.haptics = true, this.sound = true});

  final bool haptics;
  final bool sound;

  LiquidGlassFeedbackData copyWith({bool? haptics, bool? sound}) =>
      LiquidGlassFeedbackData(
        haptics: haptics ?? this.haptics,
        sound: sound ?? this.sound,
      );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassFeedbackData &&
      haptics == other.haptics &&
      sound == other.sound;

  @override
  int get hashCode => Object.hash(haptics, sound);
}

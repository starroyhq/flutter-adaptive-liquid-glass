import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'native_visibility.dart';
import 'theme.dart';

/// One dispatch point for package-owned interactions, never native value echoes.
abstract final class LiquidGlassFeedback {
  static bool canInteract(BuildContext context) {
    if (!context.mounted) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    Route<dynamic>? route = ModalRoute.of(context);
    final visited = <Route<dynamic>>{};
    while (route != null && visited.add(route)) {
      if (!route.isCurrent || nativeRouteCoverage.covers(route)) return false;
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    return true;
  }

  static void tap(BuildContext context) {
    if (!canInteract(context)) return;
    context.findRenderObject()?.sendSemanticsEvent(const TapSemanticEvent());
    if (LiquidGlassTheme.of(context).feedback.sound &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.fuchsia)) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  static void longPress(BuildContext context) {
    if (!canInteract(context)) return;
    context.findRenderObject()?.sendSemanticsEvent(
      const LongPressSemanticsEvent(),
    );
    final policy = LiquidGlassTheme.of(context).feedback;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        if (policy.haptics) unawaited(HapticFeedback.heavyImpact());
        if (policy.sound) unawaited(SystemSound.play(SystemSoundType.click));
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        if (policy.haptics) unawaited(HapticFeedback.vibrate());
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
    }
  }

  static void selection(BuildContext context) {
    if (!canInteract(context)) return;
    if (LiquidGlassTheme.of(context).feedback.haptics &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  static void wheel(BuildContext context) {
    selection(context);
    if (canInteract(context) &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        LiquidGlassTheme.of(context).feedback.sound) {
      unawaited(SystemSound.play(SystemSoundType.tick));
    }
  }
}

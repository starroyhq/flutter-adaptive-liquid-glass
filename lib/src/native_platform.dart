// Adapted from native_liquid_glass 0.3.1 (MIT); see THIRD_PARTY_NOTICES.md.
import 'package:flutter/foundation.dart';

import 'native_platform_stub.dart'
    if (dart.library.io) 'native_platform_io.dart'
    as platform;

/// The first iOS major version with Liquid Glass.
const _firstGlassVersion = 26;

int? _iosMajorVersion;
bool _iosVersionRead = false;

/// Whether this process runs on iOS 26 or later.
///
/// Synchronous, so it holds from the first frame. The target platform is
/// checked on every call; the iOS major version is read once from the
/// operating system version and kept, and an unreadable version counts as 0.
/// `UIDesignRequiresCompatibility` is not consulted.
bool get liquidGlassPlatformSupported {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  if (!_iosVersionRead) {
    _iosVersionRead = true;
    if (platform.isIOS) {
      _iosMajorVersion = _majorVersion(platform.operatingSystemVersion);
    }
  }
  return (_iosMajorVersion ?? 0) >= _firstGlassVersion;
}

/// [liquidGlassPlatformSupported] for the given platform facts.
@visibleForTesting
bool liquidGlassSupportedFor({
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required bool isIOS,
  required String operatingSystemVersion,
}) =>
    !isWeb &&
    targetPlatform == TargetPlatform.iOS &&
    isIOS &&
    (_majorVersion(operatingSystemVersion) ?? 0) >= _firstGlassVersion;

/// The first number in a version such as "Version 26.5 (Build 23F73)".
int? _majorVersion(String version) {
  final match = RegExp(r'(\d+)').firstMatch(version);
  return match == null ? null : int.tryParse(match.group(1)!);
}

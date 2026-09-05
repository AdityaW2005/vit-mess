import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the running build's own metadata.
///
/// The only file that touches `package_info_plus`. Reading the version from
/// the installed package rather than repeating it in Dart is what keeps the
/// footer from drifting out of step with `pubspec.yaml`.
class AppInfoService {
  /// Creates the service.
  AppInfoService();

  /// The marketing version, e.g. `1.0.0`, or `null` when the platform cannot
  /// say — a plain unit test, for instance.
  Future<String?> version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      return version.isEmpty ? null : version;
    } on Object catch (error) {
      debugPrint('AppInfoService.version failed: $error');
      return null;
    }
  }
}

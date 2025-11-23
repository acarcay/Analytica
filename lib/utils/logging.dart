import 'package:flutter/foundation.dart';

/// Simple app-level logging helper.
/// In release builds logs are suppressed to avoid leaking secrets.
class AppLog {
  AppLog._();

  /// Debug log: only prints when not in release mode.
  static void d(String message) {
    if (!kReleaseMode) {
      // use debugPrint to avoid clipped output in long messages
      debugPrint(message);
    }
  }

  /// Info log: prints in all modes (use sparingly).
  static void i(String message) {
    debugPrint(message);
  }

  /// Error log: prints in all modes (use sparingly), could be extended to report to Crashlytics.
  static void e(String message) {
    debugPrint('ERROR: $message');
  }
}

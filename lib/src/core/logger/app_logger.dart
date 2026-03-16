import 'package:flutter/foundation.dart';

/// Utilidad de logging centralizada.
/// Solo imprime en modo debug (kDebugMode), garantizando que
/// no se filtra información sensible en producción.
class AppLogger {
  AppLogger._();

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[INFO]${_tag(tag)} $message');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      debugPrint('[WARN]${_tag(tag)} $message');
    }
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      debugPrint('[ERROR]${_tag(tag)} $message');
      if (error != null) debugPrint('  ↳ Error: $error');
      if (stackTrace != null) debugPrint('  ↳ StackTrace: $stackTrace');
    }
  }

  static String _tag(String? tag) => tag != null ? '[$tag]' : '';
}


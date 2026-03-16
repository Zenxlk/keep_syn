import 'package:cloud_functions/cloud_functions.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/core/logger/app_logger.dart';

class FirebaseLogUser {
  final String? uid;
  final String? email;

  const FirebaseLogUser({
    this.uid,
    this.email,
  });

  bool get isEmpty {
    final hasUid = uid != null && uid!.trim().isNotEmpty;
    final hasEmail = email != null && email!.trim().isNotEmpty;
    return !hasUid && !hasEmail;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (uid != null && uid!.trim().isNotEmpty) 'uid': uid,
      if (email != null && email!.trim().isNotEmpty) 'email': email,
    };
  }
}

abstract class IFirebaseErrorLogger {
  Future<void> logException(
      AppException exception, {
        required String feature,
        String? tag,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
        FirebaseLogUser? user,
      });

  Future<void> logError(
      Object error, {
        required String feature,
        String? tag,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
        FirebaseLogUser? user,
      });
}

class FirebaseErrorLoggerImpl implements IFirebaseErrorLogger {
  FirebaseErrorLoggerImpl({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<void> logException(
      AppException exception, {
        required String feature,
        String? tag,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
        FirebaseLogUser? user,
      }) async {
    await _send(
      severity: 'ERROR',
      feature: feature,
      errorType: exception.runtimeType.toString(),
      message: exception.message,
      tag: tag,
      stackTrace: stackTrace?.toString(),
      metadata: metadata,
      user: user,
    );
  }

  @override
  Future<void> logError(
      Object error, {
        required String feature,
        String? tag,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
        FirebaseLogUser? user,
      }) async {
    await _send(
      severity: 'ERROR',
      feature: feature,
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      tag: tag,
      stackTrace: stackTrace?.toString(),
      metadata: metadata,
      user: user,
    );
  }

  Future<void> _send({
    required String severity,
    required String feature,
    required String errorType,
    required String message,
    String? tag,
    String? stackTrace,
    Map<String, dynamic>? metadata,
    FirebaseLogUser? user,
  }) async {
    try {
      final callable = _functions.httpsCallable('logClientError');

      await callable.call(<String, dynamic>{
        'severity': severity,
        'feature': feature,
        'errorType': errorType,
        'message': message,
        'tag': tag,
        'stackTrace': stackTrace,
        'metadata': _sanitizeMap(metadata ?? <String, dynamic>{}),
        'user': user != null && !user.isEmpty ? user.toMap() : null,
      });
    } catch (e, st) {
      AppLogger.warning(
        'No se pudo enviar log remoto: $e',
        tag: 'FirebaseErrorLogger',
      );
      AppLogger.error(
        'Stack de fallo en logger remoto.',
        error: e,
        stackTrace: st,
        tag: 'FirebaseErrorLogger',
      );
    }
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    return input.map((key, value) {
      return MapEntry(key, _sanitizeValue(value));
    });
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is Map) {
      return value.map(
            (key, nestedValue) => MapEntry(
          key.toString(),
          _sanitizeValue(nestedValue),
        ),
      );
    }

    if (value is Iterable) {
      return value.map(_sanitizeValue).toList();
    }

    return value.toString();
  }
}

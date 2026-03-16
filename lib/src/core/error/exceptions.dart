// Excepciones tipadas de la capa de datos.
// Se lanzan en los DataSources y se capturan en los Repositories,
// donde se convierten en Failures del dominio.

abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Error genérico del servidor / red.
class ServerException extends AppException {
  const ServerException([super.message = 'Error en el servidor.']);
}

/// El usuario canceló el flujo de autenticación.
class AuthCancelledException extends AppException {
  const AuthCancelledException([super.message = 'Inicio de sesión cancelado por el usuario.']);
}

/// El usuario de Firebase/Google no se pudo obtener tras el login.
class AuthUserNullException extends AppException {
  const AuthUserNullException([super.message = 'No se pudo obtener el usuario tras la autenticación.']);
}

/// El usuario no está en la allowlist de acceso.  ← NUEVO
class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'No tienes acceso a esta aplicación.']);
}

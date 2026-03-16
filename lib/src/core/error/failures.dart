import 'package:equatable/equatable.dart';

/// Fallo de dominio. Los repositorios devuelven [Failure] (vía Either)
/// en lugar de lanzar excepciones, para que la capa de dominio/presentación
/// pueda manejarlos de forma tipada.
abstract class Failure extends Equatable {
  final String? message;
  const Failure({this.message});

  @override
  List<Object?> get props => [message];
}

/// Error genérico de servidor o red.
class ServerFailure extends Failure {
  const ServerFailure({super.message});
}

/// El usuario canceló el flujo de autenticación.
class SignInCancelledFailure extends Failure {
  const SignInCancelledFailure({super.message});
}

/// No hay conexión a Internet.
class NetworkFailure extends Failure {
  const NetworkFailure({super.message});
}

/// El usuario no tiene permisos suficientes.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message});
}

/// Error al sincronizar playlists entre plataformas.
class SyncFailure extends Failure {
  const SyncFailure({super.message});
}

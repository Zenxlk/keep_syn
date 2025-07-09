import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart';

abstract class IAuthRepository {
  // Inicio de sesión con Google
  // Retorna un objeto Future que contiene un objeto Either que puede contener un objeto Failure o un objeto User.
  Future<Either<Failure, User>> signInWithGoogle();

  // Cerrar sesión
  Future<void> signOut();

  // Obtiene el estado de autenticación del usuario en tiempo real.
  // Emite un nuevo 'User' cada vez que el estado cambia (login/logout).
  Stream<User?> get authStateChanges;
}

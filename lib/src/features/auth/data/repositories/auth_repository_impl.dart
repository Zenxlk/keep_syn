import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart';
import 'package:keepsyn_app/src/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final IAuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<User?> get authStateChanges {
    return remoteDataSource.authStateChanges.map((firebaseUser) {
      return firebaseUser != null
          ? User(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName,
            email: firebaseUser.email,
            photoUrl: firebaseUser.photoURL,
          )
          : null;
    });
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();
      return Right(userModel); // Éxito
    } on Exception catch (e) {
      if (e.toString().contains('cancelado')) {
        return Left(SignInCancelledFailure());
      }
      return Left(ServerFailure()); // Error
    }
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}

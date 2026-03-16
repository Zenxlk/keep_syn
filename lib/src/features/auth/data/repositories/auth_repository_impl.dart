import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
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
      return Right(userModel);
    } on AuthCancelledException catch (e) {
      return Left(SignInCancelledFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}

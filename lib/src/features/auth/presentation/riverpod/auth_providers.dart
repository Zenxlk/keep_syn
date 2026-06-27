import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/core/logger/app_logger.dart';
import 'package:keepsyn_app/src/core/logger/firebase_error_logger.dart';
import 'package:keepsyn_app/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:keepsyn_app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart' as app;
import 'package:keepsyn_app/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_controller_state.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(Ref ref) => GoogleSignIn.instance;

@Riverpod(keepAlive: true)
FirebaseFunctions firebaseFunctions(Ref ref) => FirebaseFunctions.instance;

@Riverpod(keepAlive: true)
IFirebaseErrorLogger firebaseErrorLogger(Ref ref) {
  return FirebaseErrorLoggerImpl(
    functions: ref.watch(firebaseFunctionsProvider),
  );
}

@Riverpod(keepAlive: true)
IAuthRemoteDataSource authRemoteDataSource(Ref ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    firebaseErrorLogger: ref.watch(firebaseErrorLoggerProvider),
  );
}

@Riverpod(keepAlive: true)
IAuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  StreamSubscription<app.User?>? _authSub;
  static const _tag = 'AuthController';

  @override
  AuthControllerState build() {
    final repository = ref.watch(authRepositoryProvider);

    _authSub?.cancel();
    _authSub = repository.authStateChanges.listen(
          (user) {
        if (user != null) {
          state = AuthControllerState.authenticated(user);
        } else {
          state = state.copyWith(
            status: AuthSessionStatus.unauthenticated,
            user: null,
            isSubmitting: false,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Error en authStateChanges.',
          error: error,
          stackTrace: stackTrace,
          tag: _tag,
        );

        state = AuthControllerState.unauthenticated(
          failure: ServerFailure(message: 'No se pudo verificar la sesión.'),
        );
      },
    );

    ref.onDispose(() async {
      await _authSub?.cancel();
    });

    return const AuthControllerState.loading();
  }

  Future<void> signInWithGoogle() async {
    if (state.isSubmitting) return;

    state = state.copyWith(
      isSubmitting: true,
      clearFailure: true,
    );

    final Either<Failure, app.User> result =
    await ref.read(authRepositoryProvider).signInWithGoogle();

    result.fold(
          (failure) {
        state = state.copyWith(
          status: AuthSessionStatus.unauthenticated,
          failure: failure,
          isSubmitting: false,
          user: null,
        );
      },
          (user) {
        state = state.copyWith(
          status: AuthSessionStatus.authenticated,
          user: user,
          isSubmitting: false,
          clearFailure: true,
        );
      },
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();

    state = state.copyWith(
      status: AuthSessionStatus.unauthenticated,
      user: null,
      isSubmitting: false,
      clearFailure: true,
    );
  }

  void clearFailure() {
    state = state.copyWith(clearFailure: true);
  }
}

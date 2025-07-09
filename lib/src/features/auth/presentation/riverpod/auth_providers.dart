import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:keepsyn_app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:keepsyn_app/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart' as app;

// PROVEEDORES DE SERVICIOS EXTERNOS

/// Proveedor para la instancia de FirebaseAuth.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Proveedor para la instancia de GoogleSignIn.
final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn.instance,
);

//PROVEEDORES DE LA CAPA DE DATOS

/// Proveedor para nuestro AuthRemoteDataSource.
final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    googleSignIn: ref.watch(googleSignInProvider),
  );
});

/// Proveedor para nuestro AuthRepository.
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

// PROVEEDORES DE ESTADO PARA LA UI

/// Proveedor que expone el Stream de cambios de estado de autenticación.
/// La UI escuchará este provider para saber si hay un usuario logueado o no.
final authStateChangesProvider = StreamProvider<app.User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

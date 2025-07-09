import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/features/auth/data/models/user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();

  Future<void> signOut();

  Stream<firebase.User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  final firebase.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRemoteDataSourceImpl({
    required firebase.FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  @override
  Stream<firebase.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  Future<UserModel> signInWithGoogle() async {
    try {
      // Usamos el método `authenticate` de la instancia singleton.
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.authenticate();

      if (googleUser == null) {
        // El usuario canceló el flujo de inicio de sesión
        throw Exception('Inicio de sesión cancelado por el usuario.');
      }

      // Obtenemos los tokens de autenticación del usuario de Google.
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Creamos la credencial de Firebase con los tokens.
      final firebase.AuthCredential credential = firebase
          .GoogleAuthProvider.credential(idToken: googleAuth.idToken);

      // Iniciamos sesión en Firebase con la credencial.
      final firebase.UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      if (userCredential.user == null) {
        throw Exception('Error al obtener el usuario de Firebase.');
      }

      return UserModel.fromFirebaseUser(userCredential.user!);
    } catch (e) {
      // Re-lanza la excepción para que el repositorio la maneje.
      throw Exception(
        'Error durante el inicio de sesión con Google: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}

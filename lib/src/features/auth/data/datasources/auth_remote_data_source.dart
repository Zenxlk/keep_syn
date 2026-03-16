import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/core/logger/app_logger.dart';
import 'package:keepsyn_app/src/core/logger/firebase_error_logger.dart';
import 'package:keepsyn_app/src/features/auth/data/models/user_model.dart';

abstract class IAuthRemoteDataSource {
  Future<UserModel> signInWithGoogle();
  Future<void> signOut();
  Stream<firebase.User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  final firebase.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;
  final IFirebaseErrorLogger _firebaseErrorLogger;

  static const _tag = 'AuthDataSource';

  AuthRemoteDataSourceImpl({
    required firebase.FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    FirebaseFunctions? functions,
    required IFirebaseErrorLogger firebaseErrorLogger,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _functions = functions ?? FirebaseFunctions.instance,
        _firebaseErrorLogger = firebaseErrorLogger;

  @override
  Stream<firebase.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserModel> signInWithGoogle() async {
    GoogleSignInAccount? selectedGoogleUser;
    firebase.User? authenticatedUser;

    try {
      AppLogger.info('Iniciando flujo Google Sign-In...', tag: _tag);

      selectedGoogleUser = await _googleSignIn.authenticate();

      AppLogger.info(
        'Cuenta seleccionada: ${selectedGoogleUser.email}',
        tag: _tag,
      );

      final GoogleSignInAuthentication googleAuth =
          selectedGoogleUser.authentication;

      final firebase.OAuthCredential credential =
          firebase.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      AppLogger.info('Autenticando en Firebase...', tag: _tag);

      final firebase.UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      authenticatedUser = userCredential.user;

      if (authenticatedUser == null) {
        AppLogger.error('Firebase retornó usuario nulo.', tag: _tag);

        throw const AuthUserNullException();
      }

      AppLogger.info(
        'Sesión Firebase OK — uid: ${authenticatedUser.uid}',
        tag: _tag,
      );

      AppLogger.info('Verificando allowlist...', tag: _tag);

      final callable = _functions.httpsCallable('verifyAccess');
      final result = await callable.call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(result.data as Map);
      final status = data['status'] as String? ?? 'ERROR';
      final serverMessage = data['message'] as String?;

      if (status != 'OK') {
        final exception = UnauthorizedException(
          serverMessage ?? 'No autorizado.',
        );

        AppLogger.warning(
          'ACCESO DENEGADO — ${authenticatedUser.email}: $serverMessage',
          tag: _tag,
        );

        await _firebaseErrorLogger.logException(
          exception,
          feature: 'auth_google_signin',
          tag: _tag,
          user: _buildLogUser(
            firebaseUser: authenticatedUser,
            fallbackEmail: selectedGoogleUser.email,
          ),
          metadata: _buildAuthMetadata(
            step: 'verify_access',
            googleEmail: selectedGoogleUser.email,
            firebaseUid: authenticatedUser.uid,
            firebaseEmail: authenticatedUser.email,
            verifyAccessStatus: status,
            serverMessage: serverMessage,
          ),
        );

        await _firebaseAuth.signOut();
        await _googleSignIn.signOut();

        throw exception;
      }

      AppLogger.info(
        'ACCESO CONCEDIDO — ${authenticatedUser.email}',
        tag: _tag,
      );

      return UserModel.fromFirebaseUser(authenticatedUser);
    } on AuthCancelledException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } on AuthUserNullException catch (e, st) {
      await _firebaseErrorLogger.logException(
        e,
        feature: 'auth_google_signin',
        tag: _tag,
        stackTrace: st,
        user: _buildLogUser(
          firebaseUser: authenticatedUser,
          fallbackEmail: selectedGoogleUser?.email,
        ),
        metadata: _buildAuthMetadata(
          step: 'firebase_user_null',
          googleEmail: selectedGoogleUser?.email,
          firebaseUid: authenticatedUser?.uid,
          firebaseEmail: authenticatedUser?.email,
        ),
      );
      rethrow;
    } catch (e, st) {
      await _firebaseErrorLogger.logError(
        e,
        feature: 'auth_google_signin',
        tag: _tag,
        stackTrace: st,
        user: _buildLogUser(
          firebaseUser: authenticatedUser,
          fallbackEmail: selectedGoogleUser?.email,
        ),
        metadata: _buildAuthMetadata(
          step: 'unexpected_error',
          googleEmail: selectedGoogleUser?.email,
          firebaseUid: authenticatedUser?.uid,
          firebaseEmail: authenticatedUser?.email,
          rawError: e.toString(),
        ),
      );

      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();

      throw ServerException('Error durante el inicio de sesión: $e');
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.info('Cerrando sesión...', tag: _tag);
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    AppLogger.info('Sesión cerrada correctamente.', tag: _tag);
  }

  FirebaseLogUser? _buildLogUser({
    required firebase.User? firebaseUser,
    String? fallbackEmail,
  }) {
    final uid = firebaseUser?.uid;
    final email = firebaseUser?.email ?? fallbackEmail;

    final hasUid = uid != null && uid.trim().isNotEmpty;
    final hasEmail = email != null && email.trim().isNotEmpty;

    if (!hasUid && !hasEmail) {
      return null;
    }

    return FirebaseLogUser(
      uid: uid,
      email: email,
    );
  }

  Map<String, dynamic> _buildAuthMetadata({
    required String step,
    String? googleEmail,
    String? firebaseUid,
    String? firebaseEmail,
    String? verifyAccessStatus,
    String? serverMessage,
    String? rawError,
  }) {
    return <String, dynamic>{
      'step': step,
      if (googleEmail != null) 'googleEmail': googleEmail,
      if (firebaseUid != null) 'firebaseUid': firebaseUid,
      if (firebaseEmail != null) 'firebaseEmail': firebaseEmail,
      if (verifyAccessStatus != null) 'verifyAccessStatus': verifyAccessStatus,
      if (serverMessage != null) 'serverMessage': serverMessage,
      if (rawError != null) 'rawError': rawError,
    };
  }
}

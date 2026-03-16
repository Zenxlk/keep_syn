import 'package:keepsyn_app/src/core/constants/app_constants.dart';

/// Variables de entorno públicas para Flutter.
///
/// Nota: Aqui solo deben vivir valores de configuracion no sensibles.
/// Los secretos reales (p. ej. client_secret) se quedan en backend.
class EnvConstants {
  EnvConstants._();

  static const String serverClientId = String.fromEnvironment(
    'SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String syncApiBaseUrl = String.fromEnvironment(
    'SYNC_API_BASE_URL',
    defaultValue: AppConstants.syncApiBaseUrlDefault,
  );

  static const bool useRealSyncApi = bool.fromEnvironment(
    'USE_REAL_SYNC_API',
    defaultValue: false,
  );

  static const String spotifyClientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '',
  );

  static const String spotifyRedirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'keepsyn://spotify-callback',
  );
}

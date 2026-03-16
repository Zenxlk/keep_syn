/// Constantes globales de la aplicación.
/// Centraliza valores que se usan en múltiples capas.
class AppConstants {
  AppConstants._();

  // ─── App ────────────────────────────────────────────────────────────────────
  static const String appName = 'KeepSyn';
  static const String appVersion = '1.0.0';

  // ─── Plataformas de música soportadas ───────────────────────────────────────
  static const String platformSpotify = 'Spotify';
  static const String platformYouTubeMusic = 'YouTube Music';
  static const String platformAppleMusic = 'Apple Music';

  // ─── Claves de almacenamiento local ─────────────────────────────────────────
  static const String keySelectedPlatforms = 'selected_platforms';
  static const String keyLastSyncDate = 'last_sync_date';
  static const String keyLastSyncStatus = 'last_sync_status';
  static const String keySyncRecentErrors = 'sync_recent_errors';

  // ─── API ────────────────────────────────────────────────────────────────────
  static const String syncApiBaseUrlDefault =
      'https://us-central1-keepsyn-0001.cloudfunctions.net/api';
}

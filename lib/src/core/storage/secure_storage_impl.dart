import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keepsyn_app/src/core/storage/local_storage.dart';

class SecureStorageImpl implements ILocalStorage {
  static const _spotifyAccessTokenKey = 'spotify_access_token';
  static const _spotifyRefreshTokenKey = 'spotify_refresh_token';

  final FlutterSecureStorage _storage;

  SecureStorageImpl({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveSpotifyAccessToken(String token) {
    return saveToken(key: _spotifyAccessTokenKey, value: token);
  }

  @override
  Future<String?> getSpotifyAccessToken() {
    return readToken(_spotifyAccessTokenKey);
  }

  @override
  Future<void> deleteSpotifyAccessToken() {
    return deleteToken(_spotifyAccessTokenKey);
  }

  @override
  Future<void> saveSpotifyRefreshToken(String token) {
    return saveToken(key: _spotifyRefreshTokenKey, value: token);
  }

  @override
  Future<String?> getSpotifyRefreshToken() {
    return readToken(_spotifyRefreshTokenKey);
  }

  @override
  Future<void> deleteSpotifyRefreshToken() {
    return deleteToken(_spotifyRefreshTokenKey);
  }

  @override
  Future<void> saveToken({
    required String key,
    required String value,
  }) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> readToken(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> deleteToken(String key) {
    return _storage.delete(key: key);
  }

  @override
  Future<void> clearAllTokens() {
    return _storage.deleteAll();
  }
}

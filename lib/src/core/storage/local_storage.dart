abstract class ILocalStorage {
  Future<void> saveSpotifyAccessToken(String token);
  Future<String?> getSpotifyAccessToken();
  Future<void> deleteSpotifyAccessToken();

  Future<void> saveSpotifyRefreshToken(String token);
  Future<String?> getSpotifyRefreshToken();
  Future<void> deleteSpotifyRefreshToken();

  Future<void> saveToken({
    required String key,
    required String value,
  });

  Future<String?> readToken(String key);

  Future<void> deleteToken(String key);

  Future<void> clearAllTokens();
}

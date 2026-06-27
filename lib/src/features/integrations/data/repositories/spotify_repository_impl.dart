import 'package:keepsyn_app/src/features/integrations/data/datasources/spotify_remote_data_source.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_playlist_model.dart';
import 'package:keepsyn_app/src/features/integrations/domain/repositories/i_spotify_repository.dart';

class SpotifyRepositoryImpl implements ISpotifyRepository {
  const SpotifyRepositoryImpl({required SpotifyRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final SpotifyRemoteDataSource _dataSource;

  @override
  Future<IntegrationStatus> getStatus() => _dataSource.getStatus();

  @override
  Future<void> linkAccount(
    String code,
    String redirectUri, {
    required String clientId,
  }) => _dataSource.linkAccount(code, redirectUri, clientId: clientId);

  @override
  Future<void> unlinkAccount() => _dataSource.unlinkAccount();

  @override
  Future<List<SpotifyPlaylistModel>> getPlaylists() =>
      _dataSource.getPlaylists();
}

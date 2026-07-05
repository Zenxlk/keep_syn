import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_playlist_model.dart';

abstract interface class ISpotifyRepository {
  Future<IntegrationStatus> getStatus();
  Future<void> linkAccount(String code, String redirectUri, {required String clientId});
  Future<void> unlinkAccount();
  Future<List<SpotifyPlaylistModel>> getPlaylists();
}

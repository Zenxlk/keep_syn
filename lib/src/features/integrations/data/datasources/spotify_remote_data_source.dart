import 'package:dio/dio.dart';
import 'package:keepsyn_app/src/core/constants/standard_response.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_playlist_model.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_track_model.dart';

class SpotifyRemoteDataSource {
  final Dio _dio;

  SpotifyRemoteDataSource(this._dio);

  Future<IntegrationStatus> getStatus() async {
    try {
      final response = await _dio.get('/v1/integrations/spotify/status');
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );

      final statusString = stdRes.data?['status'] as String? ?? 'notConnected';
      return IntegrationStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => IntegrationStatus.error,
      );
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('Error obteniendo estado de Spotify: $e');
    }
  }

  Future<void> linkAccount(
    String authorizationCode,
    String redirectUri, {
    String? clientId,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/integrations/spotify/link',
        data: {
          'code': authorizationCode,
          'redirectUri': redirectUri,
          if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
        },
      );
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!stdRes.isOk) {
        throw ServerException(stdRes.message);
      }
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    }
    catch (e) {
      throw ServerException('Fallo al vincular la cuenta: $e');
    }
  }

  Future<void> unlinkAccount() async {
    try {
      final response = await _dio.post('/v1/integrations/spotify/unlink');
      final stdRes = StandardResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (!stdRes.isOk) {
        throw ServerException(stdRes.message);
      }
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('Fallo al desvincular la cuenta: $e');
    }
  }

  Future<List<SpotifyPlaylistModel>> getPlaylists() async {
    try {
      const pageSize = 50;
      var offset = 0;
      var total = 0;
      final playlists = <SpotifyPlaylistModel>[];

      do {
        final response = await _dio.get(
          '/v1/integrations/spotify/playlists',
          queryParameters: {'limit': pageSize, 'offset': offset},
        );
        final stdRes = StandardResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final data = stdRes.data ?? <String, dynamic>{};
        total = data['total'] is num ? (data['total'] as num).toInt() : 0;

        final items = (data['items'] as List?)?.whereType<Map>().toList() ??
            const <Map>[];
        final chunk = items
            .map(
              (item) => SpotifyPlaylistModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);

        playlists.addAll(chunk);
        offset += chunk.length;

        if (chunk.isEmpty) {
          break;
        }
      } while (offset < total);

      return playlists;
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('No se pudieron obtener playlists: $e');
    }
  }

  Future<List<SpotifyTrackModel>> getPlaylistTracks(String playlistId) async {
    try {
      const pageSize = 100;
      var offset = 0;
      var total = 0;
      final tracks = <SpotifyTrackModel>[];

      do {
        final response = await _dio.get(
          '/v1/integrations/spotify/playlists/$playlistId/tracks',
          queryParameters: {'limit': pageSize, 'offset': offset},
        );
        final stdRes = StandardResponse.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final data = stdRes.data ?? <String, dynamic>{};
        total = data['total'] is num ? (data['total'] as num).toInt() : 0;

        final items = (data['items'] as List?)?.whereType<Map>().toList() ??
            const <Map>[];
        final chunk = items
            .map(
              (item) => SpotifyTrackModel.fromPlaylistTrackJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);

        tracks.addAll(chunk);
        offset += chunk.length;

        if (chunk.isEmpty) {
          break;
        }
      } while (offset < total);

      return tracks;
    } on DioException catch (e) {
      throw ServerException(_extractBackendMessage(e));
    } catch (e) {
      throw ServerException('No se pudieron obtener tracks: $e');
    }
  }

  String _extractBackendMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      final nestedData = data['data'];
      if (nestedData is Map<String, dynamic>) {
        final spotifyError = nestedData['spotifyError'];
        if (spotifyError is Map<String, dynamic>) {
          final errorCode = spotifyError['error'];
          final description = spotifyError['error_description'];
          if (errorCode is String && description is String) {
            return '$message [$errorCode: $description]';
          }
          if (description is String && description.trim().isNotEmpty) {
            return '$message [$description]';
          }
        }

        final redirectReceived = nestedData['redirectUriReceived'];
        final redirectExpected = nestedData['redirectUriExpected'];
        if (redirectReceived is String && redirectExpected is String) {
          return '$message [received=$redirectReceived expected=$redirectExpected]';
        }
      }

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return 'Error HTTP $statusCode al comunicar con Spotify.';
    }

    return e.message ?? 'Error de red al comunicar con Spotify.';
  }
}
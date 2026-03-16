import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:keepsyn_app/src/core/constants/env_constants.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/core/logger/firebase_error_logger.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/integrations/data/datasources/spotify_remote_data_source.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_playlist_model.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_track_model.dart';

const _spotifyScope =
    'playlist-read-private playlist-read-collaborative user-read-email';

final spotifyDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: EnvConstants.syncApiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});

final spotifyDataSourceProvider = Provider<SpotifyRemoteDataSource>((ref) {
  return SpotifyRemoteDataSource(ref.watch(spotifyDioProvider));
});

final spotifyPlaylistsProvider = FutureProvider<List<SpotifyPlaylistModel>>((
  ref,
) async {
  return ref.watch(spotifyDataSourceProvider).getPlaylists();
});

final spotifyPlaylistTracksProvider =
    FutureProvider.family<List<SpotifyTrackModel>, String>((ref, playlistId) {
      return ref.watch(spotifyDataSourceProvider).getPlaylistTracks(playlistId);
    });

final spotifyStatusProvider =
    StateNotifierProvider<SpotifyStatusNotifier, AsyncValue<IntegrationStatus>>(
      (ref) {
        return SpotifyStatusNotifier(
          ref,
          ref.watch(spotifyDataSourceProvider),
          ref.watch(firebaseErrorLoggerProvider),
        );
      },
    );

class SpotifyStatusNotifier
    extends StateNotifier<AsyncValue<IntegrationStatus>> {
  final Ref _ref;
  final SpotifyRemoteDataSource _dataSource;
  final IFirebaseErrorLogger _errorLogger;

  static const _feature = 'spotify_integration';
  static const _tag = 'SpotifyIntegration';

  SpotifyStatusNotifier(this._ref, this._dataSource, this._errorLogger)
    : super(const AsyncValue.loading()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = const AsyncValue.loading();
    try {
      final status = await _dataSource.getStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      await _errorLogger.logError(
        e,
        feature: _feature,
        tag: _tag,
        stackTrace: st,
        metadata: {'action': 'check_status'},
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> linkWithSpotifyOAuth() async {
    if (EnvConstants.spotifyClientId.isEmpty) {
      const error = ServerException(
        'Falta SPOTIFY_CLIENT_ID en dart-define.',
      );
      await _errorLogger.logException(
        error,
        feature: _feature,
        tag: _tag,
        metadata: {'action': 'oauth_start'},
      );
      state = AsyncValue.error(error, StackTrace.current);
      return;
    }

    final redirectUri = Uri.parse(EnvConstants.spotifyRedirectUri);
    if (redirectUri.scheme != 'keepsyn') {
      const error = ServerException(
        'SPOTIFY_REDIRECT_URI invalido. Debe usar scheme keepsyn://',
      );
      await _errorLogger.logException(
        error,
        feature: _feature,
        tag: _tag,
        metadata: {
          'action': 'oauth_start',
          'redirectUri': EnvConstants.spotifyRedirectUri,
        },
      );
      state = AsyncValue.error(error, StackTrace.current);
      return;
    }

    state = const AsyncValue.data(IntegrationStatus.linking);

    try {
      final authUri = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': EnvConstants.spotifyClientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'scope': _spotifyScope,
        'show_dialog': 'true',
      });

      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: redirectUri.scheme,
      );

      final callbackUri = Uri.parse(callbackUrl);
      final authError = callbackUri.queryParameters['error'];
      if (authError != null && authError.isNotEmpty) {
        throw ServerException('Spotify OAuth error: $authError');
      }

      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const ServerException('Spotify no devolvio authorization code.');
      }

      await _dataSource.linkAccount(
        code,
        redirectUri.toString(),
        clientId: EnvConstants.spotifyClientId,
      );

      final confirmedStatus = await _dataSource.getStatus();
      if (confirmedStatus != IntegrationStatus.connected) {
        throw ServerException(
          'Spotify respondio al link, pero el estado confirmado es: '
          '${confirmedStatus.name}.',
        );
      }

      _ref.invalidate(spotifyPlaylistsProvider);
      state = AsyncValue.data(confirmedStatus);
    } catch (e, st) {
      await _errorLogger.logError(
        e,
        feature: _feature,
        tag: _tag,
        stackTrace: st,
        metadata: {'action': 'oauth_link'},
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unlinkAccount() async {
    try {
      await _dataSource.unlinkAccount();
      _ref.invalidate(spotifyPlaylistsProvider);
      state = const AsyncValue.data(IntegrationStatus.notConnected);
    } catch (e, st) {
      await _errorLogger.logError(
        e,
        feature: _feature,
        tag: _tag,
        stackTrace: st,
        metadata: {'action': 'unlink'},
      );
      state = AsyncValue.error(e, st);
    }
  }
}
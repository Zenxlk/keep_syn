import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:keepsyn_app/src/core/constants/env_constants.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/core/logger/firebase_error_logger.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';
import 'package:keepsyn_app/src/features/integrations/data/datasources/youtube_remote_data_source.dart';
import 'package:keepsyn_app/src/features/integrations/data/enums/integration_status.dart';

const _youtubeScopes = <String>[
  'https://www.googleapis.com/auth/youtube',
  'https://www.googleapis.com/auth/youtube.readonly',
];

final youtubeDioProvider = Provider<Dio>((ref) {
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
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});

final youtubeDataSourceProvider = Provider<YouTubeRemoteDataSource>((ref) {
  return YouTubeRemoteDataSource(ref.watch(youtubeDioProvider));
});

final youtubeStatusProvider =
    StateNotifierProvider<YouTubeStatusNotifier, AsyncValue<IntegrationStatus>>(
      (ref) {
        return YouTubeStatusNotifier(
          ref.watch(youtubeDataSourceProvider),
          ref.watch(firebaseErrorLoggerProvider),
          ref.watch(googleSignInProvider),
        );
      },
    );

class YouTubeStatusNotifier
    extends StateNotifier<AsyncValue<IntegrationStatus>> {
  final YouTubeRemoteDataSource _dataSource;
  final IFirebaseErrorLogger _errorLogger;
  final GoogleSignIn _googleSignIn;

  static const _feature = 'youtube_integration';
  static const _tag = 'YouTubeIntegration';

  YouTubeStatusNotifier(this._dataSource, this._errorLogger, this._googleSignIn)
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

  Future<void> linkWithYouTube() async {
    state = const AsyncValue.data(IntegrationStatus.linking);

    try {
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: _youtubeScopes,
      );

      final serverAuthorization = await googleUser.authorizationClient
          .authorizeServer(_youtubeScopes);

      final serverAuthCode = serverAuthorization?.serverAuthCode;
      if (serverAuthCode == null || serverAuthCode.isEmpty) {
        throw const ServerException(
          'Google no devolvio serverAuthCode para YouTube. Intenta desvincular y volver a vincular.',
        );
      }

      await _dataSource.linkAccount(serverAuthCode: serverAuthCode);

      final status = await _dataSource.getStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      await _errorLogger.logError(
        e,
        feature: _feature,
        tag: _tag,
        stackTrace: st,
        metadata: {'action': 'link_google_sign_in'},
      );
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unlinkAccount() async {
    try {
      await _dataSource.unlinkAccount();
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

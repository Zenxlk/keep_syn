import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/review_item.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});

class HttpSyncService implements ISyncService {
  @override
  Future<SyncJobStatus?> getLastJobStatus() async => null;

  @override
  Future<SyncResult> reconnectToJob({
    required String jobId,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    throw const ServerException('reconnectToJob no soportado en HttpSyncService.');
  }

  @override
  Future<List<ReviewPendingItem>> getReviewItems({required String jobId}) async =>
      const [];

  @override
  Future<void> submitReview({
    required String jobId,
    required List<ReviewDecision> decisions,
  }) async {
    throw const ServerException('submitReview no soportado en HttpSyncService.');
  }

  final String baseUrl;
  final IdTokenProvider idTokenProvider;
  final http.Client _client;
  final Duration pollInterval;
  final int maxPollAttempts;

  HttpSyncService({
    required this.baseUrl,
    required this.idTokenProvider,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPollAttempts = 12,
  }) : _client = client ?? http.Client();

  @override
  Future<void> cancelSync({required String jobId}) async {
    final token = await _getValidToken();
    final uri = Uri.parse('$baseUrl/v1/sync/jobs/$jobId/cancel');

    final response = await _client.post(
      uri,
      headers: _headers(token),
    );

    final payload = _decodeResponse(response);
    _ensureSuccess(response.statusCode, payload);
  }

  @override
  Future<SyncResult> syncPlaylist({
    required SyncJob job,
    required Playlist sourcePlaylist,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    final token = await _getValidToken();

    final createUri = Uri.parse('$baseUrl/v1/sync/jobs');
    final createResponse = await _client.post(
      createUri,
      headers: _headers(token),
      body: jsonEncode(<String, dynamic>{
        'sourcePlatform': job.sourcePlatform,
        'targetPlatform': job.targetPlatform,
        'sourcePlaylistId': job.sourcePlaylistId,
      }),
    );

    final createPayload = _decodeResponse(createResponse);
    _ensureSuccess(createResponse.statusCode, createPayload);

    final data = createPayload['data'] as Map<String, dynamic>?;
    final createdJobId = data?['jobId']?.toString();
    if (createdJobId == null || createdJobId.isEmpty) {
      throw const ServerException('Respuesta invalida: jobId ausente.');
    }

    for (var attempt = 1; attempt <= maxPollAttempts; attempt++) {
      await Future<void>.delayed(pollInterval);

      final snapshot = await _fetchJobStatus(createdJobId);
      final state = snapshot['state']?.toString() ?? 'failed';
      final counters = _parseCounters(snapshot['counters']);

      onProgress(
        SyncProgress(
          jobId: createdJobId,
          processed: counters['processed'] ?? 0,
          total: sourcePlaylist.totalTracks,
          message: 'Estado remoto: $state',
        ),
      );

      if (_isTerminalState(state)) {
        return _mapToSyncResult(
          jobId: createdJobId,
          state: state,
          counters: counters,
          rawErrors: snapshot['errors'],
        );
      }
    }

    throw const ServerException(
      'El job sigue en progreso. Intenta consultar estado mas tarde.',
    );
  }

  Future<Map<String, dynamic>> _fetchJobStatus(String jobId) async {
    final token = await _getValidToken();
    final uri = Uri.parse('$baseUrl/v1/sync/jobs/$jobId');

    final response = await _client.get(
      uri,
      headers: _headers(token),
    );

    final payload = _decodeResponse(response);
    _ensureSuccess(response.statusCode, payload);

    return payload['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Map<String, String> _headers(String token) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<String> _getValidToken() async {
    var token = await idTokenProvider(forceRefresh: false);
    if (token != null && token.trim().isNotEmpty) {
      return token;
    }

    token = await idTokenProvider(forceRefresh: true);
    if (token == null || token.trim().isEmpty) {
      throw const UnauthorizedException('No hay sesion activa para Sync API.');
    }

    return token;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Se maneja abajo con excepcion estandar.
    }
    throw ServerException(
      'Respuesta invalida del servidor (${response.statusCode}).',
    );
  }

  void _ensureSuccess(int statusCode, Map<String, dynamic> payload) {
    final status = payload['status']?.toString() ?? 'ERROR';
    final message = payload['message']?.toString() ?? 'Error desconocido';

    if (statusCode == 401 || statusCode == 403) {
      throw UnauthorizedException(message);
    }

    if (status != 'OK') {
      throw ServerException(message);
    }
  }

  bool _isTerminalState(String state) {
    return state == 'success' ||
        state == 'partial_success' ||
        state == 'failed' ||
        state == 'cancelled';
  }

  Map<String, int> _parseCounters(Object? rawCounters) {
    if (rawCounters is! Map) {
      return <String, int>{
        'processed': 0,
        'created': 0,
        'updated': 0,
        'skipped': 0,
        'failed': 0,
      };
    }

    int parseInt(Object? value) => value is num ? value.toInt() : 0;

    return <String, int>{
      'processed': parseInt(rawCounters['processed']),
      'created': parseInt(rawCounters['created']),
      'updated': parseInt(rawCounters['updated']),
      'skipped': parseInt(rawCounters['skipped']),
      'failed': parseInt(rawCounters['failed']),
    };
  }

  List<SyncTrackError> _parseErrors(Object? rawErrors) {
    if (rawErrors is! List) {
      return const <SyncTrackError>[];
    }

    return rawErrors
        .whereType<Map>()
        .map(
          (error) => SyncTrackError(
            trackId: error['trackId']?.toString() ?? 'unknown',
            code: error['code']?.toString() ?? 'UNKNOWN',
            message: error['message']?.toString() ?? 'Sin detalle',
            retriable: error['retriable'] == true,
          ),
        )
        .toList(growable: false);
  }

  SyncResult _mapToSyncResult({
    required String jobId,
    required String state,
    required Map<String, int> counters,
    required Object? rawErrors,
  }) {
    final status = switch (state) {
      'success' => SyncResultStatus.success,
      'partial_success' => SyncResultStatus.partialSuccess,
      'cancelled' => SyncResultStatus.cancelled,
      _ => SyncResultStatus.failed,
    };

    return SyncResult(
      jobId: jobId,
      status: status,
      processed: counters['processed'] ?? 0,
      created: counters['created'] ?? 0,
      updated: counters['updated'] ?? 0,
      skipped: counters['skipped'] ?? 0,
      failed: counters['failed'] ?? 0,
      errors: _parseErrors(rawErrors),
      completedAt: DateTime.now(),
    );
  }
}


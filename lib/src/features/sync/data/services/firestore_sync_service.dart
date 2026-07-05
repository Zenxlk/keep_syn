import 'dart:async';

import 'package:dio/dio.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/review_item.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

class FirestoreSyncService implements ISyncService {
  final Dio _dio;
  final Duration _pollInterval;
  final Duration _maxPollDuration;

  FirestoreSyncService({
    required Dio dio,
    Duration pollInterval = const Duration(seconds: 3),
    Duration maxPollDuration = const Duration(minutes: 5),
  })  : _dio = dio,
        _pollInterval = pollInterval,
        _maxPollDuration = maxPollDuration;

  @override
  Future<SyncResult> syncPlaylist({
    required SyncJob job,
    required Playlist sourcePlaylist,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    final createResponse = await _dio.post<Map<String, dynamic>>(
      '/v1/sync/jobs',
      data: <String, dynamic>{
        'sourcePlatform': job.sourcePlatform,
        'targetPlatform': job.targetPlatform,
        'sourcePlaylistId': job.sourcePlaylistId,
      },
    );

    final createData = createResponse.data;
    if (createData == null || createData['status'] != 'OK') {
      throw ServerException(
        createData?['message']?.toString() ?? 'Error creando sync job.',
      );
    }

    final jobId =
        (createData['data'] as Map<String, dynamic>?)?['jobId']?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const ServerException('Respuesta invalida: jobId ausente.');
    }

    return _pollJob(
      backendJobId: jobId,
      localJobId: job.jobId,
      estimatedTotal: sourcePlaylist.totalTracks,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> cancelSync({required String jobId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sync/jobs/$jobId/cancel',
    );
    final data = response.data;
    if (data != null && data['status'] != 'OK') {
      throw ServerException(
          data['message']?.toString() ?? 'Error cancelando job.');
    }
  }

  @override
  Future<SyncJobStatus?> getLastJobStatus() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/v1/sync/jobs/last');
      final data = response.data;
      if (data == null || data['status'] != 'OK') return null;
      final jobData = data['data'] as Map<String, dynamic>?;
      if (jobData == null) return null;
      final jobId = jobData['jobId']?.toString();
      final state = jobData['state']?.toString();
      if (jobId == null || jobId.isEmpty || state == null) return null;
      return SyncJobStatus(jobId: jobId, state: state);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SyncResult> reconnectToJob({
    required String jobId,
    required void Function(SyncProgress progress) onProgress,
  }) {
    return _pollJob(
      backendJobId: jobId,
      localJobId: jobId,
      estimatedTotal: 0,
      onProgress: onProgress,
    );
  }

  @override
  Future<List<ReviewPendingItem>> getReviewItems({required String jobId}) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/sync/jobs/$jobId');
    final data = response.data;
    if (data == null || data['status'] != 'OK') {
      throw ServerException(
        data?['message']?.toString() ?? 'Error consultando job.',
      );
    }
    final jobData =
        (data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final raw = jobData['review_pending'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(_parseReviewItem).whereType<ReviewPendingItem>().toList();
  }

  @override
  Future<void> submitReview({
    required String jobId,
    required List<ReviewDecision> decisions,
  }) async {
    final body = <String, dynamic>{
      'decisions': decisions
          .map((d) => <String, dynamic>{
                'sourceTrackId': d.sourceTrackId,
                'action': d.approve ? 'approve' : 'skip',
                if (d.videoId != null) 'videoId': d.videoId,
              })
          .toList(growable: false),
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sync/jobs/$jobId/review',
      data: body,
    );
    final data = response.data;
    if (data != null && data['status'] != 'OK') {
      throw ServerException(
        data['message']?.toString() ?? 'Error enviando revisión.',
      );
    }
  }

  ReviewPendingItem? _parseReviewItem(Map raw) {
    try {
      final src = raw['sourceTrack'] as Map? ?? {};
      final sourceTrack = ReviewTrack(
        id: src['id']?.toString() ?? '',
        title: src['title']?.toString() ?? '',
        artists: _parseStringList(src['artists']),
        album: src['album']?.toString(),
      );

      final options = (raw['options'] is List ? raw['options'] as List : [])
          .whereType<Map>()
          .map((o) {
            final t = o['track'] as Map? ?? {};
            return ReviewOption(
              confidence: (o['confidence'] as num?)?.toDouble() ?? 0,
              strategy: o['strategy']?.toString() ?? '',
              track: ReviewTrack(
                id: t['id']?.toString() ?? '',
                title: t['title']?.toString() ?? '',
                artists: _parseStringList(t['artists']),
              ),
            );
          })
          .toList(growable: false);

      return ReviewPendingItem(
        sourceTrack: sourceTrack,
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0,
        strategy: raw['strategy']?.toString() ?? '',
        options: options,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _parseStringList(Object? raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) return [raw];
    return const [];
  }

  Future<SyncResult> _pollJob({
    required String backendJobId,
    required String localJobId,
    required int estimatedTotal,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    final deadline = DateTime.now().add(_maxPollDuration);

    while (true) {
      await Future<void>.delayed(_pollInterval);

      if (DateTime.now().isAfter(deadline)) {
        throw const ServerException(
          'Tiempo de espera agotado. El job no completó en el tiempo esperado.',
        );
      }

      final statusResponse = await _dio.get<Map<String, dynamic>>(
        '/v1/sync/jobs/$backendJobId',
      );

      final statusData = statusResponse.data;
      if (statusData == null || statusData['status'] != 'OK') {
        throw ServerException(
          statusData?['message']?.toString() ?? 'Error consultando sync job.',
        );
      }

      final jobData =
          (statusData['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final state = jobData['state']?.toString() ?? 'running';
      final counters = _parseCounters(jobData['counters']);
      final totalTracks = _parseTotalTracks(jobData, estimatedTotal);

      onProgress(
        SyncProgress(
          jobId: localJobId,
          processed: counters['processed'] ?? 0,
          total: totalTracks,
          message: _stateMessage(state),
        ),
      );

      if (_isTerminal(state)) {
        return _buildResult(
          jobId: backendJobId,
          state: state,
          counters: counters,
          rawErrors: jobData['errors'],
          rawReviewPending: jobData['review_pending'],
        );
      }
    }
  }

  bool _isTerminal(String state) {
    return state == 'success' ||
        state == 'partial_success' ||
        state == 'failed' ||
        state == 'cancelled';
  }

  String _stateMessage(String state) {
    switch (state) {
      case 'preparing':
        return 'Preparando sincronizacion...';
      case 'running':
        return 'Sincronizando tracks...';
      case 'success':
        return 'Sincronizacion completada.';
      case 'partial_success':
        return 'Sincronizacion completada con algunos errores.';
      case 'failed':
        return 'La sincronizacion ha fallado.';
      case 'cancelled':
        return 'Sincronizacion cancelada.';
      default:
        return 'Esperando actualizacion...';
    }
  }

  int _parseTotalTracks(Map<String, dynamic> data, int fallback) {
    final snapshot = data['sourceSnapshot'];
    if (snapshot is Map<String, dynamic>) {
      final total = snapshot['totalTracks'];
      if (total is num) return total.toInt();
    }
    return fallback;
  }

  Map<String, int> _parseCounters(Object? raw) {
    if (raw is! Map) {
      return {
        'processed': 0,
        'created': 0,
        'updated': 0,
        'skipped': 0,
        'failed': 0,
      };
    }
    int toInt(Object? v) => v is num ? v.toInt() : 0;
    return {
      'processed': toInt(raw['processed']),
      'created': toInt(raw['created']),
      'updated': toInt(raw['updated']),
      'skipped': toInt(raw['skipped']),
      'failed': toInt(raw['failed']),
    };
  }

  List<SyncTrackError> _parseErrors(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      return SyncTrackError(
        trackId: e['trackId']?.toString() ?? 'unknown',
        code: e['code']?.toString() ?? 'UNKNOWN',
        message: e['message']?.toString() ?? 'Sin detalle',
        retriable: e['retriable'] == true,
      );
    }).toList(growable: false);
  }

  SyncResult _buildResult({
    required String jobId,
    required String state,
    required Map<String, int> counters,
    required Object? rawErrors,
    Object? rawReviewPending,
  }) {
    final status = switch (state) {
      'success' => SyncResultStatus.success,
      'partial_success' => SyncResultStatus.partialSuccess,
      'cancelled' => SyncResultStatus.cancelled,
      _ => SyncResultStatus.failed,
    };

    final reviewPendingCount =
        rawReviewPending is List ? rawReviewPending.length : 0;

    return SyncResult(
      jobId: jobId,
      status: status,
      processed: counters['processed'] ?? 0,
      created: counters['created'] ?? 0,
      updated: counters['updated'] ?? 0,
      skipped: counters['skipped'] ?? 0,
      failed: counters['failed'] ?? 0,
      reviewPendingCount: reviewPendingCount,
      errors: _parseErrors(rawErrors),
      completedAt: DateTime.now(),
    );
  }
}

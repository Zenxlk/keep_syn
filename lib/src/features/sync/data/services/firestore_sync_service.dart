import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:keepsyn_app/src/core/error/exceptions.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

class FirestoreSyncService implements ISyncService {
  final Dio _dio;
  final FirebaseFirestore _firestore;

  FirestoreSyncService({required Dio dio, FirebaseFirestore? firestore})
      : _dio = dio,
        _firestore = firestore ?? FirebaseFirestore.instance;

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

    final jobId = (createData['data'] as Map<String, dynamic>?)?['jobId']?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw const ServerException('Respuesta invalida: jobId ausente.');
    }

    final completer = Completer<SyncResult>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;

    subscription = _firestore
        .collection('sync_jobs')
        .doc(jobId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        final state = data['state']?.toString() ?? 'running';
        final counters = _parseCounters(data['counters']);
        final totalTracks = _parseTotalTracks(data, sourcePlaylist.totalTracks);

        onProgress(
          SyncProgress(
            jobId: jobId,
            processed: counters['processed'] ?? 0,
            total: totalTracks,
            message: _stateMessage(state),
          ),
        );

        if (_isTerminal(state) && !completer.isCompleted) {
          completer.complete(
            _buildResult(
              jobId: jobId,
              state: state,
              counters: counters,
              rawErrors: data['errors'],
            ),
          );
          subscription?.cancel();
        }
      },
      onError: (Object err) {
        if (!completer.isCompleted) {
          completer.completeError(ServerException('Error escuchando sync job: $err'));
          subscription?.cancel();
        }
      },
    );

    return completer.future;
  }

  @override
  Future<void> cancelSync({required String jobId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sync/jobs/$jobId/cancel',
    );
    final data = response.data;
    if (data != null && data['status'] != 'OK') {
      throw ServerException(data['message']?.toString() ?? 'Error cancelando job.');
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
    final source = data['source'];
    if (source is Map<String, dynamic>) {
      final total = source['totalTracks'];
      if (total is num) return total.toInt();
    }
    return fallback;
  }

  Map<String, int> _parseCounters(Object? raw) {
    if (raw is! Map) {
      return {'processed': 0, 'created': 0, 'updated': 0, 'skipped': 0, 'failed': 0};
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

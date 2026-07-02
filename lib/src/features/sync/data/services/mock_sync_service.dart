import 'dart:async';

import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

class MockSyncService implements ISyncService {
  final Set<String> _cancelledJobIds = <String>{};

  @override
  Future<SyncJobStatus?> getLastJobStatus() async => null;

  @override
  Future<SyncResult> reconnectToJob({
    required String jobId,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    // Mock always returns a completed job for reconnect.
    return SyncResult(
      jobId: jobId,
      status: SyncResultStatus.failed,
      processed: 0,
      created: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: const <SyncTrackError>[],
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancelSync({required String jobId}) async {
    _cancelledJobIds.add(jobId);
  }

  @override
  Future<SyncResult> syncPlaylist({
    required SyncJob job,
    required Playlist sourcePlaylist,
    required void Function(SyncProgress progress) onProgress,
  }) async {
    final total = sourcePlaylist.totalTracks;

    if (total == 0) {
      return SyncResult(
        jobId: job.jobId,
        status: SyncResultStatus.failed,
        processed: 0,
        created: 0,
        updated: 0,
        skipped: 0,
        failed: 0,
        errors: const <SyncTrackError>[],
        completedAt: DateTime.now(),
      );
    }

    final errors = <SyncTrackError>[];
    var created = 0;
    var skipped = 0;

    for (var i = 0; i < total; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 220));

      if (_cancelledJobIds.contains(job.jobId)) {
        _cancelledJobIds.remove(job.jobId);
        return SyncResult(
          jobId: job.jobId,
          status: SyncResultStatus.cancelled,
          processed: i,
          created: created,
          updated: 0,
          skipped: skipped,
          failed: errors.length,
          errors: errors,
          completedAt: DateTime.now(),
        );
      }

      final track = sourcePlaylist.tracks[i];
      final isMappingIssue = (i + 1) % 7 == 0;

      if (isMappingIssue) {
        skipped += 1;
        errors.add(
          SyncTrackError(
            trackId: track.id,
            code: 'TRACK_MAPPING_NOT_FOUND',
            message: 'No se encontró coincidencia para ${track.title}.',
            retriable: false,
          ),
        );
      } else {
        created += 1;
      }

      onProgress(
        SyncProgress(
          jobId: job.jobId,
          processed: i + 1,
          total: total,
          message: 'Sincronizando track ${i + 1}/$total',
        ),
      );
    }

    return SyncResult(
      jobId: job.jobId,
      status: errors.isEmpty
          ? SyncResultStatus.success
          : SyncResultStatus.partialSuccess,
      processed: total,
      created: created,
      updated: 0,
      skipped: skipped,
      failed: errors.length,
      errors: errors,
      completedAt: DateTime.now(),
    );
  }
}


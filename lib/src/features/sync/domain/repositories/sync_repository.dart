import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

abstract class ISyncRepository {
  Future<Either<Failure, SyncResult>> startSync({
    required SyncJob job,
    required Playlist sourcePlaylist,
  });

  Future<Either<Failure, void>> cancelSync({required String jobId});

  Stream<SyncProgress> watchSyncProgress({required String jobId});

  Stream<SyncResult> watchSyncResults({required String jobId});

  Future<SyncJobStatus?> getLastJobStatus();

  Future<Either<Failure, SyncResult>> reconnectToJob({
    required String jobId,
    required void Function(SyncProgress progress) onProgress,
  });
}

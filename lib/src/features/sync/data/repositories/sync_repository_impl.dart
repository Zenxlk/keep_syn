import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';
import 'package:keepsyn_app/src/features/sync/domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final ISyncService _syncService;

  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();
  final StreamController<SyncResult> _resultController =
      StreamController<SyncResult>.broadcast();

  SyncRepositoryImpl({required ISyncService syncService})
      : _syncService = syncService;

  @override
  Future<Either<Failure, void>> cancelSync({required String jobId}) async {
    try {
      await _syncService.cancelSync(jobId: jobId);
      return const Right(null);
    } catch (e) {
      return Left(SyncFailure(message: 'No se pudo cancelar el job: $e'));
    }
  }

  @override
  Future<Either<Failure, SyncResult>> startSync({
    required SyncJob job,
    required Playlist sourcePlaylist,
  }) async {
    try {
      final result = await _syncService.syncPlaylist(
        job: job,
        sourcePlaylist: sourcePlaylist,
        onProgress: (progress) => _progressController.add(progress),
      );

      _resultController.add(result);
      return Right(result);
    } catch (e) {
      return Left(
        SyncFailure(message: 'Error inesperado durante la sincronización: $e'),
      );
    }
  }

  @override
  Stream<SyncProgress> watchSyncProgress({required String jobId}) {
    return _progressController.stream.where((progress) => progress.jobId == jobId);
  }

  @override
  Stream<SyncResult> watchSyncResults({required String jobId}) {
    return _resultController.stream.where((result) => result.jobId == jobId);
  }
}


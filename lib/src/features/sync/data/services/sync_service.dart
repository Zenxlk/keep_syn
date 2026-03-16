import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

abstract class ISyncService {
  Future<SyncResult> syncPlaylist({
    required SyncJob job,
    required Playlist sourcePlaylist,
    required void Function(SyncProgress progress) onProgress,
  });

  Future<void> cancelSync({required String jobId});
}


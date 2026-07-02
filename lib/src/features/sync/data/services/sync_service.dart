import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/review_item.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

class SyncJobStatus {
  final String jobId;
  final String state;
  const SyncJobStatus({required this.jobId, required this.state});
  bool get isActive =>
      state == 'idle' || state == 'preparing' || state == 'running';
}

abstract class ISyncService {
  Future<SyncResult> syncPlaylist({
    required SyncJob job,
    required Playlist sourcePlaylist,
    required void Function(SyncProgress progress) onProgress,
  });

  Future<void> cancelSync({required String jobId});

  Future<SyncJobStatus?> getLastJobStatus();

  Future<SyncResult> reconnectToJob({
    required String jobId,
    required void Function(SyncProgress progress) onProgress,
  });

  Future<List<ReviewPendingItem>> getReviewItems({required String jobId});

  Future<void> submitReview({
    required String jobId,
    required List<ReviewDecision> decisions,
  });
}

class ReviewDecision {
  final String sourceTrackId;
  final bool approve;
  final String? videoId;

  const ReviewDecision.approve({
    required this.sourceTrackId,
    required String this.videoId,
  }) : approve = true;

  const ReviewDecision.skip({required this.sourceTrackId})
      : approve = false,
        videoId = null;
}


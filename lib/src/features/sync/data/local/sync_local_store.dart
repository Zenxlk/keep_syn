import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';

class SyncLocalSnapshot {
  final SyncStatus? lastStatus;
  final DateTime? lastSyncAt;
  final List<SyncTrackError> recentErrors;

  const SyncLocalSnapshot({
    this.lastStatus,
    this.lastSyncAt,
    this.recentErrors = const <SyncTrackError>[],
  });
}

class SyncHistoryEntry {
  final String jobId;
  final SyncStatus status;
  final DateTime completedAt;
  final String? playlistName;
  final int created;
  final int skipped;
  final int failed;
  final int processed;

  const SyncHistoryEntry({
    required this.jobId,
    required this.status,
    required this.completedAt,
    this.playlistName,
    required this.created,
    required this.skipped,
    required this.failed,
    required this.processed,
  });
}

abstract class ISyncLocalStore {
  Future<void> saveSnapshot(SyncLocalSnapshot snapshot);
  Future<SyncLocalSnapshot> loadSnapshot();
  Future<void> saveHistoryEntry(SyncHistoryEntry entry);
  Future<List<SyncHistoryEntry>> loadHistory();
  Future<void> clear();
}


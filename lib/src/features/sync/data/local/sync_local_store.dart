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

abstract class ISyncLocalStore {
  Future<void> saveSnapshot(SyncLocalSnapshot snapshot);
  Future<SyncLocalSnapshot> loadSnapshot();
  Future<void> clear();
}


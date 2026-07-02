import 'dart:convert';

import 'package:keepsyn_app/src/core/constants/app_constants.dart';
import 'package:keepsyn_app/src/features/sync/data/local/sync_local_store.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesSyncLocalStore implements ISyncLocalStore {
  final SharedPreferences _prefs;

  SharedPreferencesSyncLocalStore({required SharedPreferences prefs})
      : _prefs = prefs;

  @override
  Future<void> saveHistoryEntry(SyncHistoryEntry entry) async {
    final existing = await loadHistory();
    final updated = [entry, ...existing]
        .take(AppConstants.syncHistoryMaxEntries)
        .toList(growable: false);

    final encoded = updated
        .map((e) => <String, dynamic>{
              'jobId': e.jobId,
              'status': e.status.name,
              'completedAt': e.completedAt.toIso8601String(),
              'playlistName': e.playlistName,
              'created': e.created,
              'skipped': e.skipped,
              'failed': e.failed,
              'processed': e.processed,
            })
        .toList(growable: false);

    await _prefs.setString(AppConstants.keySyncHistory, jsonEncode(encoded));
  }

  @override
  Future<List<SyncHistoryEntry>> loadHistory() async {
    final raw = _prefs.getString(AppConstants.keySyncHistory);
    if (raw == null) return const <SyncHistoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SyncHistoryEntry>[];
      return decoded.whereType<Map>().map((item) {
        final status = _parseStatus(item['status']?.toString());
        final at = DateTime.tryParse(item['completedAt']?.toString() ?? '');
        if (status == null || at == null) return null;
        return SyncHistoryEntry(
          jobId: item['jobId']?.toString() ?? '',
          status: status,
          completedAt: at,
          playlistName: item['playlistName']?.toString(),
          created: (item['created'] as num?)?.toInt() ?? 0,
          skipped: (item['skipped'] as num?)?.toInt() ?? 0,
          failed: (item['failed'] as num?)?.toInt() ?? 0,
          processed: (item['processed'] as num?)?.toInt() ?? 0,
        );
      }).whereType<SyncHistoryEntry>().toList(growable: false);
    } catch (_) {
      return const <SyncHistoryEntry>[];
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(AppConstants.keyLastSyncStatus);
    await _prefs.remove(AppConstants.keyLastSyncDate);
    await _prefs.remove(AppConstants.keySyncRecentErrors);
    await _prefs.remove(AppConstants.keySyncHistory);
  }

  @override
  Future<SyncLocalSnapshot> loadSnapshot() async {
    final rawStatus = _prefs.getString(AppConstants.keyLastSyncStatus);
    final rawDate = _prefs.getString(AppConstants.keyLastSyncDate);
    final rawErrors =
        _prefs.getString(AppConstants.keySyncRecentErrors) ?? '[]';

    final status = _parseStatus(rawStatus);
    final lastSyncAt =
        rawDate != null ? DateTime.tryParse(rawDate) : null;
    final recentErrors = _parseErrors(rawErrors);

    return SyncLocalSnapshot(
      lastStatus: status,
      lastSyncAt: lastSyncAt,
      recentErrors: recentErrors,
    );
  }

  @override
  Future<void> saveSnapshot(SyncLocalSnapshot snapshot) async {
    if (snapshot.lastStatus != null) {
      await _prefs.setString(
        AppConstants.keyLastSyncStatus,
        snapshot.lastStatus!.name,
      );
    }

    if (snapshot.lastSyncAt != null) {
      await _prefs.setString(
        AppConstants.keyLastSyncDate,
        snapshot.lastSyncAt!.toIso8601String(),
      );
    }

    final errorJson = snapshot.recentErrors
        .take(5)
        .map((e) => <String, dynamic>{
              'trackId': e.trackId,
              'code': e.code,
              'message': e.message,
              'retriable': e.retriable,
            })
        .toList(growable: false);

    await _prefs.setString(
      AppConstants.keySyncRecentErrors,
      jsonEncode(errorJson),
    );
  }

  SyncStatus? _parseStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) {
      return null;
    }

    for (final status in SyncStatus.values) {
      if (status.name == rawStatus) {
        return status;
      }
    }
    return null;
  }

  List<SyncTrackError> _parseErrors(String rawErrors) {
    try {
      final decoded = jsonDecode(rawErrors);
      if (decoded is! List) {
        return const <SyncTrackError>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => SyncTrackError(
                trackId: item['trackId']?.toString() ?? 'unknown',
                code: item['code']?.toString() ?? 'UNKNOWN',
                message: item['message']?.toString() ?? 'Sin detalle',
                retriable: item['retriable'] == true,
              ))
          .toList(growable: false);
    } catch (_) {
      return const <SyncTrackError>[];
    }
  }
}


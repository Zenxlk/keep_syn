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
  Future<void> clear() async {
    await _prefs.remove(AppConstants.keyLastSyncStatus);
    await _prefs.remove(AppConstants.keyLastSyncDate);
    await _prefs.remove(AppConstants.keySyncRecentErrors);
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


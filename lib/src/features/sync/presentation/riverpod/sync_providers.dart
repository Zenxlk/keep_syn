import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keepsyn_app/src/core/constants/env_constants.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/data/local/shared_preferences_sync_local_store.dart';
import 'package:keepsyn_app/src/features/sync/data/local/sync_local_store.dart';
import 'package:keepsyn_app/src/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:keepsyn_app/src/features/sync/data/services/http_sync_service.dart';
import 'package:keepsyn_app/src/features/sync/data/services/mock_sync_service.dart';
import 'package:keepsyn_app/src/features/sync/data/services/sync_service.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_progress.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';
import 'package:keepsyn_app/src/features/sync/domain/repositories/sync_repository.dart';
import 'package:keepsyn_app/src/features/sync/presentation/riverpod/sync_controller_state.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) {
  return SharedPreferences.getInstance();
}

@Riverpod(keepAlive: true)
Future<ISyncLocalStore> syncLocalStore(Ref ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPreferencesSyncLocalStore(prefs: prefs);
}

@Riverpod(keepAlive: true)
ISyncService syncService(Ref ref) {
  if (EnvConstants.useRealSyncApi) {
    return HttpSyncService(
      baseUrl: EnvConstants.syncApiBaseUrl,
      idTokenProvider: ({bool forceRefresh = false}) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        return currentUser?.getIdToken(forceRefresh);
      },
    );
  }

  return MockSyncService();
}

@Riverpod(keepAlive: true)
ISyncRepository syncRepository(Ref ref) {
  return SyncRepositoryImpl(syncService: ref.watch(syncServiceProvider));
}

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  StreamSubscription<SyncProgress>? _progressSubscription;

  @override
  SyncControllerState build() {
    ref.onDispose(() async {
      await _progressSubscription?.cancel();
    });

    _hydrateSnapshot();
    return const SyncControllerState.idle();
  }

  Future<void> startSync({
    required SyncJob job,
    required Playlist sourcePlaylist,
  }) async {
    if (!state.canStartNewSync) {
      state = state.copyWith(
        failure: const SyncFailure(
          message: 'Ya hay una sincronizacion en curso para esta sesion.',
        ),
      );
      return;
    }

    state = state.copyWith(
      status: SyncStatus.preparing,
      activeJob: job,
      sessionActiveJobId: job.jobId,
      sessionSyncInProgress: true,
      progress: 0,
      clearProgressMessage: true,
      clearResult: true,
      clearFailure: true,
    );

    await _progressSubscription?.cancel();
    _progressSubscription = ref
        .read(syncRepositoryProvider)
        .watchSyncProgress(jobId: job.jobId)
        .listen(_handleProgressEvent);

    state = state.copyWith(status: SyncStatus.running);

    final result = await ref
        .read(syncRepositoryProvider)
        .startSync(job: job, sourcePlaylist: sourcePlaylist);

    await result.fold(
      (failure) async {
        final now = DateTime.now();
        final failureErrors = _buildFailureErrors(failure);

        state = state.copyWith(
          status: SyncStatus.failed,
          failure: failure,
          progress: 0,
          sessionSyncInProgress: false,
          sessionActiveJobId: null,
          lastSyncStatus: SyncStatus.failed,
          lastSyncAt: now,
          recentErrors: failureErrors,
          progressMessage:
              failure.message ?? 'Fallo durante la sincronizacion.',
        );

        await _persistSnapshot(
          status: SyncStatus.failed,
          completedAt: now,
          errors: failureErrors,
        );
      },
      (syncResult) async {
        final mappedStatus = _mapResultStatus(syncResult.status);
        final now = syncResult.completedAt;
        final quotaExceeded = syncResult.errors.any(
          (error) => error.code == 'TARGET_QUOTA_EXCEEDED',
        );

        state = state.copyWith(
          status: mappedStatus,
          result: syncResult,
          progress: 1,
          sessionSyncInProgress: false,
          sessionActiveJobId: null,
          clearFailure: true,
          lastSyncStatus: mappedStatus,
          lastSyncAt: now,
          recentErrors: syncResult.errors,
          progressMessage:
              quotaExceeded
                  ? 'Cuota de YouTube alcanzada. Se detuvo el job para evitar mas consumo.'
                  : syncResult.hasFailures
                  ? 'Sincronizacion finalizada con algunos errores.'
                  : 'Sincronizacion completada correctamente.',
        );

        await _persistSnapshot(
          status: mappedStatus,
          completedAt: now,
          errors: syncResult.errors,
        );
      },
    );
  }

  Future<void> cancelActiveSync() async {
    final activeJob = state.activeJob;
    if (activeJob == null || !state.isRunning) {
      return;
    }

    final result = await ref
        .read(syncRepositoryProvider)
        .cancelSync(jobId: activeJob.jobId);

    await result.fold(
      (failure) async {
        final now = DateTime.now();
        final failureErrors = _buildFailureErrors(failure);

        state = state.copyWith(
          status: SyncStatus.failed,
          failure: failure,
          sessionSyncInProgress: false,
          sessionActiveJobId: null,
          lastSyncStatus: SyncStatus.failed,
          lastSyncAt: now,
          recentErrors: failureErrors,
          progressMessage:
              failure.message ?? 'No se pudo cancelar la sincronizacion.',
        );

        await _persistSnapshot(
          status: SyncStatus.failed,
          completedAt: now,
          errors: failureErrors,
        );
      },
      (_) async {
        final now = DateTime.now();

        state = state.copyWith(
          status: SyncStatus.cancelled,
          sessionSyncInProgress: false,
          sessionActiveJobId: null,
          clearFailure: true,
          lastSyncStatus: SyncStatus.cancelled,
          lastSyncAt: now,
          progressMessage: 'Sincronizacion cancelada por el usuario.',
        );

        await _persistSnapshot(
          status: SyncStatus.cancelled,
          completedAt: now,
          errors: state.recentErrors,
        );
      },
    );
  }

  void reset() {
    state = state.copyWith(
      status: SyncStatus.idle,
      activeJob: null,
      sessionActiveJobId: null,
      sessionSyncInProgress: false,
      progress: 0,
      clearProgressMessage: true,
      clearFailure: true,
      clearResult: true,
    );
  }

  void _handleProgressEvent(SyncProgress progress) {
    state = state.copyWith(
      status: SyncStatus.running,
      progress: progress.value,
      progressMessage: progress.message,
      clearFailure: true,
    );
  }

  SyncStatus _mapResultStatus(SyncResultStatus status) {
    switch (status) {
      case SyncResultStatus.success:
        return SyncStatus.idle;
      case SyncResultStatus.partialSuccess:
        return SyncStatus.partialSuccess;
      case SyncResultStatus.failed:
        return SyncStatus.failed;
      case SyncResultStatus.cancelled:
        return SyncStatus.cancelled;
    }
  }

  List<SyncTrackError> _buildFailureErrors(Failure failure) {
    return <SyncTrackError>[
      SyncTrackError(
        trackId: 'job',
        code: failure.runtimeType.toString(),
        message: failure.message ?? 'Error de sincronizacion.',
      ),
    ];
  }

  Future<void> _hydrateSnapshot() async {
    try {
      final localStore = await ref.read(syncLocalStoreProvider.future);
      final snapshot = await localStore.loadSnapshot();

      state = state.copyWith(
        lastSyncStatus: snapshot.lastStatus,
        lastSyncAt: snapshot.lastSyncAt,
        recentErrors: snapshot.recentErrors,
      );
    } catch (_) {
      // La hidratacion local no debe romper el flujo.
    }
  }

  Future<void> _persistSnapshot({
    required SyncStatus status,
    required DateTime completedAt,
    required List<SyncTrackError> errors,
  }) async {
    try {
      final localStore = await ref.read(syncLocalStoreProvider.future);
      await localStore.saveSnapshot(
        SyncLocalSnapshot(
          lastStatus: status,
          lastSyncAt: completedAt,
          recentErrors: errors,
        ),
      );
    } catch (_) {
      // La persistencia local no bloquea el resultado de negocio.
    }
  }

  Failure classifyFailure(Object error) {
    if (error is Failure) {
      return error;
    }

    return SyncFailure(message: 'Error no clasificado: $error');
  }
}

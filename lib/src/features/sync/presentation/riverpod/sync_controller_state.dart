import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_job.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/sync_result.dart';

enum SyncStatus {
  idle,
  preparing,
  running,
  partialSuccess,
  failed,
  cancelled,
}

class SyncControllerState extends Equatable {
  final SyncStatus status;
  final SyncJob? activeJob;
  final String? sessionActiveJobId;
  final bool sessionSyncInProgress;
  final SyncResult? result;
  final Failure? failure;
  final double progress;
  final String? progressMessage;
  final SyncStatus? lastSyncStatus;
  final DateTime? lastSyncAt;
  final List<SyncTrackError> recentErrors;

  const SyncControllerState({
    required this.status,
    this.activeJob,
    this.sessionActiveJobId,
    this.sessionSyncInProgress = false,
    this.result,
    this.failure,
    this.progress = 0,
    this.progressMessage,
    this.lastSyncStatus,
    this.lastSyncAt,
    this.recentErrors = const <SyncTrackError>[],
  });

  const SyncControllerState.idle() : this(status: SyncStatus.idle);

  bool get isIdle => status == SyncStatus.idle;
  bool get isPreparing => status == SyncStatus.preparing;
  bool get isRunning => status == SyncStatus.running;
  bool get isFinished =>
      status == SyncStatus.partialSuccess ||
      status == SyncStatus.failed ||
      status == SyncStatus.cancelled;
  bool get canStartNewSync => !sessionSyncInProgress && !isPreparing && !isRunning;
  bool get hasError => failure != null;

  SyncControllerState copyWith({
    SyncStatus? status,
    SyncJob? activeJob,
    String? sessionActiveJobId,
    bool? sessionSyncInProgress,
    SyncResult? result,
    Failure? failure,
    bool clearFailure = false,
    bool clearResult = false,
    double? progress,
    String? progressMessage,
    bool clearProgressMessage = false,
    SyncStatus? lastSyncStatus,
    DateTime? lastSyncAt,
    List<SyncTrackError>? recentErrors,
  }) {
    return SyncControllerState(
      status: status ?? this.status,
      activeJob: activeJob ?? this.activeJob,
      sessionActiveJobId: sessionActiveJobId ?? this.sessionActiveJobId,
      sessionSyncInProgress:
          sessionSyncInProgress ?? this.sessionSyncInProgress,
      result: clearResult ? null : (result ?? this.result),
      failure: clearFailure ? null : (failure ?? this.failure),
      progress: progress ?? this.progress,
      progressMessage:
          clearProgressMessage ? null : (progressMessage ?? this.progressMessage),
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      recentErrors: recentErrors ?? this.recentErrors,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeJob,
        sessionActiveJobId,
        sessionSyncInProgress,
        result,
        failure,
        progress,
        progressMessage,
        lastSyncStatus,
        lastSyncAt,
        recentErrors,
      ];
}


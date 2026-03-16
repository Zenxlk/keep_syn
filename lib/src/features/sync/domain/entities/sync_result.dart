import 'package:equatable/equatable.dart';

enum SyncResultStatus {
  success,
  partialSuccess,
  failed,
  cancelled,
}

class SyncTrackError extends Equatable {
  final String trackId;
  final String code;
  final String message;
  final bool retriable;

  const SyncTrackError({
    required this.trackId,
    required this.code,
    required this.message,
    this.retriable = false,
  });

  @override
  List<Object?> get props => [trackId, code, message, retriable];
}

class SyncResult extends Equatable {
  final String jobId;
  final SyncResultStatus status;
  final int processed;
  final int created;
  final int updated;
  final int skipped;
  final int failed;
  final List<SyncTrackError> errors;
  final DateTime completedAt;

  const SyncResult({
    required this.jobId,
    required this.status,
    required this.processed,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.errors,
    required this.completedAt,
  });

  bool get hasFailures => failed > 0 || errors.isNotEmpty;

  @override
  List<Object?> get props => [
        jobId,
        status,
        processed,
        created,
        updated,
        skipped,
        failed,
        errors,
        completedAt,
      ];
}


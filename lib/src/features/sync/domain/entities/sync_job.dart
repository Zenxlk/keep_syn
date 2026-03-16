import 'package:equatable/equatable.dart';

class SyncJob extends Equatable {
  final String jobId;
  final String sourcePlatform;
  final String targetPlatform;
  final String sourcePlaylistId;
  final DateTime requestedAt;
  final int attempt;

  const SyncJob({
    required this.jobId,
    required this.sourcePlatform,
    required this.targetPlatform,
    required this.sourcePlaylistId,
    required this.requestedAt,
    this.attempt = 0,
  });

  SyncJob nextAttempt() {
    return copyWith(
      attempt: attempt + 1,
      requestedAt: DateTime.now(),
    );
  }

  SyncJob copyWith({
    String? jobId,
    String? sourcePlatform,
    String? targetPlatform,
    String? sourcePlaylistId,
    DateTime? requestedAt,
    int? attempt,
  }) {
    return SyncJob(
      jobId: jobId ?? this.jobId,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      targetPlatform: targetPlatform ?? this.targetPlatform,
      sourcePlaylistId: sourcePlaylistId ?? this.sourcePlaylistId,
      requestedAt: requestedAt ?? this.requestedAt,
      attempt: attempt ?? this.attempt,
    );
  }

  @override
  List<Object?> get props => [
        jobId,
        sourcePlatform,
        targetPlatform,
        sourcePlaylistId,
        requestedAt,
        attempt,
      ];
}


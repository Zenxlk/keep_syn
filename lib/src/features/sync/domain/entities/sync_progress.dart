import 'package:equatable/equatable.dart';

class SyncProgress extends Equatable {
  final String jobId;
  final int processed;
  final int total;
  final String message;

  const SyncProgress({
    required this.jobId,
    required this.processed,
    required this.total,
    required this.message,
  });

  double get value {
    if (total <= 0) return 0;
    final raw = processed / total;
    if (raw < 0) return 0;
    if (raw > 1) return 1;
    return raw;
  }

  @override
  List<Object?> get props => [jobId, processed, total, message];
}


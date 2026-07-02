import 'package:equatable/equatable.dart';

class ReviewTrack extends Equatable {
  final String id;
  final String title;
  final List<String> artists;
  final String? album;

  const ReviewTrack({
    required this.id,
    required this.title,
    required this.artists,
    this.album,
  });

  String get displayArtists => artists.join(', ');

  @override
  List<Object?> get props => [id, title, artists, album];
}

class ReviewOption extends Equatable {
  final double confidence;
  final String strategy;
  final ReviewTrack track;

  const ReviewOption({
    required this.confidence,
    required this.strategy,
    required this.track,
  });

  @override
  List<Object?> get props => [confidence, strategy, track];
}

class ReviewPendingItem extends Equatable {
  final ReviewTrack sourceTrack;
  final double confidence;
  final String strategy;
  final List<ReviewOption> options;

  const ReviewPendingItem({
    required this.sourceTrack,
    required this.confidence,
    required this.strategy,
    required this.options,
  });

  ReviewOption? get bestOption => options.isEmpty ? null : options.first;

  @override
  List<Object?> get props => [sourceTrack, confidence, strategy, options];
}

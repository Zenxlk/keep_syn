import 'package:equatable/equatable.dart';

class TargetTrackMatch extends Equatable {
  final String trackId;
  final String title;
  final List<String> artists;
  final String? externalId;

  const TargetTrackMatch({
    required this.trackId,
    required this.title,
    required this.artists,
    this.externalId,
  });

  @override
  List<Object?> get props => [trackId, title, artists, externalId];
}


import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/track.dart';

class SpotifyTrackModel extends Equatable {
  final String id;
  final String title;
  final List<String> artists;
  final int? durationMs;
  final String? isrc;

  const SpotifyTrackModel({
    required this.id,
    required this.title,
    required this.artists,
    this.durationMs,
    this.isrc,
  });

  factory SpotifyTrackModel.fromPlaylistTrackJson(Map<String, dynamic> json) {
    final track = Map<String, dynamic>.from(
      (json['track'] as Map?) ?? <String, dynamic>{},
    );
    final artists = (track['artists'] as List?)
            ?.whereType<Map>()
            .map((artist) => artist['name']?.toString() ?? 'Unknown Artist')
            .toList(growable: false) ??
        const <String>[];
    final externalIds = Map<String, dynamic>.from(
      (track['external_ids'] as Map?) ?? <String, dynamic>{},
    );

    return SpotifyTrackModel(
      id: track['id']?.toString() ?? 'unknown-track',
      title: track['name']?.toString() ?? 'Unknown Track',
      artists: artists,
      durationMs: track['duration_ms'] is num
          ? (track['duration_ms'] as num).toInt()
          : null,
      isrc: externalIds['isrc']?.toString(),
    );
  }

  Track toDomain() {
    return Track(
      id: id,
      title: title,
      artists: artists,
      durationMs: durationMs,
      isrc: isrc,
    );
  }

  @override
  List<Object?> get props => [id, title, artists, durationMs, isrc];
}


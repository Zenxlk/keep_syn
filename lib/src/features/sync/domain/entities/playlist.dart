import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/track.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String platform;
  final List<Track> tracks;
  final DateTime? snapshotAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.platform,
    required this.tracks,
    this.snapshotAt,
  });

  int get totalTracks => tracks.length;

  Playlist copyWith({
    String? id,
    String? name,
    String? platform,
    List<Track>? tracks,
    DateTime? snapshotAt,
    bool clearSnapshotAt = false,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      tracks: tracks ?? this.tracks,
      snapshotAt: clearSnapshotAt ? null : (snapshotAt ?? this.snapshotAt),
    );
  }

  @override
  List<Object?> get props => [id, name, platform, tracks, snapshotAt];
}


import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_track_model.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';

class SpotifyPlaylistModel extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? ownerName;
  final int tracksTotal;

  const SpotifyPlaylistModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.ownerName,
    required this.tracksTotal,
  });

  factory SpotifyPlaylistModel.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final owner = Map<String, dynamic>.from(
      (json['owner'] as Map?) ?? <String, dynamic>{},
    );
    final tracks = Map<String, dynamic>.from(
      (json['tracks'] as Map?) ?? <String, dynamic>{},
    );

    return SpotifyPlaylistModel(
      id: json['id']?.toString() ?? 'unknown-playlist',
      name: json['name']?.toString() ?? 'Playlist sin nombre',
      imageUrl: images.isNotEmpty ? images.first['url']?.toString() : null,
      ownerName: owner['display_name']?.toString(),
      tracksTotal:
          tracks['total'] is num ? (tracks['total'] as num).toInt() : 0,
    );
  }

  Playlist toDomain(List<SpotifyTrackModel> tracks) {
    return Playlist(
      id: id,
      name: name,
      platform: 'spotify',
      tracks: tracks.map((track) => track.toDomain()).toList(growable: false),
      snapshotAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, imageUrl, ownerName, tracksTotal];
}


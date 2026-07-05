import 'package:equatable/equatable.dart';
import 'package:keepsyn_app/src/features/integrations/data/models/spotify_track_model.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/playlist.dart';

class SpotifyPlaylistModel extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? ownerName;
  final String? ownerId;
  final int tracksTotal;

  const SpotifyPlaylistModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.ownerName,
    this.ownerId,
    required this.tracksTotal,
  });

  /// Playlists curadas por Spotify (Daily Mix, Discover Weekly, etc.)
  /// devuelven 403 al acceder a sus tracks vía API.
  bool get isSpotifyGenerated => ownerId == 'spotify';

  factory SpotifyPlaylistModel.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    final owner = Map<String, dynamic>.from(
      (json['owner'] as Map?) ?? <String, dynamic>{},
    );

    // Backend sends tracksTotal as a top-level field; fall back to nested
    // tracks.total for raw Spotify API responses (e.g. tests / stubs).
    final int tracksTotal;
    if (json['tracksTotal'] is num) {
      tracksTotal = (json['tracksTotal'] as num).toInt();
    } else {
      final tracks = Map<String, dynamic>.from(
        (json['tracks'] as Map?) ?? <String, dynamic>{},
      );
      tracksTotal = tracks['total'] is num ? (tracks['total'] as num).toInt() : 0;
    }

    return SpotifyPlaylistModel(
      id: json['id']?.toString() ?? 'unknown-playlist',
      name: json['name']?.toString() ?? 'Playlist sin nombre',
      imageUrl: images.isNotEmpty
          ? images.first['url']?.toString()
          : json['imageUrl']?.toString(),
      ownerName: owner['display_name']?.toString(),
      ownerId: json['ownerId']?.toString() ?? owner['id']?.toString(),
      tracksTotal: tracksTotal,
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
  List<Object?> get props => [id, name, imageUrl, ownerName, ownerId, tracksTotal];
}


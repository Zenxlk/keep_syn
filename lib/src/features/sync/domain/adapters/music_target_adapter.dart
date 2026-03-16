import 'package:dartz/dartz.dart';
import 'package:keepsyn_app/src/core/error/failures.dart';
import 'package:keepsyn_app/src/features/sync/domain/adapters/models/target_playlist.dart';
import 'package:keepsyn_app/src/features/sync/domain/adapters/models/target_track_match.dart';
import 'package:keepsyn_app/src/features/sync/domain/entities/track.dart';

/// Contrato del destino de sincronizacion (YouTube Music, Tidal, etc).
///
/// No depende de SDKs concretos para mantener desacoplado el dominio.
abstract class IMusicTargetAdapter {
  /// Crea una playlist en la plataforma destino.
  Future<Either<Failure, TargetPlaylist>> createPlaylist({
    required String name,
    String? description,
    bool isPublic = false,
  });

  /// Busca una posible coincidencia en el destino para un track origen.
  ///
  /// Retorna `null` cuando no existe match aceptable.
  Future<Either<Failure, TargetTrackMatch?>> searchTrack({
    required Track sourceTrack,
  });

  /// Agrega un track (ya identificado en el destino) a una playlist destino.
  Future<Either<Failure, void>> addTrackToPlaylist({
    required String playlistId,
    required String targetTrackId,
  });
}


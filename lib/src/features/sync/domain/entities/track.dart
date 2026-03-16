import 'package:equatable/equatable.dart';

class Track extends Equatable {
  final String id;
  final String title;
  final List<String> artists;
  final int? durationMs;
  final String? isrc;

  const Track({
    required this.id,
    required this.title,
    required this.artists,
    this.durationMs,
    this.isrc,
  });

  Track copyWith({
    String? id,
    String? title,
    List<String>? artists,
    int? durationMs,
    String? isrc,
    bool clearIsrc = false,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      durationMs: durationMs ?? this.durationMs,
      isrc: clearIsrc ? null : (isrc ?? this.isrc),
    );
  }

  @override
  List<Object?> get props => [id, title, artists, durationMs, isrc];
}


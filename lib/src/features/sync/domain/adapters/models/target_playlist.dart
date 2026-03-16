import 'package:equatable/equatable.dart';

class TargetPlaylist extends Equatable {
  final String id;
  final String name;
  final String platform;

  const TargetPlaylist({
    required this.id,
    required this.name,
    required this.platform,
  });

  @override
  List<Object?> get props => [id, name, platform];
}


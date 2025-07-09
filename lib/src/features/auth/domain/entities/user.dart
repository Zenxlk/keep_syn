import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String uid;
  final String? email;
  final String? name;
  final String? photoUrl;

  const User({
    required this.uid,
    this.email,
    this.name,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [uid, email, name, photoUrl];
}

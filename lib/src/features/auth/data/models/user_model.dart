import 'package:keepsyn_app/src/features/auth/domain/entities/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class UserModel extends User {
  const UserModel({
    required super.uid,
    super.email,
    super.name,
    super.photoUrl,
  });

  // Factory constructor para crear un UserModel a partir del objeto User de Firebase.
  factory UserModel.fromFirebaseUser(firebase.User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      name: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

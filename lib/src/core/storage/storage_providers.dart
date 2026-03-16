import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keepsyn_app/src/core/storage/local_storage.dart';
import 'package:keepsyn_app/src/core/storage/secure_storage_impl.dart';

final localStorageProvider = Provider<ILocalStorage>((ref) {
  return SecureStorageImpl();
});

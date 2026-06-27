import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:keepsyn_app/src/core/constants/env_constants.dart';
import 'package:keepsyn_app/src/features/auth/presentation/riverpod/auth_providers.dart';

part 'api_dio_provider.g.dart';

/// Cliente HTTP único para toda la app.
///
/// Inyecta el Firebase ID token en cada request leyendo [firebaseAuthProvider]
/// del grafo de Riverpod — sin llamadas a FirebaseAuth.instance directamente.
@Riverpod(keepAlive: true)
Dio apiDio(Ref ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: EnvConstants.syncApiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await firebaseAuth.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}

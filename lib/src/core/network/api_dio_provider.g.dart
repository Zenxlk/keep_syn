// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cliente HTTP único para toda la app.
///
/// Inyecta el Firebase ID token en cada request leyendo [firebaseAuthProvider]
/// del grafo de Riverpod — sin llamadas a FirebaseAuth.instance directamente.

@ProviderFor(apiDio)
final apiDioProvider = ApiDioProvider._();

/// Cliente HTTP único para toda la app.
///
/// Inyecta el Firebase ID token en cada request leyendo [firebaseAuthProvider]
/// del grafo de Riverpod — sin llamadas a FirebaseAuth.instance directamente.

final class ApiDioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Cliente HTTP único para toda la app.
  ///
  /// Inyecta el Firebase ID token en cada request leyendo [firebaseAuthProvider]
  /// del grafo de Riverpod — sin llamadas a FirebaseAuth.instance directamente.
  ApiDioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiDioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiDioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return apiDio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$apiDioHash() => r'7bbf17ebbc834180a631bc0b37293b8d83b864ff';

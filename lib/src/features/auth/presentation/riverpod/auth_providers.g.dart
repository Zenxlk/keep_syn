// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$firebaseAuthHash() => r'8c3e9d11b27110ca96130356b5ef4d5d34a5ffc2';

/// See also [firebaseAuth].
@ProviderFor(firebaseAuth)
final firebaseAuthProvider = Provider<FirebaseAuth>.internal(
  firebaseAuth,
  name: r'firebaseAuthProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$firebaseAuthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseAuthRef = ProviderRef<FirebaseAuth>;
String _$googleSignInHash() => r'be6e657edfb1790d127cff1d3820a50c34e65011';

/// See also [googleSignIn].
@ProviderFor(googleSignIn)
final googleSignInProvider = Provider<GoogleSignIn>.internal(
  googleSignIn,
  name: r'googleSignInProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$googleSignInHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GoogleSignInRef = ProviderRef<GoogleSignIn>;
String _$firebaseFunctionsHash() => r'd93861c0944a5de507eaed64d4c4ecf0b90ae818';

/// See also [firebaseFunctions].
@ProviderFor(firebaseFunctions)
final firebaseFunctionsProvider = Provider<FirebaseFunctions>.internal(
  firebaseFunctions,
  name: r'firebaseFunctionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$firebaseFunctionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseFunctionsRef = ProviderRef<FirebaseFunctions>;
String _$firebaseErrorLoggerHash() =>
    r'5ffb6637fcd7c939d09d212701d73072c5c24c7c';

/// See also [firebaseErrorLogger].
@ProviderFor(firebaseErrorLogger)
final firebaseErrorLoggerProvider = Provider<IFirebaseErrorLogger>.internal(
  firebaseErrorLogger,
  name: r'firebaseErrorLoggerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$firebaseErrorLoggerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FirebaseErrorLoggerRef = ProviderRef<IFirebaseErrorLogger>;
String _$authRemoteDataSourceHash() =>
    r'336bf4e072b06d3072eee9d0db0809f30dc02787';

/// See also [authRemoteDataSource].
@ProviderFor(authRemoteDataSource)
final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>.internal(
  authRemoteDataSource,
  name: r'authRemoteDataSourceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authRemoteDataSourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRemoteDataSourceRef = ProviderRef<IAuthRemoteDataSource>;
String _$authRepositoryHash() => r'bde7e7f3002f43b082f9286b0900c42e1630a268';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = Provider<IAuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = ProviderRef<IAuthRepository>;
String _$authControllerHash() => r'989a234f63ef9c8ca231a4b4bd5c6dc59912687b';

/// See also [AuthController].
@ProviderFor(AuthController)
final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>.internal(
      AuthController.new,
      name: r'authControllerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$authControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthController = Notifier<AuthControllerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

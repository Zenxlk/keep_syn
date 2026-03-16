// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sharedPreferencesHash() => r'48e60558ea6530114ea20ea03e69b9fb339ab129';

/// See also [sharedPreferences].
@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>.internal(
  sharedPreferences,
  name: r'sharedPreferencesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sharedPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SharedPreferencesRef = FutureProviderRef<SharedPreferences>;
String _$syncLocalStoreHash() => r'346a26a4a4e05308d0693c4bf51118419fe7c8db';

/// See also [syncLocalStore].
@ProviderFor(syncLocalStore)
final syncLocalStoreProvider = FutureProvider<ISyncLocalStore>.internal(
  syncLocalStore,
  name: r'syncLocalStoreProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$syncLocalStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncLocalStoreRef = FutureProviderRef<ISyncLocalStore>;
String _$syncServiceHash() => r'030e68d6ef74b170e5063daece42816869571f68';

/// See also [syncService].
@ProviderFor(syncService)
final syncServiceProvider = Provider<ISyncService>.internal(
  syncService,
  name: r'syncServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$syncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncServiceRef = ProviderRef<ISyncService>;
String _$syncRepositoryHash() => r'63019b08f6130d160c31a0c5a0dc0b69316e1096';

/// See also [syncRepository].
@ProviderFor(syncRepository)
final syncRepositoryProvider = Provider<ISyncRepository>.internal(
  syncRepository,
  name: r'syncRepositoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$syncRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncRepositoryRef = ProviderRef<ISyncRepository>;
String _$syncControllerHash() => r'bed3542062a5035412ea6a7c80ee5847cb9fd953';

/// See also [SyncController].
@ProviderFor(SyncController)
final syncControllerProvider =
    NotifierProvider<SyncController, SyncControllerState>.internal(
      SyncController.new,
      name: r'syncControllerProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$syncControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SyncController = Notifier<SyncControllerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package

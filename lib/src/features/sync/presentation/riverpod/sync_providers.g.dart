// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SharedPreferences>,
          SharedPreferences,
          FutureOr<SharedPreferences>
        >
    with
        $FutureModifier<SharedPreferences>,
        $FutureProvider<SharedPreferences> {
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SharedPreferences> create(Ref ref) {
    return sharedPreferences(ref);
  }
}

String _$sharedPreferencesHash() => r'48e60558ea6530114ea20ea03e69b9fb339ab129';

@ProviderFor(syncLocalStore)
final syncLocalStoreProvider = SyncLocalStoreProvider._();

final class SyncLocalStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<ISyncLocalStore>,
          ISyncLocalStore,
          FutureOr<ISyncLocalStore>
        >
    with $FutureModifier<ISyncLocalStore>, $FutureProvider<ISyncLocalStore> {
  SyncLocalStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLocalStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLocalStoreHash();

  @$internal
  @override
  $FutureProviderElement<ISyncLocalStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ISyncLocalStore> create(Ref ref) {
    return syncLocalStore(ref);
  }
}

String _$syncLocalStoreHash() => r'346a26a4a4e05308d0693c4bf51118419fe7c8db';

@ProviderFor(syncService)
final syncServiceProvider = SyncServiceProvider._();

final class SyncServiceProvider
    extends $FunctionalProvider<ISyncService, ISyncService, ISyncService>
    with $Provider<ISyncService> {
  SyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncServiceHash();

  @$internal
  @override
  $ProviderElement<ISyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISyncService create(Ref ref) {
    return syncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISyncService>(value),
    );
  }
}

String _$syncServiceHash() => r'00f69995fcc352ebcce2a16479a7deaeb49bc959';

@ProviderFor(syncRepository)
final syncRepositoryProvider = SyncRepositoryProvider._();

final class SyncRepositoryProvider
    extends
        $FunctionalProvider<ISyncRepository, ISyncRepository, ISyncRepository>
    with $Provider<ISyncRepository> {
  SyncRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncRepositoryHash();

  @$internal
  @override
  $ProviderElement<ISyncRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ISyncRepository create(Ref ref) {
    return syncRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ISyncRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ISyncRepository>(value),
    );
  }
}

String _$syncRepositoryHash() => r'63019b08f6130d160c31a0c5a0dc0b69316e1096';

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncControllerState> {
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncControllerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncControllerState>(value),
    );
  }
}

String _$syncControllerHash() => r'f3ace3a3b4f58cc81f8c626ba84ba6de6de21056';

abstract class _$SyncController extends $Notifier<SyncControllerState> {
  SyncControllerState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncControllerState, SyncControllerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncControllerState, SyncControllerState>,
              SyncControllerState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

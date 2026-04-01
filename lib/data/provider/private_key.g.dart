// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_key.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivateKeyNotifier)
final privateKeyProvider = PrivateKeyNotifierProvider._();

final class PrivateKeyNotifierProvider
    extends $NotifierProvider<PrivateKeyNotifier, PrivateKeyState> {
  PrivateKeyNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privateKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privateKeyNotifierHash();

  @$internal
  @override
  PrivateKeyNotifier create() => PrivateKeyNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateKeyState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateKeyState>(value),
    );
  }
}

String _$privateKeyNotifierHash() =>
    r'79d02e116fe665df1ccb0719590947e109a5a736';

abstract class _$PrivateKeyNotifier extends $Notifier<PrivateKeyState> {
  PrivateKeyState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PrivateKeyState, PrivateKeyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PrivateKeyState, PrivateKeyState>,
              PrivateKeyState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

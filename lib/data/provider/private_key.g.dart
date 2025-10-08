// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_key.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PrivateKeyNotifier)
const privateKeyProvider = PrivateKeyNotifierProvider._();

final class PrivateKeyNotifierProvider
    extends $NotifierProvider<PrivateKeyNotifier, PrivateKeyState> {
  const PrivateKeyNotifierProvider._()
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
    r'12edd05dca29d1cbc9e2a3e047c3d417d22f7bb7';

abstract class _$PrivateKeyNotifier extends $Notifier<PrivateKeyState> {
  PrivateKeyState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<PrivateKeyState, PrivateKeyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PrivateKeyState, PrivateKeyState>,
              PrivateKeyState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

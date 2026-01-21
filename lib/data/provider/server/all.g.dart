// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServersNotifier)
const serversProvider = ServersNotifierProvider._();

final class ServersNotifierProvider
    extends $NotifierProvider<ServersNotifier, ServersState> {
  const ServersNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serversProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serversNotifierHash();

  @$internal
  @override
  ServersNotifier create() => ServersNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServersState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServersState>(value),
    );
  }
}

String _$serversNotifierHash() => r'277d1b219235f14bcc1b82a1e16260c2f28decdb';

abstract class _$ServersNotifier extends $Notifier<ServersState> {
  ServersState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ServersState, ServersState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServersState, ServersState>,
              ServersState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

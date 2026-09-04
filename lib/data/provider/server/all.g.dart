// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'all.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServersNotifier)
final serversProvider = ServersNotifierProvider._();

final class ServersNotifierProvider
    extends $NotifierProvider<ServersNotifier, ServersState> {
  ServersNotifierProvider._()
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

String _$serversNotifierHash() => r'1cef626d3a0773c0a1c68974a98c230c98efb708';

abstract class _$ServersNotifier extends $Notifier<ServersState> {
  ServersState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ServersState, ServersState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServersState, ServersState>,
              ServersState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

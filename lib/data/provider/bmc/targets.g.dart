// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'targets.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages all [BmcTarget] records (both standalone and server-linked).

@ProviderFor(BmcTargetsNotifier)
final bmcTargetsProvider = BmcTargetsNotifierProvider._();

/// Manages all [BmcTarget] records (both standalone and server-linked).
final class BmcTargetsNotifierProvider
    extends $NotifierProvider<BmcTargetsNotifier, BmcTargetsState> {
  /// Manages all [BmcTarget] records (both standalone and server-linked).
  BmcTargetsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bmcTargetsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bmcTargetsNotifierHash();

  @$internal
  @override
  BmcTargetsNotifier create() => BmcTargetsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BmcTargetsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BmcTargetsState>(value),
    );
  }
}

String _$bmcTargetsNotifierHash() =>
    r'6d039fc65db596343f2d7c3320dc09449f60aa35';

/// Manages all [BmcTarget] records (both standalone and server-linked).

abstract class _$BmcTargetsNotifier extends $Notifier<BmcTargetsState> {
  BmcTargetsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BmcTargetsState, BmcTargetsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BmcTargetsState, BmcTargetsState>,
              BmcTargetsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

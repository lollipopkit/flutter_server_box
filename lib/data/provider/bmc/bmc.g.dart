// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One server's BMC.
///
/// Holds a [RedfishClient], and therefore a session on a device that allows
/// few of them — so the client is closed on dispose, which is the only thing
/// that gives the session back. See `docs/principles/bmc.md`.

@ProviderFor(BmcNotifier)
final bmcProvider = BmcNotifierFamily._();

/// One server's BMC.
///
/// Holds a [RedfishClient], and therefore a session on a device that allows
/// few of them — so the client is closed on dispose, which is the only thing
/// that gives the session back. See `docs/principles/bmc.md`.
final class BmcNotifierProvider
    extends $NotifierProvider<BmcNotifier, BmcState> {
  /// One server's BMC.
  ///
  /// Holds a [RedfishClient], and therefore a session on a device that allows
  /// few of them — so the client is closed on dispose, which is the only thing
  /// that gives the session back. See `docs/principles/bmc.md`.
  BmcNotifierProvider._({
    required BmcNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'bmcProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bmcNotifierHash();

  @override
  String toString() {
    return r'bmcProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BmcNotifier create() => BmcNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BmcState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BmcState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BmcNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bmcNotifierHash() => r'29bba54ad478072aac61bc35544112ac591dd831';

/// One server's BMC.
///
/// Holds a [RedfishClient], and therefore a session on a device that allows
/// few of them — so the client is closed on dispose, which is the only thing
/// that gives the session back. See `docs/principles/bmc.md`.

final class BmcNotifierFamily extends $Family
    with $ClassFamilyOverride<BmcNotifier, BmcState, BmcState, BmcState, Spi> {
  BmcNotifierFamily._()
    : super(
        retry: null,
        name: r'bmcProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One server's BMC.
  ///
  /// Holds a [RedfishClient], and therefore a session on a device that allows
  /// few of them — so the client is closed on dispose, which is the only thing
  /// that gives the session back. See `docs/principles/bmc.md`.

  BmcNotifierProvider call(Spi spi) =>
      BmcNotifierProvider._(argument: spi, from: this);

  @override
  String toString() => r'bmcProvider';
}

/// One server's BMC.
///
/// Holds a [RedfishClient], and therefore a session on a device that allows
/// few of them — so the client is closed on dispose, which is the only thing
/// that gives the session back. See `docs/principles/bmc.md`.

abstract class _$BmcNotifier extends $Notifier<BmcState> {
  late final _$args = ref.$arg as Spi;
  Spi get spi => _$args;

  BmcState build(Spi spi);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BmcState, BmcState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BmcState, BmcState>,
              BmcState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

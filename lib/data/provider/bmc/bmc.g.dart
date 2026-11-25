// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bmc.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One server's BMC.
///
/// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
/// device that allows few of them — so the client is closed on dispose, which
/// is the only thing that gives the session back.

@ProviderFor(BmcNotifier)
final bmcProvider = BmcNotifierFamily._();

/// One server's BMC.
///
/// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
/// device that allows few of them — so the client is closed on dispose, which
/// is the only thing that gives the session back.
final class BmcNotifierProvider
    extends $NotifierProvider<BmcNotifier, BmcState> {
  /// One server's BMC.
  ///
  /// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
  /// device that allows few of them — so the client is closed on dispose, which
  /// is the only thing that gives the session back.
  BmcNotifierProvider._({
    required BmcNotifierFamily super.from,
    required String super.argument,
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

String _$bmcNotifierHash() => r'0d269b026062ab981333764539a9477360a56863';

/// One server's BMC.
///
/// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
/// device that allows few of them — so the client is closed on dispose, which
/// is the only thing that gives the session back.

final class BmcNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          BmcNotifier,
          BmcState,
          BmcState,
          BmcState,
          String
        > {
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
  /// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
  /// device that allows few of them — so the client is closed on dispose, which
  /// is the only thing that gives the session back.

  BmcNotifierProvider call(String targetId) =>
      BmcNotifierProvider._(argument: targetId, from: this);

  @override
  String toString() => r'bmcProvider';
}

/// One server's BMC.
///
/// Holds a [BmcClient] (`sbm_redfish` over FFI), and therefore a session on a
/// device that allows few of them — so the client is closed on dispose, which
/// is the only thing that gives the session back.

abstract class _$BmcNotifier extends $Notifier<BmcState> {
  late final _$args = ref.$arg as String;
  String get targetId => _$args;

  BmcState build(String targetId);
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'port_forward_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PortForwardNotifier)
const portForwardProvider = PortForwardNotifierFamily._();

final class PortForwardNotifierProvider
    extends $NotifierProvider<PortForwardNotifier, PortForwardState> {
  const PortForwardNotifierProvider._({
    required PortForwardNotifierFamily super.from,
    required Spi super.argument,
  }) : super(
         retry: null,
         name: r'portForwardProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$portForwardNotifierHash();

  @override
  String toString() {
    return r'portForwardProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PortForwardNotifier create() => PortForwardNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PortForwardState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PortForwardState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PortForwardNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$portForwardNotifierHash() =>
    r'6f598fc27998d702254ed2ed03fda433b5e3ef5d';

final class PortForwardNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PortForwardNotifier,
          PortForwardState,
          PortForwardState,
          PortForwardState,
          Spi
        > {
  const PortForwardNotifierFamily._()
    : super(
        retry: null,
        name: r'portForwardProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PortForwardNotifierProvider call(Spi spiParam) =>
      PortForwardNotifierProvider._(argument: spiParam, from: this);

  @override
  String toString() => r'portForwardProvider';
}

abstract class _$PortForwardNotifier extends $Notifier<PortForwardState> {
  late final _$args = ref.$arg as Spi;
  Spi get spiParam => _$args;

  PortForwardState build(Spi spiParam);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<PortForwardState, PortForwardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PortForwardState, PortForwardState>,
              PortForwardState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

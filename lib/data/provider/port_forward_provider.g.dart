// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'port_forward_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PortForwardNotifier)
final portForwardProvider = PortForwardNotifierFamily._();

final class PortForwardNotifierProvider
    extends $NotifierProvider<PortForwardNotifier, PortForwardState> {
  PortForwardNotifierProvider._({
    required PortForwardNotifierFamily super.from,
    required String super.argument,
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
    r'd06ec72d3d47834e1a6db315c8d17e33e1628b3e';

final class PortForwardNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          PortForwardNotifier,
          PortForwardState,
          PortForwardState,
          PortForwardState,
          String
        > {
  PortForwardNotifierFamily._()
    : super(
        retry: null,
        name: r'portForwardProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PortForwardNotifierProvider call(String serverId) =>
      PortForwardNotifierProvider._(argument: serverId, from: this);

  @override
  String toString() => r'portForwardProvider';
}

abstract class _$PortForwardNotifier extends $Notifier<PortForwardState> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  PortForwardState build(String serverId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PortForwardState, PortForwardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PortForwardState, PortForwardState>,
              PortForwardState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

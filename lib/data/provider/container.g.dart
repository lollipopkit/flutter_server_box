// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'container.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ContainerNotifier)
const containerProvider = ContainerNotifierFamily._();

final class ContainerNotifierProvider
    extends $NotifierProvider<ContainerNotifier, ContainerState> {
  const ContainerNotifierProvider._({
    required ContainerNotifierFamily super.from,
    required (SSHClient?, String, String, BuildContext) super.argument,
  }) : super(
         retry: null,
         name: r'containerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$containerNotifierHash();

  @override
  String toString() {
    return r'containerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ContainerNotifier create() => ContainerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContainerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContainerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContainerNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$containerNotifierHash() => r'2f8eb969f0e66e28f60b6fc11169e8f28315ed32';

final class ContainerNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ContainerNotifier,
          ContainerState,
          ContainerState,
          ContainerState,
          (SSHClient?, String, String, BuildContext)
        > {
  const ContainerNotifierFamily._()
    : super(
        retry: null,
        name: r'containerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContainerNotifierProvider call(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  ) => ContainerNotifierProvider._(
    argument: (client, userName, hostId, context),
    from: this,
  );

  @override
  String toString() => r'containerProvider';
}

abstract class _$ContainerNotifier extends $Notifier<ContainerState> {
  late final _$args = ref.$arg as (SSHClient?, String, String, BuildContext);
  SSHClient? get client => _$args.$1;
  String get userName => _$args.$2;
  String get hostId => _$args.$3;
  BuildContext get context => _$args.$4;

  ContainerState build(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2, _$args.$3, _$args.$4);
    final ref = this.ref as $Ref<ContainerState, ContainerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ContainerState, ContainerState>,
              ContainerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

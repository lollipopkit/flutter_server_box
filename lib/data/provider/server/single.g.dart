// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServerNotifier)
const serverProvider = ServerNotifierFamily._();

final class ServerNotifierProvider
    extends $NotifierProvider<ServerNotifier, ServerState> {
  const ServerNotifierProvider._({
    required ServerNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'serverProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$serverNotifierHash();

  @override
  String toString() {
    return r'serverProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ServerNotifier create() => ServerNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ServerNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$serverNotifierHash() => r'04b1beef4d96242fd10d5b523c6f5f17eb774bae';

final class ServerNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ServerNotifier,
          ServerState,
          ServerState,
          ServerState,
          String
        > {
  const ServerNotifierFamily._()
    : super(
        retry: null,
        name: r'serverProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ServerNotifierProvider call(String serverId) =>
      ServerNotifierProvider._(argument: serverId, from: this);

  @override
  String toString() => r'serverProvider';
}

abstract class _$ServerNotifier extends $Notifier<ServerState> {
  late final _$args = ref.$arg as String;
  String get serverId => _$args;

  ServerState build(String serverId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ServerState, ServerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServerState, ServerState>,
              ServerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

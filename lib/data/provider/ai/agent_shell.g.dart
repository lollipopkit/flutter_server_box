// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_shell.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AgentShell)
final agentShellProvider = AgentShellProvider._();

final class AgentShellProvider
    extends $NotifierProvider<AgentShell, AgentShellMode> {
  AgentShellProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentShellProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentShellHash();

  @$internal
  @override
  AgentShell create() => AgentShell();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentShellMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentShellMode>(value),
    );
  }
}

String _$agentShellHash() => r'14ffb9ade96c5d2b29d7cffdc3574b183bf60e72';

abstract class _$AgentShell extends $Notifier<AgentShellMode> {
  AgentShellMode build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AgentShellMode, AgentShellMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AgentShellMode, AgentShellMode>,
              AgentShellMode,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

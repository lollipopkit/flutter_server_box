// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_shell.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the Agent follows you onto the other tabs, and how much of it comes
/// along.
///
/// The conversation is in `agentSessionProvider` and carries on either way —
/// see [FloatShellMode], which the terminal's floating window shares.

@ProviderFor(AgentShell)
final agentShellProvider = AgentShellProvider._();

/// Whether the Agent follows you onto the other tabs, and how much of it comes
/// along.
///
/// The conversation is in `agentSessionProvider` and carries on either way —
/// see [FloatShellMode], which the terminal's floating window shares.
final class AgentShellProvider
    extends $NotifierProvider<AgentShell, FloatShellMode> {
  /// Whether the Agent follows you onto the other tabs, and how much of it comes
  /// along.
  ///
  /// The conversation is in `agentSessionProvider` and carries on either way —
  /// see [FloatShellMode], which the terminal's floating window shares.
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
  Override overrideWithValue(FloatShellMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FloatShellMode>(value),
    );
  }
}

String _$agentShellHash() => r'7b4e8674930e490318e3d9e0af4e61b2eb09bda0';

/// Whether the Agent follows you onto the other tabs, and how much of it comes
/// along.
///
/// The conversation is in `agentSessionProvider` and carries on either way —
/// see [FloatShellMode], which the terminal's floating window shares.

abstract class _$AgentShell extends $Notifier<FloatShellMode> {
  FloatShellMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FloatShellMode, FloatShellMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FloatShellMode, FloatShellMode>,
              FloatShellMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

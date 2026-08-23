// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_scope.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which [AgentScopeHost] each scope has, right now.
///
/// A plain object rather than a provider holding a map, for two reasons. The
/// page registers from `initState`, and modifying a provider during a build is
/// not allowed. And the answer must not be cached: a terminal opens and closes
/// under a session that outlives both, so the lookup happens per use.

@ProviderFor(agentScopeHosts)
final agentScopeHostsProvider = AgentScopeHostsProvider._();

/// Which [AgentScopeHost] each scope has, right now.
///
/// A plain object rather than a provider holding a map, for two reasons. The
/// page registers from `initState`, and modifying a provider during a build is
/// not allowed. And the answer must not be cached: a terminal opens and closes
/// under a session that outlives both, so the lookup happens per use.

final class AgentScopeHostsProvider
    extends
        $FunctionalProvider<AgentScopeHosts, AgentScopeHosts, AgentScopeHosts>
    with $Provider<AgentScopeHosts> {
  /// Which [AgentScopeHost] each scope has, right now.
  ///
  /// A plain object rather than a provider holding a map, for two reasons. The
  /// page registers from `initState`, and modifying a provider during a build is
  /// not allowed. And the answer must not be cached: a terminal opens and closes
  /// under a session that outlives both, so the lookup happens per use.
  AgentScopeHostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentScopeHostsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentScopeHostsHash();

  @$internal
  @override
  $ProviderElement<AgentScopeHosts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AgentScopeHosts create(Ref ref) {
    return agentScopeHosts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentScopeHosts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentScopeHosts>(value),
    );
  }
}

String _$agentScopeHostsHash() => r'88f5b6d34b9973c2b3b9461fd166923e12d4ab04';

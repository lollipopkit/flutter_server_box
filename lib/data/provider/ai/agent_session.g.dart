// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// An Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in a page's `State` because a conversation has more
/// than one view: the Agent tab and the floating shell show the same one, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
///
/// Keyed by [scope], which is the same key the conversations are stored under:
/// [globalAgentConversationScope] for the app-wide Agent, a server's id for
/// the Agent in that server's terminal. Both run this loop. What they do *not*
/// share is on [AgentScopeHost] — the machine, the tools, and who carries out
/// an approved proposal — which is why there is one of these rather than two.

@ProviderFor(AgentSession)
final agentSessionProvider = AgentSessionFamily._();

/// An Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in a page's `State` because a conversation has more
/// than one view: the Agent tab and the floating shell show the same one, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
///
/// Keyed by [scope], which is the same key the conversations are stored under:
/// [globalAgentConversationScope] for the app-wide Agent, a server's id for
/// the Agent in that server's terminal. Both run this loop. What they do *not*
/// share is on [AgentScopeHost] — the machine, the tools, and who carries out
/// an approved proposal — which is why there is one of these rather than two.
final class AgentSessionProvider
    extends $NotifierProvider<AgentSession, AgentSessionState> {
  /// An Agent conversation, and everything it is doing right now.
  ///
  /// Lives here rather than in a page's `State` because a conversation has more
  /// than one view: the Agent tab and the floating shell show the same one, and
  /// a turn started in one has to keep streaming while the other is on screen —
  /// or while neither is. Nothing about a widget's lifetime should end a turn;
  /// only the user stopping it, through [stopWork].
  ///
  /// Keyed by [scope], which is the same key the conversations are stored under:
  /// [globalAgentConversationScope] for the app-wide Agent, a server's id for
  /// the Agent in that server's terminal. Both run this loop. What they do *not*
  /// share is on [AgentScopeHost] — the machine, the tools, and who carries out
  /// an approved proposal — which is why there is one of these rather than two.
  AgentSessionProvider._({
    required AgentSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'agentSessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$agentSessionHash();

  @override
  String toString() {
    return r'agentSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AgentSession create() => AgentSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AgentSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AgentSessionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$agentSessionHash() => r'2cbd6bcabfea6e43f57c091af1a7161492e6e0da';

/// An Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in a page's `State` because a conversation has more
/// than one view: the Agent tab and the floating shell show the same one, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
///
/// Keyed by [scope], which is the same key the conversations are stored under:
/// [globalAgentConversationScope] for the app-wide Agent, a server's id for
/// the Agent in that server's terminal. Both run this loop. What they do *not*
/// share is on [AgentScopeHost] — the machine, the tools, and who carries out
/// an approved proposal — which is why there is one of these rather than two.

final class AgentSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          AgentSession,
          AgentSessionState,
          AgentSessionState,
          AgentSessionState,
          String
        > {
  AgentSessionFamily._()
    : super(
        retry: null,
        name: r'agentSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// An Agent conversation, and everything it is doing right now.
  ///
  /// Lives here rather than in a page's `State` because a conversation has more
  /// than one view: the Agent tab and the floating shell show the same one, and
  /// a turn started in one has to keep streaming while the other is on screen —
  /// or while neither is. Nothing about a widget's lifetime should end a turn;
  /// only the user stopping it, through [stopWork].
  ///
  /// Keyed by [scope], which is the same key the conversations are stored under:
  /// [globalAgentConversationScope] for the app-wide Agent, a server's id for
  /// the Agent in that server's terminal. Both run this loop. What they do *not*
  /// share is on [AgentScopeHost] — the machine, the tools, and who carries out
  /// an approved proposal — which is why there is one of these rather than two.

  AgentSessionProvider call(String scope) =>
      AgentSessionProvider._(argument: scope, from: this);

  @override
  String toString() => r'agentSessionProvider';
}

/// An Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in a page's `State` because a conversation has more
/// than one view: the Agent tab and the floating shell show the same one, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
///
/// Keyed by [scope], which is the same key the conversations are stored under:
/// [globalAgentConversationScope] for the app-wide Agent, a server's id for
/// the Agent in that server's terminal. Both run this loop. What they do *not*
/// share is on [AgentScopeHost] — the machine, the tools, and who carries out
/// an approved proposal — which is why there is one of these rather than two.

abstract class _$AgentSession extends $Notifier<AgentSessionState> {
  late final _$args = ref.$arg as String;
  String get scope => _$args;

  AgentSessionState build(String scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AgentSessionState, AgentSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AgentSessionState, AgentSessionState>,
              AgentSessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

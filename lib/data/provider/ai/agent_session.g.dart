// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in the page's `State` because it has more than one
/// view: the Agent tab and the floating shell show the same conversation, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].

@ProviderFor(AgentSession)
final agentSessionProvider = AgentSessionProvider._();

/// The app-wide Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in the page's `State` because it has more than one
/// view: the Agent tab and the floating shell show the same conversation, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
final class AgentSessionProvider
    extends $NotifierProvider<AgentSession, AgentSessionState> {
  /// The app-wide Agent conversation, and everything it is doing right now.
  ///
  /// Lives here rather than in the page's `State` because it has more than one
  /// view: the Agent tab and the floating shell show the same conversation, and
  /// a turn started in one has to keep streaming while the other is on screen —
  /// or while neither is. Nothing about a widget's lifetime should end a turn;
  /// only the user stopping it, through [stopWork].
  AgentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentSessionHash();

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
}

String _$agentSessionHash() => r'fc8941a55ff3364e9f8381adb6e3e6d0c8ed4fb9';

/// The app-wide Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in the page's `State` because it has more than one
/// view: the Agent tab and the floating shell show the same conversation, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].

abstract class _$AgentSession extends $Notifier<AgentSessionState> {
  AgentSessionState build();
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
    return element.handleCreate(ref, build);
  }
}

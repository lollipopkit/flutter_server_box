import 'dart:async';

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';

part 'agent_session.g.dart';

/// Why a notice is in the timeline.
///
/// A reason rather than the sentence itself. The timeline outlives the widget
/// that shows it and is read by more than one of them, so the wording has to
/// be chosen where there is a `BuildContext` — at render time, in whatever
/// language the app is in *then*, not the one it was in when the notice
/// happened.
enum AgentNoticeKind {
  declined,
  interrupted,

  /// The command was put on the terminal's input line for the user to run
  /// themselves, so what it did — or whether it ran at all — is not known here.
  /// Only a terminal Agent can reach this.
  inserted,
}

@immutable
sealed class AgentTimelineEntry {
  const AgentTimelineEntry();
}

final class AgentUserEntry extends AgentTimelineEntry {
  const AgentUserEntry(this.content);

  final String content;
}

final class AgentAssistantEntry extends AgentTimelineEntry {
  const AgentAssistantEntry(this.content);

  final String content;
}

final class AgentToolResultEntry extends AgentTimelineEntry {
  const AgentToolResultEntry(
    this.proposal,
    this.result, {
    this.autoApproved = false,
  });

  final AskAiCommand proposal;
  final AgentToolExecutionResult result;
  final bool autoApproved;
}

/// A shell command run in a terminal, and what it printed.
///
/// Separate from [AgentToolResultEntry] rather than converted into one: the
/// two are stored differently, and the stored form is what the model reads
/// back as the tool's output. Converting would rewrite the protocol for every
/// terminal conversation, including the ones already on disk.
final class AgentShellResultEntry extends AgentTimelineEntry {
  const AgentShellResultEntry(
    this.command,
    this.result, {
    this.autoApproved = false,
  });

  final AskAiCommand command;
  final AskAiCommandResult result;
  final bool autoApproved;
}

final class AgentNoticeEntry extends AgentTimelineEntry {
  const AgentNoticeEntry(this.kind);

  final AgentNoticeKind kind;
}

/// A tool output the app could not interpret, shown as it arrived.
final class AgentRawNoticeEntry extends AgentTimelineEntry {
  const AgentRawNoticeEntry(this.text);

  final String text;
}

const _unset = Object();

@immutable
class AgentSessionState {
  const AgentSessionState({
    required this.protocol,
    this.timeline = const [],
    this.history = const [],
    this.conversations = const [],
    this.conversation,
    this.pendingTool,
    this.pendingToolRestored = false,
    this.streamingContent,
    this.error,
    this.isStreaming = false,
    this.isExecuting = false,
    this.turnCompleted = false,
    this.autoRunCount = 0,
  });

  final AskAiProtocol protocol;
  final List<AgentTimelineEntry> timeline;
  final List<AskAiConversationItem> history;

  /// Every stored conversation in this scope, read from the box rather than
  /// re-read on every build: each fetch deserialises every conversation's full
  /// item list, and the column that shows them rebuilds once per keystroke.
  final List<AgentConversation> conversations;

  final AgentConversation? conversation;
  final AskAiCommand? pendingTool;

  /// The pending tool came back from storage rather than from this turn, so it
  /// has never been reviewed and must not auto-run.
  final bool pendingToolRestored;

  final String? streamingContent;

  /// The failure as it was thrown, not a sentence about it. Describing it
  /// needs l10n, which needs a `BuildContext`, which this does not have.
  final Object? error;

  final bool isStreaming;
  final bool isExecuting;
  final bool turnCompleted;
  final int autoRunCount;

  bool get isWorking => isStreaming || isExecuting;

  bool get isEmpty => timeline.isEmpty && !isStreaming && pendingTool == null;

  AgentSessionState copyWith({
    AskAiProtocol? protocol,
    List<AgentTimelineEntry>? timeline,
    List<AskAiConversationItem>? history,
    List<AgentConversation>? conversations,
    Object? conversation = _unset,
    Object? pendingTool = _unset,
    bool? pendingToolRestored,
    Object? streamingContent = _unset,
    Object? error = _unset,
    bool? isStreaming,
    bool? isExecuting,
    bool? turnCompleted,
    int? autoRunCount,
  }) {
    return AgentSessionState(
      protocol: protocol ?? this.protocol,
      timeline: timeline ?? this.timeline,
      history: history ?? this.history,
      conversations: conversations ?? this.conversations,
      conversation: identical(conversation, _unset)
          ? this.conversation
          : conversation as AgentConversation?,
      pendingTool: identical(pendingTool, _unset)
          ? this.pendingTool
          : pendingTool as AskAiCommand?,
      pendingToolRestored: pendingToolRestored ?? this.pendingToolRestored,
      streamingContent: identical(streamingContent, _unset)
          ? this.streamingContent
          : streamingContent as String?,
      error: identical(error, _unset) ? this.error : error,
      isStreaming: isStreaming ?? this.isStreaming,
      isExecuting: isExecuting ?? this.isExecuting,
      turnCompleted: turnCompleted ?? this.turnCompleted,
      autoRunCount: autoRunCount ?? this.autoRunCount,
    );
  }
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
@Riverpod(keepAlive: true)
class AgentSession extends _$AgentSession {
  StreamSubscription<AskAiEvent>? _subscription;
  StreamSubscription<void>? _conversationWatch;
  bool _submissionInFlight = false;

  /// The language to answer in, remembered from the last thing the user did.
  ///
  /// Passed in by the view, which is the only side that can read a locale. The
  /// turns this class starts on its own — after a tool result, after a decline
  /// — reuse it rather than dropping the hint halfway through a conversation.
  String? _localeHint;

  /// Read per use, never held: a terminal can close and reopen under a session
  /// that outlives both.
  AgentScopeHost get _host => ref.read(agentScopeHostsProvider)[scope];

  @override
  AgentSessionState build(String scope) {
    // Watches the box, so a write this class did not make — a restored backup
    // — is not missed.
    _conversationWatch = Stores.agentConversation.watch().listen((_) {
      state = state.copyWith(conversations: _fetchConversations());
    });
    ref.onDispose(() {
      _conversationWatch?.cancel();
      _subscription?.cancel();
    });

    return _stateFor(Stores.agentConversation.fetchActive(scope));
  }

  // ---------------------------------------------------------------- turns

  /// Whether the prompt was taken. False leaves it with the caller, which is
  /// what the composer needs to know before it empties its box.
  Future<bool> submitPrompt(String prompt, {String? localeHint}) async {
    final text = prompt.trim();
    if (text.isEmpty ||
        _submissionInFlight ||
        state.isWorking ||
        state.pendingTool != null) {
      return false;
    }
    _submissionInFlight = true;
    try {
      if (localeHint != null) _localeHint = localeHint;
      await _ensureConversation();
      state = state.copyWith(
        history: [...state.history, AskAiMessageItem.user(text)],
        timeline: [...state.timeline, AgentUserEntry(text)],
        autoRunCount: 0,
        error: null,
      );
      await _persist();
      startStream();
      return true;
    } finally {
      _submissionInFlight = false;
    }
  }

  void startStream({String? localeHint}) {
    if (localeHint != null) _localeHint = localeHint;
    _subscription?.cancel();
    state = state.copyWith(
      isStreaming: true,
      turnCompleted: false,
      error: null,
      streamingContent: '',
    );
    final host = _host;
    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          terminalContext: host.terminalContext,
          serverName: host.serverName,
          localeHint: _localeHint,
          conversation: List.unmodifiable(state.history),
          protocol: state.protocol,
          customInstructions: host.buildInstructions(localeHint: _localeHint),
          tools: host.tools,
        )
        .listen(
          _handleEvent,
          onError: (Object error, StackTrace stackTrace) {
            state = state.copyWith(
              error: error,
              isStreaming: false,
              streamingContent: null,
              pendingTool: null,
            );
          },
          onDone: () {
            if (state.turnCompleted) return;
            state = state.copyWith(isStreaming: false, streamingContent: null);
          },
        );
  }

  Future<void> _handleEvent(AskAiEvent event) async {
    if (event is AskAiContentDelta) {
      state = state.copyWith(
        streamingContent: (state.streamingContent ?? '') + event.delta,
      );
      return;
    }
    if (event is AskAiToolSuggestion) {
      if (state.pendingTool == null) {
        state = state.copyWith(
          pendingTool: event.command,
          pendingToolRestored: false,
        );
      }
      return;
    }
    if (event is AskAiStreamError) {
      _subscription?.cancel();
      _subscription = null;
      state = state.copyWith(
        error: event.error,
        isStreaming: false,
        streamingContent: null,
        pendingTool: null,
      );
      return;
    }
    if (event is! AskAiCompleted || state.turnCompleted) return;

    final text = event.fullText.trim().isNotEmpty
        ? event.fullText
        : (state.streamingContent ?? '');
    final command = event.commands.isEmpty
        ? state.pendingTool
        : event.commands.first;
    state = state.copyWith(
      turnCompleted: true,
      isStreaming: false,
      streamingContent: null,
      pendingTool: command,
      pendingToolRestored: false,
      protocol: event.protocol,
      history: [...state.history, ...event.outputItems],
      timeline: text.trim().isNotEmpty
          ? [...state.timeline, AgentAssistantEntry(text)]
          : null,
      error: text.trim().isEmpty && command == null
          ? const AgentNoResponse()
          : null,
    );
    await _persist();

    if (command == null) return;
    if (!shouldAutoRunAgentCommand(
      command: command,
      enabled: Stores.setting.askAiAutoRunSafeCommands.fetch(),
      restored: state.pendingToolRestored,
      runCount: state.autoRunCount,
    )) {
      return;
    }
    // Deferred rather than run inline: this is a stream callback, and starting
    // the next turn from inside it re-enters the listener that is still
    // delivering this one.
    scheduleMicrotask(() {
      if (identical(state.pendingTool, command)) {
        unawaited(runPendingTool(autoApproved: true));
      }
    });
  }

  /// Runs the pending tool.
  ///
  /// Reviewing it is the caller's job: a confirmation is a dialog, and this
  /// has no `BuildContext` to put one on. [autoApproved] only records how the
  /// run was reached — it does not skip anything, because the classification
  /// that allows auto-running already excludes everything that needs asking.
  Future<void> runPendingTool({bool autoApproved = false}) async {
    final proposal = state.pendingTool;
    if (proposal == null || state.isWorking) return;

    state = state.copyWith(
      isExecuting: true,
      error: null,
      autoRunCount: autoApproved ? state.autoRunCount + 1 : null,
    );
    final host = _host;
    AgentRunResult run;
    try {
      run = await host.execute(proposal);
    } catch (error) {
      run = host.describeFailure(proposal, error);
    }
    state = state.copyWith(
      history: [
        ...state.history,
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: run.toToolMessage(),
        ),
      ],
      timeline: [
        ...state.timeline,
        switch (run) {
          AgentToolRun(:final result) => AgentToolResultEntry(
            proposal,
            result,
            autoApproved: autoApproved,
          ),
          AgentShellRun(:final result) => AgentShellResultEntry(
            proposal,
            result,
            autoApproved: autoApproved,
          ),
        },
      ],
      pendingTool: null,
      pendingToolRestored: false,
      isExecuting: false,
    );
    await _persist();
    if (!run.cancelled) startStream();
  }

  Future<void> declinePendingTool() async {
    final proposal = state.pendingTool;
    if (proposal == null || state.isWorking) return;
    state = state.copyWith(
      history: [
        ...state.history,
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
      ],
      timeline: [
        ...state.timeline,
        const AgentNoticeEntry(AgentNoticeKind.declined),
      ],
      pendingTool: null,
      pendingToolRestored: false,
    );
    await _persist();
    startStream();
  }

  /// Puts the pending command on the terminal's input line instead of running
  /// it, and records that this is what happened.
  ///
  /// No turn follows, unlike [declinePendingTool]: whether the command runs at
  /// all is the user's now, and asking the model to carry on would have it
  /// answer about a result nobody has yet.
  ///
  /// False when this scope has nowhere to put a command, which is every scope
  /// but a terminal's.
  Future<bool> insertPendingTool() async {
    final proposal = state.pendingTool;
    if (proposal == null || state.isWorking) return false;
    if (!_host.insert(proposal.command)) return false;
    state = state.copyWith(
      history: [
        ...state.history,
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.inserted,
          ),
        ),
      ],
      timeline: [
        ...state.timeline,
        const AgentNoticeEntry(AgentNoticeKind.inserted),
      ],
      pendingTool: null,
      pendingToolRestored: false,
    );
    await _persist();
    return true;
  }

  Future<void> stopWork() async {
    if (state.isExecuting) {
      await _host.cancelCurrent();
      return;
    }
    if (!state.isStreaming) return;
    await _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(
      isStreaming: false,
      streamingContent: null,
      pendingTool: null,
      pendingToolRestored: false,
      timeline: [
        ...state.timeline,
        const AgentNoticeEntry(AgentNoticeKind.interrupted),
      ],
    );
  }

  // -------------------------------------------------------- conversations

  void restoreConversation(AgentConversation? conversation) {
    _subscription?.cancel();
    _subscription = null;
    state = _stateFor(conversation);
  }

  Future<void> beginNewConversation() async {
    if (state.isWorking) return;
    restoreConversation(
      Stores.agentConversation.create(
        serverId: scope,
        protocol: _configuredProtocol(),
        providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
        model: Stores.setting.askAiModel.fetch(),
      ),
    );
  }

  Future<void> activateConversation(AgentConversation conversation) async {
    if (state.isWorking ||
        conversation.serverId != scope) {
      return;
    }
    if (!Stores.agentConversation.setActive(
      scope,
      conversation.id,
    )) {
      return;
    }
    restoreConversation(conversation);
  }

  Future<bool> renameConversation(String id, String title) async {
    if (!Stores.agentConversation.rename(id, title)) return false;
    state = state.copyWith(
      conversations: _fetchConversations(),
      conversation: state.conversation?.id == id
          ? Stores.agentConversation.fetch(id)
          : state.conversation,
    );
    return true;
  }

  Future<void> deleteConversation(String id) async {
    // Re-checked here and not only where the confirmation was raised: an
    // auto-approved tool can start while that dialog is on screen, and tearing
    // the conversation down under it leaves the execution running, to append
    // its result to whichever conversation is active by then.
    if (state.isWorking) return;
    final deletingCurrent = state.conversation?.id == id;
    Stores.agentConversation.deleteConversation(
      scope,
      id,
    );
    if (deletingCurrent) {
      restoreConversation(
        Stores.agentConversation.fetchActive(scope),
      );
    } else {
      state = state.copyWith(conversations: _fetchConversations());
    }
  }

  Future<void> clearConversationHistory() async {
    if (state.isWorking) return;
    Stores.agentConversation.clearServer(scope);
    restoreConversation(null);
  }

  // --------------------------------------------------------------- internals

  AgentSessionState _stateFor(AgentConversation? conversation) {
    final replay = replayAgentTimeline(
      conversation?.items ?? const <AskAiConversationItem>[],
    );
    final stored = conversation?.protocol;
    return AgentSessionState(
      protocol: stored == null || stored == AskAiProtocol.auto
          ? _configuredProtocol()
          : stored,
      conversation: conversation,
      conversations: _fetchConversations(),
      history: List.of(conversation?.items ?? const <AskAiConversationItem>[]),
      timeline: replay.entries,
      pendingTool: replay.pending,
      pendingToolRestored: replay.pending != null,
    );
  }

  Future<AgentConversation> _ensureConversation() async {
    final existing = state.conversation;
    if (existing != null) return existing;
    final created = Stores.agentConversation.create(
      serverId: scope,
      protocol: state.protocol,
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
    );
    state = state.copyWith(
      conversation: created,
      conversations: _fetchConversations(),
    );
    return created;
  }

  Future<void> _persist() async {
    final conversation = await _ensureConversation();
    final trimmed = AgentConversationStore.trimItemsForStorage(state.history);
    final updated = conversation.copyWith(
      updatedAt: DateTime.now(),
      protocol: state.protocol,
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
      items: trimmed,
    );
    if (!Stores.agentConversation.save(updated)) return;
    state = state.copyWith(
      conversations: _fetchConversations(),
      conversation: Stores.agentConversation.fetch(updated.id) ?? updated,
      history: trimmed.length != state.history.length ? List.of(trimmed) : null,
    );
  }

  List<AgentConversation> _fetchConversations() =>
      Stores.agentConversation.fetchForServer(scope);

  AskAiProtocol _configuredProtocol() => AskAiRepository.resolveProtocol(
    configured: parseAskAiProtocol(Stores.setting.askAiProtocol.fetch()),
    endpoint: Stores.setting.askAiBaseUrl.fetch(),
  );
}

/// The app-wide Agent: the member of [agentSessionProvider] whose scope is not
/// a server.
///
/// Named because it is referred to in a dozen places and the family argument
/// is the same every time. A terminal's session has no such name — its scope
/// is the server's id, known only where there is a server.
final globalAgentSessionProvider = agentSessionProvider(
  globalAgentConversationScope,
);

/// Rebuilds a timeline from a stored conversation, and finds the tool call —
/// if any — that was proposed but never answered.
///
/// One function for both surfaces, which is possible because a conversation is
/// stored the same way either way. Only the tool output differs, and the two
/// encodings are told apart rather than guessed at: a global tool result is
/// marked and its decoder rejects anything unmarked, so it is tried first and
/// a shell result is what is left.
///
/// Entries carry data, never sentences. Nothing here knows what language the
/// app is in, and a conversation reopened after the user changed it should
/// read in the new one.
({List<AgentTimelineEntry> entries, AskAiCommand? pending}) replayAgentTimeline(
  List<AskAiConversationItem> items,
) {
  final entries = <AgentTimelineEntry>[];
  final calls = <String, List<_PendingCall>>{};
  final callOrder = <_PendingCall>[];

  for (final item in items) {
    switch (item) {
      case AskAiMessageItem(:final role, :final content):
        if (content.trim().isEmpty) continue;
        entries.add(
          role == AskAiMessageRole.user
              ? AgentUserEntry(content)
              : AgentAssistantEntry(content),
        );
      case AskAiFunctionCallItem(:final command):
        final call = _PendingCall(command);
        calls.putIfAbsent(command.id, () => <_PendingCall>[]).add(call);
        callOrder.add(call);
      case AskAiFunctionOutputItem(:final callId, :final output):
        final matching = calls[callId];
        if (matching == null) continue;
        _PendingCall? call;
        for (final candidate in matching) {
          if (candidate.completed) continue;
          call = candidate;
          break;
        }
        if (call == null) continue;
        call.completed = true;
        final result = AgentToolExecutionResult.tryFromToolMessage(output);
        if (result != null) {
          entries.add(AgentToolResultEntry(call.command, result));
          continue;
        }
        // A terminal Agent's output. Tried second because its decoder accepts
        // anything carrying `stdout` or `stderr`, while the tool encoding
        // above is marked and rejects everything else — so this order is what
        // keeps a tool result from being read as a shell result.
        final shell = AskAiCommandResult.tryFromToolMessage(
          output,
          fallbackCommand: call.command.command,
        );
        if (shell != null) {
          entries.add(AgentShellResultEntry(call.command, shell));
          continue;
        }
        switch (decodeAgentConversationToolAction(output)) {
          case AgentConversationToolAction.declined:
            entries.add(const AgentNoticeEntry(AgentNoticeKind.declined));
          case AgentConversationToolAction.inserted:
            entries.add(const AgentNoticeEntry(AgentNoticeKind.inserted));
          case null:
            if (output.trim().isNotEmpty) {
              entries.add(AgentRawNoticeEntry(output));
            }
        }
      case AskAiReasoningItem() || AskAiRawResponseItem():
        break;
    }
  }

  AskAiCommand? pending;
  for (final call in callOrder.reversed) {
    if (call.completed) continue;
    pending = call.command;
    break;
  }
  return (entries: List.unmodifiable(entries), pending: pending);
}

/// The turn ended with neither text nor a tool call.
///
/// A type rather than a message for the same reason [AgentSessionState.error]
/// holds the thrown object: the sentence belongs to the view.
@immutable
class AgentNoResponse implements Exception {
  const AgentNoResponse();
}

class _PendingCall {
  _PendingCall(this.command);

  final AskAiCommand command;
  bool completed = false;
}

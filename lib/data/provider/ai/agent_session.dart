import 'dart:async';

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
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
enum AgentNoticeKind { declined, interrupted }

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

/// The app-wide Agent conversation, and everything it is doing right now.
///
/// Lives here rather than in the page's `State` because it has more than one
/// view: the Agent tab and the floating shell show the same conversation, and
/// a turn started in one has to keep streaming while the other is on screen —
/// or while neither is. Nothing about a widget's lifetime should end a turn;
/// only the user stopping it, through [stopWork].
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

  GlobalAgentToolService get _tools => ref.read(globalAgentToolServiceProvider);

  @override
  AgentSessionState build() {
    // Watches the box, so a write this class did not make — a restored backup
    // — is not missed.
    _conversationWatch = Stores.agentConversation.box.watch().listen((_) {
      state = state.copyWith(conversations: _fetchConversations());
    });
    ref.onDispose(() {
      _conversationWatch?.cancel();
      _subscription?.cancel();
    });

    return _stateFor(
      Stores.agentConversation.fetchActive(globalAgentConversationScope),
    );
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
    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          terminalContext: '',
          serverName: 'ServerBox',
          localeHint: _localeHint,
          conversation: List.unmodifiable(state.history),
          protocol: state.protocol,
          customInstructions: _tools.buildInstructions(localeHint: _localeHint),
          tools: globalAgentToolDefinitions,
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
    AgentToolExecutionResult result;
    try {
      result = await _tools.execute(proposal);
    } catch (error) {
      result = AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: proposal.serverId,
        summary: 'The tool failed to run.',
        succeeded: false,
        duration: Duration.zero,
        localFailure: true,
        data: {'error': error.toString()},
      );
    }
    state = state.copyWith(
      history: [
        ...state.history,
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: result.toToolMessage(),
        ),
      ],
      timeline: [
        ...state.timeline,
        AgentToolResultEntry(proposal, result, autoApproved: autoApproved),
      ],
      pendingTool: null,
      pendingToolRestored: false,
      isExecuting: false,
    );
    await _persist();
    if (!result.cancelled) startStream();
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

  Future<void> stopWork() async {
    if (state.isExecuting) {
      await _tools.cancelCurrent();
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
      await Stores.agentConversation.create(
        serverId: globalAgentConversationScope,
        protocol: _configuredProtocol(),
        providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
        model: Stores.setting.askAiModel.fetch(),
      ),
    );
  }

  Future<void> activateConversation(AgentConversation conversation) async {
    if (state.isWorking ||
        conversation.serverId != globalAgentConversationScope) {
      return;
    }
    if (!await Stores.agentConversation.setActive(
      globalAgentConversationScope,
      conversation.id,
    )) {
      return;
    }
    restoreConversation(conversation);
  }

  Future<bool> renameConversation(String id, String title) async {
    if (!await Stores.agentConversation.rename(id, title)) return false;
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
    await Stores.agentConversation.deleteConversation(
      globalAgentConversationScope,
      id,
    );
    if (deletingCurrent) {
      restoreConversation(
        Stores.agentConversation.fetchActive(globalAgentConversationScope),
      );
    } else {
      state = state.copyWith(conversations: _fetchConversations());
    }
  }

  Future<void> clearConversationHistory() async {
    if (state.isWorking) return;
    await Stores.agentConversation.clearServer(globalAgentConversationScope);
    restoreConversation(null);
  }

  // --------------------------------------------------------------- internals

  AgentSessionState _stateFor(AgentConversation? conversation) {
    final replay = replayGlobalAgentTimeline(
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
    final created = await Stores.agentConversation.create(
      serverId: globalAgentConversationScope,
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
    if (!await Stores.agentConversation.save(updated)) return;
    state = state.copyWith(
      conversations: _fetchConversations(),
      conversation: Stores.agentConversation.fetch(updated.id) ?? updated,
      history: trimmed.length != state.history.length ? List.of(trimmed) : null,
    );
  }

  List<AgentConversation> _fetchConversations() =>
      Stores.agentConversation.fetchForServer(globalAgentConversationScope);

  AskAiProtocol _configuredProtocol() => AskAiRepository.resolveProtocol(
    configured: parseAskAiProtocol(Stores.setting.askAiProtocol.fetch()),
    endpoint: Stores.setting.askAiBaseUrl.fetch(),
  );
}

/// Rebuilds a timeline from a stored conversation, and finds the tool call —
/// if any — that was proposed but never answered.
///
/// The counterpart of `AgentConversationReplay.fromItems`, for the app-wide
/// Agent: the same protocol, but tool results are [AgentToolExecutionResult]
/// rather than a shell command's output, because these tools are not all
/// shells.
///
/// Entries carry data, never sentences. Nothing here knows what language the
/// app is in, and a conversation reopened after the user changed it should
/// read in the new one.
({List<AgentTimelineEntry> entries, AskAiCommand? pending})
replayGlobalAgentTimeline(List<AskAiConversationItem> items) {
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
        if (decodeAgentConversationToolAction(output) ==
            AgentConversationToolAction.declined) {
          entries.add(const AgentNoticeEntry(AgentNoticeKind.declined));
        } else if (output.trim().isNotEmpty) {
          entries.add(AgentRawNoticeEntry(output));
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

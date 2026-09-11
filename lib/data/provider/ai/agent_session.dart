import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/agent_conversation_replay.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/ai/model_context.dart';
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

  /// The turns above this were summarised, and the model is now sent the
  /// summary instead of them. They are still on the page.
  compacted,
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
    this.pendingTools = const [],
    this.pendingIndex = 0,
    this.pendingToolRestored = false,
    this.streamingContent,
    this.error,
    this.isStreaming = false,
    this.isExecuting = false,
    this.turnCompleted = false,
    this.autoRunCount = 0,
    this.promptTokens,
  });

  final AskAiProtocol protocol;
  final List<AgentTimelineEntry> timeline;
  final List<AskAiConversationItem> history;

  /// Every stored conversation in this scope, read from the box rather than
  /// re-read on every build: each fetch deserialises every conversation's full
  /// item list, and the column that shows them rebuilds once per keystroke.
  final List<AgentConversation> conversations;

  final AgentConversation? conversation;

  /// Every call this turn produced that has not been answered yet, in the
  /// order the model made them.
  ///
  /// A list because a turn can carry several: `parallel_tool_calls: false`
  /// asks for one and most providers honour it, but the ones that do not used
  /// to have everything past the first thrown away. They are reviewed one at a
  /// time — approving one moves to the next, declining answers all of them —
  /// and the model hears back only once every call has an answer.
  final List<AskAiCommand> pendingTools;

  /// Which of [pendingTools] is on screen. Answered calls leave the list, so
  /// an index that stays put is already looking at the next one.
  final int pendingIndex;

  /// The call being reviewed, or null when there is nothing to review.
  AskAiCommand? get pendingTool =>
      pendingIndex >= 0 && pendingIndex < pendingTools.length
      ? pendingTools[pendingIndex]
      : null;

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

  /// What the last request cost, as the provider counted it, or null where it
  /// said nothing. Not persisted: it describes the request that was just made,
  /// and a conversation reopened tomorrow will make a different one.
  final int? promptTokens;

  bool get isWorking => isStreaming || isExecuting;

  /// A complete tool proposal can be reviewed even when a compatible API
  /// leaves its SSE response open after sending the function-call arguments.
  bool get canReviewPendingTool => pendingTool != null && !isExecuting;

  bool get isEmpty => timeline.isEmpty && !isStreaming && pendingTool == null;

  AgentSessionState copyWith({
    AskAiProtocol? protocol,
    List<AgentTimelineEntry>? timeline,
    List<AskAiConversationItem>? history,
    List<AgentConversation>? conversations,
    Object? conversation = _unset,
    List<AskAiCommand>? pendingTools,
    int? pendingIndex,
    bool? pendingToolRestored,
    Object? streamingContent = _unset,
    Object? error = _unset,
    bool? isStreaming,
    bool? isExecuting,
    bool? turnCompleted,
    int? autoRunCount,
    Object? promptTokens = _unset,
  }) {
    return AgentSessionState(
      protocol: protocol ?? this.protocol,
      timeline: timeline ?? this.timeline,
      history: history ?? this.history,
      conversations: conversations ?? this.conversations,
      conversation: identical(conversation, _unset)
          ? this.conversation
          : conversation as AgentConversation?,
      pendingTools: pendingTools ?? this.pendingTools,
      pendingIndex: pendingIndex ?? this.pendingIndex,
      pendingToolRestored: pendingToolRestored ?? this.pendingToolRestored,
      streamingContent: identical(streamingContent, _unset)
          ? this.streamingContent
          : streamingContent as String?,
      error: identical(error, _unset) ? this.error : error,
      isStreaming: isStreaming ?? this.isStreaming,
      isExecuting: isExecuting ?? this.isExecuting,
      turnCompleted: turnCompleted ?? this.turnCompleted,
      autoRunCount: autoRunCount ?? this.autoRunCount,
      // Explicitly nullable: a turn whose provider reported no usage has to
      // clear the last one's, or the next compaction decides on a number that
      // describes a request nobody made.
      promptTokens: identical(promptTokens, _unset)
          ? this.promptTokens
          : promptTokens as int?,
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

  /// One summary at a time. Two turns finishing close together would otherwise
  /// each summarise the same prefix and insert two summaries of it.
  bool _compacting = false;

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
      // That one was sent, and whether it opened the conversation or continued
      // one. Never the text: a prompt here can quote terminal output and file
      // contents, which is the reason this crumb carries no data about it at
      // all — not a length, not a word count.
      Diag.crumb(
        SbDiag.agent,
        'prompt',
        data: {'first': state.history.isEmpty ? 'yes' : 'no'},
      );
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
              pendingTools: const [],
              pendingIndex: 0,
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
      // Queued, not replaced. A turn that carries several arrives as several
      // of these, and taking only the first is what used to throw the rest
      // away — leaving their ids in the assistant message with nothing
      // answering them, which invalidates the *next* request (#1463).
      if (state.pendingTools.any((call) => call.id == event.command.id)) return;
      state = state.copyWith(
        pendingTools: [...state.pendingTools, event.command],
        pendingToolRestored: false,
      );
      return;
    }
    if (event is AskAiStreamError) {
      _subscription?.cancel();
      _subscription = null;
      state = state.copyWith(
        error: event.error,
        isStreaming: false,
        streamingContent: null,
        pendingTools: const [],
        pendingIndex: 0,
      );
      return;
    }
    if (event is! AskAiCompleted || state.turnCompleted) return;

    final text = event.fullText.trim().isNotEmpty
        ? event.fullText
        : (state.streamingContent ?? '');
    // All of them, in the order the model made them. A turn that carries
    // several is reviewed one at a time and answered in full — the ids in the
    // assistant message and the `tool` messages have to match, or the *next*
    // request is the one the API rejects (#1463).
    final pending = event.commands.isEmpty
        ? state.pendingTools
        : List<AskAiCommand>.unmodifiable(event.commands);
    final command = pending.isEmpty ? null : pending.first;

    state = state.copyWith(
      turnCompleted: true,
      isStreaming: false,
      streamingContent: null,
      pendingTools: pending,
      pendingIndex: 0,
      pendingToolRestored: false,
      protocol: event.protocol,
      promptTokens: event.promptTokens,
      history: [...state.history, ...event.outputItems],
      timeline: text.trim().isNotEmpty
          ? [...state.timeline, AgentAssistantEntry(text)]
          : null,
      error: text.trim().isEmpty && command == null
          ? const AgentNoResponse()
          : null,
    );
    await _persist();
    // After the turn is stored, so a summary that fails costs nothing, and
    // unawaited, so it never stands between the user and the next turn.
    unawaited(_compactIfNeeded());

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
    if (proposal == null || !await _preparePendingTool(proposal)) return;

    state = state.copyWith(
      isExecuting: true,
      error: null,
      autoRunCount: autoApproved ? state.autoRunCount + 1 : null,
    );
    // The tool's name, which comes from a fixed set the model chooses from,
    // and whether the user was asked. Never `proposal.command`, which is a
    // command against the user's own server.
    //
    // `auto` is the number worth having: it is how often the agent acts
    // without being confirmed, which is the setting people are most wary of
    // and the one nothing currently says anything about.
    Diag.crumb(
      SbDiag.agent,
      'tool',
      data: {
        'tool': proposal.toolName,
        'auto': autoApproved ? 'yes' : 'no',
      },
    );

    final host = _host;
    AgentRunResult run;
    try {
      run = await host.execute(proposal);
    } catch (error) {
      run = host.describeFailure(proposal, error);
    }
    Diag.crumb(
      SbDiag.agent,
      run.cancelled ? 'tool cancelled' : 'tool done',
      data: {'tool': proposal.toolName},
    );
    final remaining = [
      for (final call in state.pendingTools)
        if (call.id != proposal.id) call,
    ];
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
      pendingTools: remaining,
      // The list closed up under it, so the same index is already the next
      // call — which is what "approve and move on" means.
      pendingIndex: remaining.isEmpty
          ? 0
          : state.pendingIndex.clamp(0, remaining.length - 1),
      pendingToolRestored: false,
      isExecuting: false,
    );
    await _persist();
    if (run.cancelled) return;
    // Back to the model only once every call in the turn has an answer.
    // Handing it a turn with one outstanding is the invalid request this
    // exists to prevent.
    if (remaining.isEmpty) {
      startStream();
      return;
    }
    _autoRunNextIfAllowed();
  }

  /// Carries an auto-run through the rest of a batch.
  ///
  /// Deferred for the same reason the first one is: this can be reached from
  /// inside the stream listener, and starting a run there re-enters it.
  void _autoRunNextIfAllowed() {
    final next = state.pendingTool;
    if (next == null) return;
    if (!shouldAutoRunAgentCommand(
      command: next,
      enabled: Stores.setting.askAiAutoRunSafeCommands.fetch(),
      restored: state.pendingToolRestored,
      runCount: state.autoRunCount,
    )) {
      return;
    }
    scheduleMicrotask(() {
      if (identical(state.pendingTool, next)) {
        unawaited(runPendingTool(autoApproved: true));
      }
    });
  }

  /// Replaces the turns that no longer fit in a request with a summary of
  /// them.
  ///
  /// The summary is *inserted*, never a replacement: the items it stands for
  /// stay in storage and on the page, and only a request leaves them out. The
  /// conversation a user scrolls back through is the one that happened.
  ///
  /// Failure is silent on purpose. A model that is unreachable, out of quota
  /// or refusing this particular transcript leaves the conversation exactly as
  /// it was — which still works, having only the window it had before. Telling
  /// the user their conversation failed to compress would be reporting an
  /// internal step they never asked for.
  Future<void> _compactIfNeeded() async {
    if (_compacting || state.isWorking) return;
    final history = state.history;
    final settings = Stores.setting;
    if (!AskAiRepository.shouldCompact(
      history,
      promptTokens: state.promptTokens,
      contextTokens: ModelContextTable.contextFor(
        settings.askAiModel.fetch(),
        override: settings.askAi.fetch().contextOverrideFor(
          settings.askAiBaseUrl.fetch(),
          settings.askAiModel.fetch(),
        ),
      ),
      percent: settings.askAiCompactAtPercent.fetch(),
    )) {
      return;
    }

    _compacting = true;
    try {
      final window = AskAiRepository.conversationWindow(history);
      // Where the kept part begins, which is past the previous summary when
      // there is one. Taking the window's item count instead counted the
      // already-summarised prefix again: the new summary landed *before* the
      // old one, so the old one stayed the newest, and every turn from then on
      // summarised the same history and inserted another copy.
      final keptFrom = window.keptFrom;
      if (window.droppedSinceSummary <= 0 || keptFrom <= 0) return;
      final covered = history.sublist(0, keptFrom);

      final summary = await ref
          .read(askAiRepositoryProvider)
          .summarise(items: covered, localeHint: _localeHint);
      if (summary.isEmpty) return;

      // Against the history as it is *now*: a turn may have been added while
      // the summariser was working, and appending to a stale copy would drop
      // it. The prefix is append-only, so what was covered is still the head.
      final current = state.history;
      if (current.length < keptFrom) return;
      state = state.copyWith(
        history: [
          ...current.sublist(0, keptFrom),
          AskAiSummaryItem(summary: summary, coveredItems: keptFrom),
          ...current.sublist(keptFrom),
        ],
        timeline: [...state.timeline, const AgentNoticeEntry(AgentNoticeKind.compacted)],
      );
      await _persist();
      Diag.crumb(SbDiag.agent, 'compacted', data: {'items': '$keptFrom'});
    } catch (_) {
      // See above: the conversation is unchanged and still usable.
    } finally {
      _compacting = false;
    }
  }

  /// Declines the whole batch, not the one on screen.
  ///
  /// Declining is an answer to "should the Agent do this", and the batch is
  /// one proposal made in several parts. Answering only the call in front of
  /// the user would leave the rest waiting with nothing to say what happened
  /// to the others, and would hand the model a turn it cannot act on. One
  /// notice for the same reason: the user said no once.
  Future<void> declinePendingTool() async {
    final pending = state.pendingTools;
    final proposal = state.pendingTool;
    if (proposal == null || !await _preparePendingTool(proposal)) return;
    state = state.copyWith(
      history: [
        ...state.history,
        for (final call in pending)
          AskAiFunctionOutputItem(
            callId: call.id,
            output: encodeAgentConversationToolAction(
              AgentConversationToolAction.declined,
            ),
          ),
      ],
      timeline: [
        ...state.timeline,
        const AgentNoticeEntry(AgentNoticeKind.declined),
      ],
      pendingTools: const [],
      pendingIndex: 0,
      pendingToolRestored: false,
    );
    await _persist();
    startStream();
  }

  /// Asks again from an earlier message, with whatever the user typed.
  ///
  /// [ordinal] is which of the user's own messages to go back to, counted from
  /// the start — the same count in the timeline and in the history, since both
  /// only ever grow at the end.
  ///
  /// Everything after it is discarded: the replies, the calls and their
  /// results. It has to be. What follows a message is an answer *to* that
  /// message, and keeping it beside a different question would be a
  /// conversation that never happened. The dialog says so before this runs.
  ///
  /// False when there is nothing to go back to or a turn is already running.
  Future<bool> resendFrom(int ordinal, String text) async {
    if (state.isWorking) return false;
    final prompt = text.trim();
    if (prompt.isEmpty) return false;

    final historyCut = _nthUserMessage(state.history, ordinal);
    if (historyCut < 0) return false;
    final timelineCut = _nthUserEntry(state.timeline, ordinal);

    state = state.copyWith(
      history: state.history.sublist(0, historyCut),
      timeline: timelineCut < 0
          ? state.timeline
          : state.timeline.sublist(0, timelineCut),
      // The batch belonged to the turn that is being replaced. Leaving it
      // would put calls on screen that answer a question no longer asked.
      pendingTools: const [],
      pendingIndex: 0,
      pendingToolRestored: false,
      streamingContent: null,
      error: null,
    );
    await _persist();
    return submitPrompt(prompt);
  }

  /// Drops a message and everything that answered it, without asking again.
  ///
  /// The same cut [resendFrom] makes, and for the same reason — a reply cannot
  /// outlive the question — with no new turn at the end. Removing a message
  /// and keeping what it produced would leave the model reading answers to a
  /// question it can no longer see.
  Future<bool> deleteFrom(int ordinal) async {
    if (state.isWorking) return false;
    final historyCut = _nthUserMessage(state.history, ordinal);
    if (historyCut < 0) return false;
    final timelineCut = _nthUserEntry(state.timeline, ordinal);

    state = state.copyWith(
      history: state.history.sublist(0, historyCut),
      timeline: timelineCut < 0
          ? state.timeline
          : state.timeline.sublist(0, timelineCut),
      pendingTools: const [],
      pendingIndex: 0,
      pendingToolRestored: false,
      streamingContent: null,
      error: null,
    );
    await _persist();
    return true;
  }

  static int _nthUserMessage(List<AskAiConversationItem> items, int ordinal) {
    var seen = 0;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item is! AskAiMessageItem) continue;
      if (item.role != AskAiMessageRole.user) continue;
      if (seen == ordinal) return index;
      seen++;
    }
    return -1;
  }

  static int _nthUserEntry(List<AgentTimelineEntry> entries, int ordinal) {
    var seen = 0;
    for (var index = 0; index < entries.length; index++) {
      if (entries[index] is! AgentUserEntry) continue;
      if (seen == ordinal) return index;
      seen++;
    }
    return -1;
  }

  /// Shows another call of the same batch. Out-of-range is ignored rather than
  /// clamped: a page view settling on a stale index should do nothing.
  void showPendingTool(int index) {
    if (index < 0 || index >= state.pendingTools.length) return;
    if (index == state.pendingIndex) return;
    state = state.copyWith(pendingIndex: index);
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
    if (proposal == null || state.isExecuting) return false;
    if (!_host.insert(proposal.command)) return false;
    if (!await _preparePendingTool(proposal)) return false;
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
      // Only this one. A terminal has one input line, and the rest of the
      // batch is still unanswered — leaving it waiting is what lets the user
      // put one command on the line and decide about the others.
      pendingTools: [
        for (final call in state.pendingTools)
          if (call.id != proposal.id) call,
      ],
      pendingIndex: state.pendingIndex.clamp(
        0,
        state.pendingTools.length - 2 < 0 ? 0 : state.pendingTools.length - 2,
      ),
      pendingToolRestored: false,
    );
    await _persist();
    return true;
  }

  /// Makes an already complete proposal actionable when the provider has not
  /// closed its SSE response yet.
  ///
  /// Tool suggestions are only emitted after their arguments parse into a
  /// complete [AskAiCommand]. Some OpenAI-compatible providers then keep the
  /// stream open instead of sending the final completion event. Waiting for
  /// that event left every review action disabled until the app restarted.
  /// Stopping at the complete proposal preserves the assistant text and the
  /// function call that the missing completion would have stored.
  Future<bool> _preparePendingTool(AskAiCommand proposal) async {
    if (!identical(state.pendingTool, proposal) || state.isExecuting) {
      return false;
    }
    if (!state.isStreaming) return true;

    final text = (state.streamingContent ?? '').trim();
    final subscription = _subscription;
    _subscription = null;
    state = state.copyWith(
      turnCompleted: true,
      isStreaming: false,
      streamingContent: null,
      history: [
        ...state.history,
        if (text.isNotEmpty) AskAiMessageItem.assistant(text),
        // Every call of the batch, not only the one being acted on: an id
        // answered later with no call recorded here is an orphan the API
        // rejects.
        for (final call in state.pendingTools)
          AskAiFunctionCallItem(command: call),
      ],
      timeline: text.isNotEmpty
          ? [...state.timeline, AgentAssistantEntry(text)]
          : null,
      error: null,
    );
    await subscription?.cancel();
    await _persist();
    return identical(state.pendingTool, proposal) && !state.isExecuting;
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
      pendingTools: const [],
      pendingIndex: 0,
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
      pendingTools: replay.pending,
      pendingToolRestored: replay.pending.isNotEmpty,
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
({List<AgentTimelineEntry> entries, List<AskAiCommand> pending})
replayAgentTimeline(
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
      // Shown rather than skipped. Everything above it is still on the page,
      // and without a line here the reader has no way to know that the model
      // is no longer being sent it.
      case AskAiSummaryItem():
        entries.add(const AgentNoticeEntry(AgentNoticeKind.compacted));
      case AskAiReasoningItem() || AskAiRawResponseItem():
        break;
    }
  }

  // Every call still waiting for an answer, in the order they were made — a
  // turn can carry several, and reopening a conversation has to bring back all
  // of them or the ones it forgot become orphans on the next request.
  final pending = [
    for (final call in callOrder)
      if (!call.completed) call.command,
  ];
  return (entries: List.unmodifiable(entries), pending: List.unmodifiable(pending));
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

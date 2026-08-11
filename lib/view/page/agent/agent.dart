import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/view/page/ssh/agent_conversation_replay.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

enum _AgentTimelineEntryType { user, assistant, toolResult, notice }

class _AgentTimelineEntry {
  const _AgentTimelineEntry._({
    required this.type,
    this.content,
    this.proposal,
    this.result,
    this.autoApproved = false,
  });

  const _AgentTimelineEntry.user(String content)
    : this._(type: _AgentTimelineEntryType.user, content: content);

  const _AgentTimelineEntry.assistant(String content)
    : this._(type: _AgentTimelineEntryType.assistant, content: content);

  const _AgentTimelineEntry.toolResult(
    AskAiCommand proposal,
    AgentToolExecutionResult result, {
    bool autoApproved = false,
  }) : this._(
         type: _AgentTimelineEntryType.toolResult,
         proposal: proposal,
         result: result,
         autoApproved: autoApproved,
       );

  const _AgentTimelineEntry.notice(String content)
    : this._(type: _AgentTimelineEntryType.notice, content: content);

  final _AgentTimelineEntryType type;
  final String? content;
  final AskAiCommand? proposal;
  final AgentToolExecutionResult? result;
  final bool autoApproved;
}

class _ReplayToolCall {
  _ReplayToolCall(this.proposal);

  final AskAiCommand proposal;
  bool completed = false;
}

@visibleForTesting
String formatGlobalAgentToolResultOutput(
  AgentToolExecutionResult result, {
  required String cancelledLabel,
  required String timedOutLabel,
  required String noOutputLabel,
  required String truncatedLabel,
}) {
  if (result.toolName != 'run_shell_command' || result.data is! Map) {
    return result.displayData;
  }

  final data = Map<Object?, Object?>.from(result.data! as Map);
  final stdout = data['stdout'] as String? ?? '';
  final stderr = data['stderr'] as String? ?? '';
  final exitCode = data['exit_code'];
  final timedOut = data['timed_out'] == true;
  final sections = <String>[];

  final status = <String>[
    if (timedOut) timedOutLabel else if (result.cancelled) cancelledLabel,
    if (exitCode != null) 'Exit code: $exitCode',
  ];
  if (status.isNotEmpty) sections.add(status.join(' · '));
  if (stdout.isNotEmpty) sections.add('stdout\n$stdout');
  if (stderr.isNotEmpty) sections.add('stderr\n$stderr');
  if (stdout.isEmpty && stderr.isEmpty) sections.add(noOutputLabel);
  if (result.truncated) sections.add(truncatedLabel);
  return sections.join('\n\n');
}

class _AgentPageState extends ConsumerState<AgentPage>
    with AutomaticKeepAliveClientMixin {
  final _timeline = <_AgentTimelineEntry>[];
  final _history = <AskAiConversationItem>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  StreamSubscription<AskAiEvent>? _subscription;
  AgentConversation? _conversation;
  AskAiCommand? _pendingTool;
  String? _streamingContent;
  String? _error;
  late AskAiProtocol _protocol;
  bool _isStreaming = false;
  bool _isExecuting = false;
  bool _turnCompleted = false;
  bool _historyInitialized = false;
  bool _pendingToolRestored = false;
  int _autoRunCount = 0;
  late final GlobalAgentToolService _toolService;

  bool get _isWorking => _isStreaming || _isExecuting;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _toolService = ref.read(globalAgentToolServiceProvider);
    _protocol = _resolvedConfiguredProtocol();
    _inputController.addListener(_handleInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_historyInitialized) return;
    _historyInitialized = true;
    _restoreConversation(
      Stores.agentConversation.fetchActive(globalAgentConversationScope),
      notify: false,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_isExecuting) {
      unawaited(_toolService.cancelCurrent());
    }
    _scrollController.dispose();
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  AskAiProtocol _resolvedConfiguredProtocol() {
    return AskAiRepository.resolveProtocol(
      configured: parseAskAiProtocol(Stores.setting.askAiProtocol.fetch()),
      endpoint: Stores.setting.askAiBaseUrl.fetch(),
    );
  }

  void _restoreConversation(
    AgentConversation? conversation, {
    bool notify = true,
  }) {
    final entries = <_AgentTimelineEntry>[];
    final calls = <String, List<_ReplayToolCall>>{};
    final callOrder = <_ReplayToolCall>[];
    for (final item in conversation?.items ?? const <AskAiConversationItem>[]) {
      switch (item) {
        case AskAiMessageItem(:final role, :final content):
          if (content.trim().isEmpty) continue;
          entries.add(
            role == AskAiMessageRole.user
                ? _AgentTimelineEntry.user(content)
                : _AgentTimelineEntry.assistant(content),
          );
        case AskAiFunctionCallItem(:final command):
          final call = _ReplayToolCall(command);
          calls.putIfAbsent(command.id, () => <_ReplayToolCall>[]).add(call);
          callOrder.add(call);
        case AskAiFunctionOutputItem(:final callId, :final output):
          final matching = calls[callId];
          if (matching == null) continue;
          final call = matching.where((item) => !item.completed).firstOrNull;
          if (call == null) continue;
          call.completed = true;
          final result = AgentToolExecutionResult.tryFromToolMessage(output);
          if (result != null) {
            entries.add(_AgentTimelineEntry.toolResult(call.proposal, result));
            continue;
          }
          final action = _toolAction(output);
          if (action == AgentConversationToolAction.declined) {
            entries.add(
              _AgentTimelineEntry.notice(context.l10n.askAiActionDeclined),
            );
          } else if (output.trim().isNotEmpty) {
            entries.add(_AgentTimelineEntry.notice(output));
          }
        case AskAiReasoningItem() || AskAiRawResponseItem():
          break;
      }
    }

    AskAiCommand? pending;
    for (final call in callOrder.reversed) {
      if (!call.completed) {
        pending = call.proposal;
        break;
      }
    }

    void apply() {
      _subscription?.cancel();
      _conversation = conversation;
      _protocol =
          conversation?.protocol == null ||
              conversation?.protocol == AskAiProtocol.auto
          ? _resolvedConfiguredProtocol()
          : conversation!.protocol;
      _history
        ..clear()
        ..addAll(conversation?.items ?? const []);
      _timeline
        ..clear()
        ..addAll(entries);
      _pendingTool = pending;
      _pendingToolRestored = pending != null;
      _streamingContent = null;
      _error = null;
      _isStreaming = false;
      _isExecuting = false;
      _turnCompleted = false;
      _autoRunCount = 0;
      _inputController.clear();
    }

    if (notify) {
      setState(apply);
      _scheduleAutoScroll(force: true);
    } else {
      apply();
    }
  }

  AgentConversationToolAction? _toolAction(String output) {
    try {
      final value = jsonDecode(output);
      if (value is! Map) return null;
      final action = value['server_box_action'];
      return AgentConversationToolAction.values.firstWhere(
        (item) => item.name == action,
      );
    } catch (_) {
      return null;
    }
  }

  AgentConversation _ensureConversation() {
    final existing = _conversation;
    if (existing != null) return existing;
    final created = Stores.agentConversation.create(
      serverId: globalAgentConversationScope,
      protocol: _protocol,
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
    );
    _conversation = created;
    return created;
  }

  void _persistConversation() {
    final conversation = _ensureConversation();
    final trimmed = AgentConversationStore.trimItemsForStorage(_history);
    final updated = conversation.copyWith(
      updatedAt: DateTime.now(),
      protocol: _protocol,
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
      items: trimmed,
    );
    if (!Stores.agentConversation.save(updated)) return;
    _conversation = Stores.agentConversation.fetch(updated.id) ?? updated;
    if (trimmed.length != _history.length) {
      _history
        ..clear()
        ..addAll(trimmed);
    }
  }

  void _submitPrompt(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty || _isWorking || _pendingTool != null) return;
    _ensureConversation();
    setState(() {
      _history.add(AskAiMessageItem.user(text));
      _timeline.add(_AgentTimelineEntry.user(text));
      _inputController.clear();
      _autoRunCount = 0;
      _error = null;
    });
    _persistConversation();
    _startStream();
    _scheduleAutoScroll(force: true);
  }

  void _startStream() {
    _subscription?.cancel();
    final localeHint = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    setState(() {
      _isStreaming = true;
      _turnCompleted = false;
      _error = null;
      _streamingContent = '';
    });
    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          terminalContext: '',
          serverName: 'ServerBox',
          localeHint: localeHint,
          conversation: List.unmodifiable(_history),
          protocol: _protocol,
          customInstructions: _toolService.buildInstructions(
            localeHint: localeHint,
          ),
          tools: globalAgentToolDefinitions,
        )
        .listen(
          _handleEvent,
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _error = _describeError(error);
              _isStreaming = false;
              _streamingContent = null;
              _pendingTool = null;
            });
          },
          onDone: () {
            if (!mounted || _turnCompleted) return;
            setState(() {
              _isStreaming = false;
              _streamingContent = null;
            });
          },
        );
  }

  void _handleEvent(AskAiEvent event) {
    if (!mounted) return;
    if (event is AskAiContentDelta) {
      setState(() {
        _streamingContent = (_streamingContent ?? '') + event.delta;
      });
      _scheduleAutoScroll();
      return;
    }
    if (event is AskAiToolSuggestion) {
      setState(() {
        _pendingTool ??= event.command;
        _pendingToolRestored = false;
      });
      _scheduleAutoScroll(force: true);
      return;
    }
    if (event is AskAiStreamError) {
      _subscription?.cancel();
      setState(() {
        _error = _describeError(event.error);
        _isStreaming = false;
        _streamingContent = null;
        _pendingTool = null;
      });
      return;
    }
    if (event is! AskAiCompleted || _turnCompleted) return;

    final text = event.fullText.trim().isNotEmpty
        ? event.fullText
        : (_streamingContent ?? '');
    final command = event.commands.isEmpty
        ? _pendingTool
        : event.commands.first;
    setState(() {
      _turnCompleted = true;
      _isStreaming = false;
      _streamingContent = null;
      _pendingTool = command;
      _pendingToolRestored = false;
      _protocol = event.protocol;
      _history.addAll(event.outputItems);
      if (text.trim().isNotEmpty) {
        _timeline.add(_AgentTimelineEntry.assistant(text));
      }
      if (text.trim().isEmpty && command == null) {
        _error = context.l10n.askAiNoResponse;
      }
    });
    _persistConversation();
    _scheduleAutoScroll(force: true);

    if (command != null &&
        shouldAutoRunAgentCommand(
          command: command,
          enabled: Stores.setting.askAiAutoRunSafeCommands.fetch(),
          restored: _pendingToolRestored,
          runCount: _autoRunCount,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_pendingTool, command)) {
          _runPendingTool(autoApproved: true);
        }
      });
    }
  }

  Future<void> _runPendingTool({bool autoApproved = false}) async {
    final proposal = _pendingTool;
    if (proposal == null || _isWorking) return;
    if (!autoApproved && proposal.risk == AskAiCommandRisk.destructive) {
      final confirmed = await context.showRoundDialog<bool>(
        title: context.l10n.askAiHighRiskConfirmTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.askAiHighRiskConfirmBody),
            const SizedBox(height: 12),
            SelectableText(
              proposal.displayValue,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actionsBuilder: (dialogContext) => [
          Btn.cancel(),
          Btn.text(text: libL10n.run, onTap: () => dialogContext.pop(true)),
        ],
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isExecuting = true;
      _error = null;
      if (autoApproved) _autoRunCount++;
    });
    AgentToolExecutionResult result;
    try {
      result = await _toolService.execute(proposal);
    } catch (error) {
      if (!mounted) return;
      result = AgentToolExecutionResult(
        toolName: proposal.toolName,
        serverId: proposal.serverId,
        summary: context.l10n.agentToolFailed,
        succeeded: false,
        duration: Duration.zero,
        data: {'error': _describeError(error)},
      );
    }
    if (!mounted) return;
    setState(() {
      _history.add(
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: result.toToolMessage(),
        ),
      );
      _timeline.add(
        _AgentTimelineEntry.toolResult(
          proposal,
          result,
          autoApproved: autoApproved,
        ),
      );
      _pendingTool = null;
      _pendingToolRestored = false;
      _isExecuting = false;
    });
    _persistConversation();
    _scheduleAutoScroll(force: true);
    if (!result.cancelled) _startStream();
  }

  void _declinePendingTool() {
    final proposal = _pendingTool;
    if (proposal == null || _isWorking) return;
    setState(() {
      _history.add(
        AskAiFunctionOutputItem(
          callId: proposal.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
      );
      _timeline.add(
        _AgentTimelineEntry.notice(context.l10n.askAiActionDeclined),
      );
      _pendingTool = null;
      _pendingToolRestored = false;
    });
    _persistConversation();
    _startStream();
  }

  Future<void> _stopWork() async {
    if (_isExecuting) {
      await _toolService.cancelCurrent();
      return;
    }
    if (!_isStreaming) return;
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _isStreaming = false;
      _streamingContent = null;
      _pendingTool = null;
      _pendingToolRestored = false;
      _timeline.add(_AgentTimelineEntry.notice(context.l10n.askAiInterrupted));
    });
  }

  void _scheduleAutoScroll({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!force && position.pixels < position.maxScrollExtent - 96) return;
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _describeError(Object error) {
    final l10n = context.l10n;
    if (error is AskAiConfigException) {
      if (error.missingFields.isEmpty) {
        return error.hasInvalidBaseUrl
            ? '${l10n.invalidUrl}: ${error.invalidBaseUrl}'
            : error.toString();
      }
      final fields = error.missingFields
          .map(
            (field) => switch (field) {
              AskAiConfigField.baseUrl => l10n.askAiBaseUrl,
              AskAiConfigField.apiKey => l10n.askAiApiKey,
              AskAiConfigField.model => libL10n.askAiModel,
            },
          )
          .join(', ');
      return l10n.askAiConfigMissing(fields);
    }
    if (error is AskAiNetworkException) return error.message;
    return error.toString();
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.showSnackBar(libL10n.success);
  }

  Future<void> _beginNewConversation() async {
    if (_isWorking) return;
    final conversation = Stores.agentConversation.create(
      serverId: globalAgentConversationScope,
      protocol: _resolvedConfiguredProtocol(),
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
    );
    _restoreConversation(conversation);
  }

  Future<void> _activateConversation(AgentConversation conversation) async {
    if (_isWorking || conversation.serverId != globalAgentConversationScope) {
      return;
    }
    if (!Stores.agentConversation.setActive(
      globalAgentConversationScope,
      conversation.id,
    )) {
      return;
    }
    _restoreConversation(conversation);
  }

  Future<void> _renameConversation(
    AgentConversation conversation, {
    VoidCallback? onChanged,
  }) async {
    final controller = TextEditingController(text: conversation.title)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: conversation.title.length,
      );
    try {
      final title = await context.showRoundDialog<String>(
        title: context.l10n.askAiRenameConversation,
        childBuilder: (dialogContext) => TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => dialogContext.pop(value.trim()),
        ),
        actionsBuilder: (dialogContext) => [
          Btn.text(text: libL10n.cancel),
          Btn.text(
            text: libL10n.ok,
            onTap: () => dialogContext.pop(controller.text.trim()),
          ),
        ],
      );
      if (title == null || title.isEmpty || !mounted) return;
      if (!Stores.agentConversation.rename(conversation.id, title)) return;
      setState(() {
        if (_conversation?.id == conversation.id) {
          _conversation = Stores.agentConversation.fetch(conversation.id);
        }
      });
      onChanged?.call();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteConversation(
    AgentConversation conversation, {
    VoidCallback? onChanged,
  }) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.askAiDeleteConversationTitle,
      child: Text(context.l10n.askAiDeleteConversationTip),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: libL10n.delete,
          textStyle: UIs.textRed,
          onTap: () => dialogContext.pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final deletingCurrent = _conversation?.id == conversation.id;
    Stores.agentConversation.deleteConversation(
      globalAgentConversationScope,
      conversation.id,
    );
    if (deletingCurrent) {
      _restoreConversation(
        Stores.agentConversation.fetchActive(globalAgentConversationScope),
      );
    } else {
      setState(() {});
    }
    onChanged?.call();
  }

  Future<void> _clearConversationHistory({VoidCallback? onChanged}) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.agentClearHistoryTitle,
      child: Text(context.l10n.agentClearHistoryTip),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: context.l10n.askAiClearHistory,
          textStyle: UIs.textRed,
          onTap: () => dialogContext.pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    Stores.agentConversation.clearServer(globalAgentConversationScope);
    _restoreConversation(null);
    onChanged?.call();
  }

  Future<void> _showHistorySheet() async {
    if (_isWorking) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: 0.82,
          child: _buildHistoryPanel(
            sheetContext,
            closeOnSelect: true,
            onChanged: () {
              if (sheetContext.mounted) setSheetState(() {});
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(
    BuildContext context, {
    required bool closeOnSelect,
    VoidCallback? onChanged,
  }) {
    final theme = Theme.of(context);
    final conversations = Stores.agentConversation.fetchForServer(
      globalAgentConversationScope,
    );
    final activeId = Stores.agentConversation.activeConversationId(
      globalAgentConversationScope,
    );
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.askAiHistory,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (conversations.isNotEmpty)
                  IconButton(
                    tooltip: context.l10n.askAiClearHistory,
                    onPressed: _isWorking
                        ? null
                        : () => _clearConversationHistory(onChanged: onChanged),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                IconButton.filledTonal(
                  tooltip: context.l10n.askAiNewConversation,
                  onPressed: _isWorking
                      ? null
                      : () async {
                          await _beginNewConversation();
                          if (closeOnSelect && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: conversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.agentNoHistory,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final selected = conversation.id == activeId;
                      return Card(
                        elevation: 0,
                        color: selected
                            ? theme.colorScheme.secondaryContainer
                            : theme.colorScheme.surfaceContainerLow,
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            conversation.title.isEmpty
                                ? context.l10n.askAiUntitledConversation
                                : conversation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _conversationPreview(conversation),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: _isWorking
                              ? null
                              : () async {
                                  await _activateConversation(conversation);
                                  if (closeOnSelect && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          trailing: PopupMenuButton<_HistoryAction>(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _HistoryAction.rename,
                                child: Text(
                                  context.l10n.askAiRenameConversation,
                                ),
                              ),
                              PopupMenuItem(
                                value: _HistoryAction.delete,
                                child: Text(libL10n.delete),
                              ),
                            ],
                            onSelected: (action) async {
                              if (action == _HistoryAction.rename) {
                                await _renameConversation(
                                  conversation,
                                  onChanged: onChanged,
                                );
                              } else {
                                await _deleteConversation(
                                  conversation,
                                  onChanged: onChanged,
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              context.l10n.askAiHistoryLocalOnly,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _conversationPreview(AgentConversation conversation) {
    for (final item in conversation.items.reversed) {
      if (item is AskAiMessageItem && item.content.trim().isNotEmpty) {
        return item.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return context.l10n.askAiNoHistoryMessages;
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.onPrimaryContainer,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.agentTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (compact)
            IconButton(
              tooltip: context.l10n.askAiHistory,
              onPressed: _isWorking ? null : _showHistorySheet,
              icon: const Icon(Icons.history),
            ),
          IconButton(
            tooltip: context.l10n.askAiNewConversation,
            onPressed: _isWorking ? null : _beginNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          if (_isWorking)
            IconButton.filledTonal(
              tooltip: libL10n.stop,
              onPressed: _stopWork,
              icon: const Icon(Icons.stop),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.hub_outlined, size: 50, color: theme.colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            context.l10n.agentWelcome,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.agentWelcomeTip,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _toolChip(theme, Icons.terminal, context.l10n.agentToolShell),
              _toolChip(
                theme,
                Icons.description_outlined,
                context.l10n.agentToolReadFile,
              ),
              _toolChip(
                theme,
                Icons.edit_document,
                context.l10n.agentToolWriteFile,
              ),
              _toolChip(
                theme,
                Icons.dns_outlined,
                context.l10n.agentToolServerBox,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolChip(ThemeData theme, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    ThemeData theme,
    _AgentTimelineEntry entry,
  ) {
    switch (entry.type) {
      case _AgentTimelineEntryType.user:
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                entry.content ?? '',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        );
      case _AgentTimelineEntryType.assistant:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SimpleMarkdown(data: entry.content ?? ''),
        );
      case _AgentTimelineEntryType.notice:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.content ?? '')),
            ],
          ),
        );
      case _AgentTimelineEntryType.toolResult:
        return _buildToolResultCard(context, theme, entry);
    }
  }

  Widget _buildToolResultCard(
    BuildContext context,
    ThemeData theme,
    _AgentTimelineEntry entry,
  ) {
    final proposal = entry.proposal!;
    final result = entry.result!;
    final output = formatGlobalAgentToolResultOutput(
      result,
      cancelledLabel: context.l10n.askAiCommandCancelled,
      timedOutLabel: context.l10n.askAiCommandTimedOut,
      noOutputLabel: context.l10n.askAiNoCommandOutput,
      truncatedLabel: context.l10n.askAiOutputTruncated,
    );
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: result.succeeded
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          child: Icon(
            result.succeeded ? Icons.check : Icons.error_outline,
            size: 18,
            color: result.succeeded
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
        ),
        title: Text(
          result.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_toolLabel(context, proposal.toolName)} · ${result.duration.inMilliseconds} ms${entry.autoApproved ? ' · ${context.l10n.askAiAutoApproved}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (output.isNotEmpty) ...[
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 320),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  output,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: output.isEmpty ? null : () => _copyText(output),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(libL10n.copy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalCard(BuildContext context, ThemeData theme) {
    final proposal = _pendingTool!;
    final arguments = proposal.arguments;
    final serverId = proposal.serverId;
    final serverName = serverId == null
        ? null
        : ref.watch(serversProvider).servers[serverId]?.name;
    final detail = switch (proposal.toolName) {
      'run_shell_command' => arguments['command'] as String? ?? '',
      'read_file' || 'write_file' => arguments['path'] as String? ?? '',
      'serverbox' => arguments['action'] as String? ?? '',
      _ => proposal.displayValue,
    };
    final content = arguments['content'];
    final risk = _riskInfo(context, proposal.risk);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_toolIcon(proposal.toolName), size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _toolLabel(context, proposal.toolName),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(risk.icon, size: 15, color: risk.color),
                  label: Text(risk.label),
                  side: BorderSide(color: risk.color.withValues(alpha: 0.45)),
                  backgroundColor: risk.color.withValues(alpha: 0.09),
                ),
              ],
            ),
            if (serverId != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${serverName ?? serverId} · $serverId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (proposal.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(proposal.description),
            ],
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: proposal.toolName == 'run_shell_command'
                        ? 'monospace'
                        : null,
                  ),
                ),
              ),
            ],
            if (content is String) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
            if (_pendingToolRestored) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.askAiRestoredReview,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isWorking ? null : _declinePendingTool,
                  child: Text(context.l10n.askAiDecline),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isWorking ? null : _runPendingTool,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(context.l10n.askAiApproveRun),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({String label, IconData icon, Color color}) _riskInfo(
    BuildContext context,
    AskAiCommandRisk risk,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (risk) {
      AskAiCommandRisk.readOnly => (
        label: context.l10n.askAiRiskReadOnly,
        icon: Icons.visibility_outlined,
        color: scheme.primary,
      ),
      AskAiCommandRisk.caution => (
        label: context.l10n.askAiRiskCaution,
        icon: Icons.warning_amber_rounded,
        color: scheme.tertiary,
      ),
      AskAiCommandRisk.destructive => (
        label: context.l10n.askAiRiskDestructive,
        icon: Icons.dangerous_outlined,
        color: scheme.error,
      ),
    };
  }

  String _toolLabel(BuildContext context, String toolName) {
    return switch (toolName) {
      'run_shell_command' => context.l10n.agentToolShell,
      'read_file' => context.l10n.agentToolReadFile,
      'write_file' => context.l10n.agentToolWriteFile,
      'serverbox' => context.l10n.agentToolServerBox,
      _ => toolName,
    };
  }

  IconData _toolIcon(String toolName) {
    return switch (toolName) {
      'run_shell_command' => Icons.terminal,
      'read_file' => Icons.description_outlined,
      'write_file' => Icons.edit_document,
      'serverbox' => Icons.dns_outlined,
      _ => Icons.build_outlined,
    };
  }

  Widget _buildComposer(BuildContext context, ThemeData theme) {
    final canSend =
        !_isWorking &&
        _pendingTool == null &&
        _inputController.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isWorking ? null : _startStream,
                        child: Text(libL10n.retry),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.center,
                        enabled: !_isWorking && _pendingTool == null,
                        decoration: InputDecoration(
                          hintText: _pendingTool == null
                              ? context.l10n.agentPromptHint
                              : context.l10n.askAiReviewBeforeContinuing,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            15,
                            12,
                            8,
                            12,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7),
                      child: IconButton.filled(
                        tooltip: context.l10n.askAiAgentSend,
                        onPressed: canSend
                            ? () => _submitPrompt(_inputController.text)
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.askAiDisclaimer,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context, ThemeData theme, bool compact) {
    final visibleTimeline = <Widget>[
      if (_timeline.isEmpty && !_isStreaming && _pendingTool == null)
        _buildEmptyState(context, theme),
      for (final entry in _timeline) ...[
        _buildTimelineEntry(context, theme, entry),
        const SizedBox(height: 14),
      ],
      if (_isStreaming) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _streamingContent?.trim().isNotEmpty == true
                  ? SimpleMarkdown(data: _streamingContent!)
                  : Text(context.l10n.askAiAwaitingResponse),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (_pendingTool != null) _buildProposalCard(context, theme),
    ];

    return Column(
      children: [
        _buildHeader(context, theme, compact),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 24,
                20,
                compact ? 12 : 24,
                24,
              ),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: visibleTimeline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Align(
          alignment: Alignment.center,
          child: _buildComposer(context, theme),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Material(
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              if (wide) ...[
                SizedBox(
                  width: 280,
                  child: _buildHistoryPanel(context, closeOnSelect: false),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ],
              Expanded(child: _buildMain(context, theme, !wide)),
            ],
          ),
        );
      },
    );
  }
}

enum _HistoryAction { rename, delete }

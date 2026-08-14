import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/pane_settings.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

@visibleForTesting
String formatGlobalAgentToolResultOutput(
  AgentToolExecutionResult result, {
  required String cancelledLabel,
  required String timedOutLabel,
  required String noOutputLabel,
  required String truncatedLabel,
}) {
  // Above the tool name, because `{'error': ...}` is what every tool that
  // threw produces, not only the shell's. Read inside the shell branch, a
  // failed read_file printed the raw JSON of that map, and a failed shell
  // command printed "the command produced no output" — which is what a
  // command that never ran looks like from here, and says nothing about why.
  if (result.data case final Map data?) {
    final error = data['error'];
    if (error is String && error.isNotEmpty) return error;
  }

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

/// The conversation lives in [agentSessionProvider]; this page draws it.
///
/// Kept alive not for the conversation — that now outlives every widget — but
/// for the scroll position and whatever is half-typed in the composer, which
/// belong to this view and would be thrown away on a tab switch otherwise.
class _AgentPageState extends ConsumerState<AgentPage>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  AgentSession get _notifier => ref.read(agentSessionProvider.notifier);

  String? get _localeHint =>
      Localizations.maybeLocaleOf(context)?.toLanguageTag();

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ actions

  /// Enter sends and Shift+Enter breaks the line, or the other way round with
  /// the modifier doing the sending — the two habits people bring to a chat
  /// box, and the setting that picks between them.
  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final withModifier = keys.isMetaPressed || keys.isControlPressed;
    final sends = Stores.setting.askAiSendOnEnter.fetch()
        ? !keys.isShiftPressed
        : withModifier;
    if (!sends) return KeyEventResult.ignored;

    // Mid-composition a bare Enter belongs to the IME, which is using it to
    // accept a candidate; taking it would send half a word in every language
    // that needs one to type at all. Only a bare one: no IME commits on
    // Cmd/Ctrl+Enter, and Android keeps the word being typed in a composing
    // range at all times, so guarding the modifier form too swallowed the
    // send shortcut for the whole of a sentence.
    if (withModifier) return _sendAndConsume();
    if (!_inputController.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    return _sendAndConsume();
  }

  KeyEventResult _sendAndConsume() {
    _submitPrompt(_inputController.text);
    // Handled either way: the key meant "send", and letting it through would
    // leave a line break behind whenever there was nothing to send.
    return KeyEventResult.handled;
  }

  void _submitPrompt(String prompt) {
    // Emptied only once the session has taken it. It refuses while a turn is
    // running or a tool is waiting to be reviewed, and a box cleared anyway
    // would lose what was typed.
    if (_notifier.submitPrompt(prompt, localeHint: _localeHint)) {
      _inputController.clear();
    }
  }

  /// Reviews the proposal, then hands it to the session to run.
  ///
  /// The confirmation is a dialog and so has to be raised from a widget; the
  /// session has no context to put one on, and auto-running never reaches here
  /// because nothing that needs asking is eligible for it.
  Future<void> _runPendingTool(AskAiCommand proposal) async {
    if (proposal.risk == AskAiCommandRisk.destructive) {
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
    await _notifier.runPendingTool();
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.showSnackBar(libL10n.success);
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
      if (!_notifier.renameConversation(conversation.id, title)) return;
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
    // Whether this is still allowed is re-checked inside the session, not only
    // when the row was built: an auto-approved tool can start while the
    // confirmation is on screen.
    _notifier.deleteConversation(conversation.id);
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
    _notifier.clearConversationHistory();
    onChanged?.call();
  }

  Future<void> _showHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: 0.82,
          child: Consumer(
            builder: (sheetContext, ref, _) => _buildHistoryPanel(
              sheetContext,
              ref.watch(agentSessionProvider),
              inSheet: true,
              onChanged: () {
                if (sheetContext.mounted) setSheetState(() {});
              },
            ),
          ),
        ),
      ),
    );
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

  // -------------------------------------------------------------------- utils

  String _describeError(BuildContext context, Object error) {
    final l10n = context.l10n;
    if (error is AgentNoResponse) return l10n.askAiNoResponse;
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

  String _noticeText(BuildContext context, AgentNoticeKind kind) {
    return switch (kind) {
      AgentNoticeKind.declined => context.l10n.askAiActionDeclined,
      AgentNoticeKind.interrupted => context.l10n.askAiInterrupted,
    };
  }

  String _conversationPreview(AgentConversation conversation) {
    for (final item in conversation.items.reversed) {
      if (item is AskAiMessageItem && item.content.trim().isNotEmpty) {
        return item.content.replaceAll(_whitespace, ' ').trim();
      }
    }
    return context.l10n.askAiNoHistoryMessages;
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

  // -------------------------------------------------------------------- build

  /// The conversation list, as a sheet you opened or as the column that is
  /// always beside the page.
  ///
  /// [inSheet] is the difference between the two: a sheet is done once you have
  /// picked something from it, so picking closes it. The column stays.
  Widget _buildHistoryPanel(
    BuildContext context,
    AgentSessionState session, {
    required bool inSheet,
    VoidCallback? onChanged,
  }) {
    final theme = Theme.of(context);
    final conversations = session.conversations;
    final activeId = session.conversation?.id;
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
                    onPressed: session.isWorking
                        ? null
                        : () => _clearConversationHistory(onChanged: onChanged),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                IconButton.filledTonal(
                  tooltip: context.l10n.askAiNewConversation,
                  onPressed: session.isWorking
                      ? null
                      : () {
                          _notifier.beginNewConversation();
                          if (inSheet && context.mounted) {
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
                          // Default is 16 either side. In a column this narrow
                          // that is the width the title wants, and it was what
                          // held the menu button away from the edge.
                          contentPadding: const EdgeInsets.only(
                            left: 12,
                            right: 4,
                          ),
                          title: Text(
                            conversation.title.isEmpty
                                ? context.l10n.askAiUntitledConversation
                                : conversation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _conversationPreview(conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: session.isWorking
                              ? null
                              : () {
                                  _notifier.activateConversation(conversation);
                                  if (inSheet && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                          // The row's own tap is already refused while a
                          // tool is running. Renaming is harmless, but
                          // deleting the conversation being worked in clears
                          // the timeline the execution is about to append its
                          // output to — and the execution keeps going, since
                          // nothing but the stop button ends one.
                          trailing: PopupMenu<_HistoryAction>(
                            enabled: !session.isWorking,
                            items: [
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
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
    bool compact,
  ) {
    return Padding(
      // Symmetric where the row ends with the title, so its ellipsis sits
      // the same distance from the edge as the content below it. The
      // narrower right side is for the buttons the compact layout keeps.
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 10, compact ? 8 : 20, 10),
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
          // Both only while the history is a sheet away. Beside its own column
          // they would be a second copy of the two buttons already at the top
          // of it.
          if (compact) ...[
            IconButton(
              tooltip: context.l10n.askAiHistory,
              onPressed: session.isWorking ? null : _showHistorySheet,
              icon: const Icon(Icons.history),
            ),
            IconButton(
              tooltip: context.l10n.askAiNewConversation,
              onPressed: session.isWorking
                  ? null
                  : _notifier.beginNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
          if (session.isWorking)
            IconButton.filledTonal(
              tooltip: libL10n.stop,
              onPressed: _notifier.stopWork,
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
      side: BorderSide(color: Hairline.color(context)),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    ThemeData theme,
    AgentTimelineEntry entry,
  ) {
    return switch (entry) {
      AgentUserEntry(:final content) => Align(
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
              content,
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
        ),
      ),
      AgentAssistantEntry(:final content) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SimpleMarkdown(data: content),
      ),
      AgentNoticeEntry(:final kind) => _buildNotice(
        context,
        theme,
        _noticeText(context, kind),
      ),
      AgentRawNoticeEntry(:final text) => _buildNotice(context, theme, text),
      AgentToolResultEntry() => _buildToolResultCard(context, theme, entry),
    };
  }

  Widget _buildNotice(BuildContext context, ThemeData theme, String text) {
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
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildToolResultCard(
    BuildContext context,
    ThemeData theme,
    AgentToolResultEntry entry,
  ) {
    final result = entry.result;
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
        side: BorderSide(color: Hairline.color(context)),
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
        // A result's own summary is English on purpose — the model reads it.
        // A tool that never ran has nothing else to show, so the app says so
        // in its own words rather than passing that sentence on.
        title: Text(
          result.localFailure ? context.l10n.agentToolFailed : result.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_toolLabel(context, entry.proposal.toolName)} · ${result.duration.inMilliseconds} ms${entry.autoApproved ? ' · ${context.l10n.askAiAutoApproved}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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

  Widget _buildProposalCard(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    final proposal = session.pendingTool!;
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
        side: BorderSide(color: Hairline.color(context)),
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
            if (session.pendingToolRestored) ...[
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
                  onPressed: session.isWorking
                      ? null
                      : _notifier.declinePendingTool,
                  child: Text(context.l10n.askAiDecline),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: session.isWorking
                      ? null
                      : () => _runPendingTool(proposal),
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

  Widget _buildComposer(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    // Everything but the text is session state, so only the send button has to
    // follow the keystrokes — see the builder around it. Rebuilding the page
    // for each one redrew the timeline's markdown and every history row.
    final canSendWhatever = !session.isWorking && session.pendingTool == null;
    final error = session.error;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null) ...[
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
                          _describeError(context, error),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: session.isWorking
                            ? null
                            : () => _notifier.startStream(
                                localeHint: _localeHint,
                              ),
                        child: Text(libL10n.retry),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Listened to, not read: the setting is changed on another page,
              // and nothing here would bring this one back to ask again.
              Stores.setting.askAiSendOnEnter.listenable().listenVal((
                sendOnEnter,
              ) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    // The same line as the rule directly above it.
                    border: Border.all(color: Hairline.color(context)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        // Above the field rather than on it: the key has to be
                        // answered before the platform's text input sees it, or
                        // the newline is in the box by the time we decide it was
                        // a send.
                        child: Focus(
                          canRequestFocus: false,
                          onKeyEvent: _handleComposerKey,
                          child: TextField(
                            controller: _inputController,
                            minLines: 1,
                            maxLines: 6,
                            // What a soft keyboard's return key does, on the
                            // devices that have one of those instead of a Shift.
                            // The setting is about a hardware keyboard, where
                            // Shift+Enter is the other half of it. A soft one
                            // has no Shift, so a return key that sends leaves
                            // no way to type a line break at all — and the
                            // send button is right beside the field anyway.
                            textInputAction: sendOnEnter && isDesktop
                                ? TextInputAction.send
                                : TextInputAction.newline,
                            onSubmitted: sendOnEnter && isDesktop
                                ? _submitPrompt
                                : null,
                            enabled: canSendWhatever,
                            decoration: InputDecoration(
                              hintText: session.pendingTool == null
                                  ? context.l10n.agentPromptHint
                                  : context.l10n.askAiReviewBeforeContinuing,
                              border: InputBorder.none,
                              // Not for density — the padding below is
                              // unchanged — but because a field that is not
                              // dense is also never shorter than 48px, and
                              // `InputDecorator` both centres the text in that
                              // floor *and* applies `textAlignVertical` to what
                              // is left over. The two together pushed the line
                              // below the middle of the box. Dense, the field is
                              // its padding plus its text, and the row centres
                              // the whole of it against the send button.
                              isDense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                15,
                                12,
                                8,
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(7),
                        child: ValueListenableBuilder(
                          valueListenable: _inputController,
                          builder: (_, value, _) => IconButton.filled(
                            tooltip: context.l10n.askAiAgentSend,
                            onPressed:
                                canSendWhatever && value.text.trim().isNotEmpty
                                ? () => _submitPrompt(_inputController.text)
                                : null,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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

  Widget _buildMain(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
    bool compact,
  ) {
    final visibleTimeline = <Widget>[
      if (session.isEmpty) _buildEmptyState(context, theme),
      for (final entry in session.timeline) ...[
        _buildTimelineEntry(context, theme, entry),
        const SizedBox(height: 14),
      ],
      if (session.isStreaming) ...[
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
              child: session.streamingContent?.trim().isNotEmpty == true
                  ? SimpleMarkdown(data: session.streamingContent!)
                  : Text(context.l10n.askAiAwaitingResponse),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (session.pendingTool != null)
        _buildProposalCard(context, theme, session),
    ];

    return Column(
      children: [
        _buildHeader(context, theme, session, compact),
        // The same seam as the one beside the history column, which these two
        // meet at a corner: at full strength they read as a brighter line than
        // it, which is the pane looking like a window of its own.
        Divider(
          height: Hairline.thickness,
          thickness: Hairline.thickness,
          color: Hairline.color(context),
        ),
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
        Divider(
          height: Hairline.thickness,
          thickness: Hairline.thickness,
          color: Hairline.color(context),
        ),
        Align(
          alignment: Alignment.center,
          child: _buildComposer(context, theme, session),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final session = ref.watch(agentSessionProvider);

    // Following the state rather than scrolling wherever this page last
    // appended something: the session moves on its own now, so a turn started
    // here keeps going while the page is off screen and comes back further
    // along than it was left.
    ref.listen(agentSessionProvider, (previous, next) {
      final settled =
          previous?.timeline.length != next.timeline.length ||
          previous?.pendingTool != next.pendingTool;
      if (settled || previous?.streamingContent != next.streamingContent) {
        _scheduleAutoScroll(force: settled);
      }
    });

    // The same judgement, width and seam as the server list and the terminal
    // tabs: whether a list gets a column of its own is a property of the
    // window, not of the page that happens to be in it.
    return Material(
      color: theme.colorScheme.surface,
      child: SbPaneList(
        // Nothing to sit beside until there is a conversation: the header
        // keeps its history and new-conversation buttons, so folding the
        // column away costs nothing and hands 320pt back to the answer.
        hasContent: session.conversations.isNotEmpty,
        sideBuilder: (ctx) => _buildHistoryPanel(ctx, session, inSheet: false),
        builder: (ctx, split) => _buildMain(ctx, theme, session, !split),
      ),
    );
  }
}

/// Built once. It was constructed per history row per rebuild.
final _whitespace = RegExp(r'\s+');

enum _HistoryAction { rename, delete }

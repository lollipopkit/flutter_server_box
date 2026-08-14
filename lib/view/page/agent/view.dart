import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/adhoc_ssh.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/ask_ai.dart';
import 'package:server_box/data/provider/ai/global_agent_tools.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/agent/history.dart';

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

/// The buttons that act on the conversation rather than on the window around
/// it. Shared by the tab's header and the floating shell's title bar, which
/// otherwise have nothing in common.
class AgentHeaderActions extends ConsumerWidget {
  const AgentHeaderActions({super.key, required this.showConversations});

  /// False beside the history column, where these would be a second copy of
  /// the two buttons already at the top of it.
  final bool showConversations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(agentSessionProvider);
    final notifier = ref.read(agentSessionProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showConversations) ...[
          IconButton(
            tooltip: context.l10n.askAiHistory,
            onPressed: session.isWorking
                ? null
                : () => showAgentHistorySheet(context),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: context.l10n.askAiNewConversation,
            onPressed: session.isWorking ? null : notifier.beginNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
        const _AdHocSessionsButton(),
      ],
    );
  }
}

/// How many hosts the Agent has open that are not configured servers.
///
/// Present only while there are any. They are invisible otherwise — no card,
/// no server row — and a connection the model opened and forgot about should
/// not be something only the model knows exists.
class _AdHocSessionsButton extends ConsumerWidget {
  const _AdHocSessionsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(adHocSshSessionsProvider);
    if (sessions.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.l10n.agentAdHocSessions,
      onPressed: () => _show(context),
      icon: Badge.count(
        count: sessions.length,
        child: const Icon(Icons.cable),
      ),
    );
  }

  void _show(BuildContext context) {
    context.showRoundDialog(
      title: context.l10n.agentAdHocSessions,
      child: Consumer(
        builder: (context, ref, _) {
          final sessions = ref.watch(adHocSshSessionsProvider).values.toList();
          if (sessions.isEmpty) return Text(libL10n.empty);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final session in sessions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cable, size: 20),
                  title: Text(session.label),
                  subtitle: Text(
                    session.id,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  trailing: IconButton(
                    tooltip: libL10n.close,
                    onPressed: () => ref
                        .read(adHocSshSessionsProvider.notifier)
                        .close(session.id),
                    icon: const Icon(Icons.link_off),
                  ),
                ),
            ],
          );
        },
      ),
      actions: [Btn.ok()],
    );
  }
}

/// The conversation: its timeline and the box you type into.
///
/// More than one of these can be on screen at once — the tab and the floating
/// shell — and they show the same [agentSessionProvider]. What belongs to each
/// separately is only what is being typed and where it is scrolled to.
class AgentConversationView extends ConsumerStatefulWidget {
  const AgentConversationView({
    super.key,
    required this.compact,
    this.showHeader = true,
    this.headerTrailing,
  });

  /// Too narrow for the conversation list to sit beside it, so the header
  /// carries the buttons that open it instead.
  final bool compact;

  /// False where the container draws its own bar — the floating shell, whose
  /// bar has to be the thing you drag it by.
  final bool showHeader;

  /// Goes after the conversation's own buttons. The tab puts the control that
  /// sends this conversation floating there; the shell, having no header,
  /// puts those controls on its title bar instead.
  final Widget? headerTrailing;

  @override
  ConsumerState<AgentConversationView> createState() =>
      _AgentConversationViewState();
}

class _AgentConversationViewState extends ConsumerState<AgentConversationView> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

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
    // A turn is running, so there is nothing to send yet. Let the key through
    // rather than eating it: the box stays usable while an answer streams, and
    // a keystroke that neither sends nor types anything simply disappears.
    if (ref.read(agentSessionProvider).isWorking) return KeyEventResult.ignored;
    _submitPrompt(_inputController.text);
    // Handled either way from here: the key meant "send", and letting it
    // through would leave a line break behind whenever there was nothing to
    // send.
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
            ? '${libL10n.invalidUrl}: ${error.invalidBaseUrl}'
            : error.toString();
      }
      final fields = error.missingFields
          .map(
            (field) => switch (field) {
              AskAiConfigField.baseUrl => libL10n.apiEndpoint,
              AskAiConfigField.apiKey => libL10n.apiKey,
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
      AskAiCommandRisk.unknown => (
        label: context.l10n.askAiRiskUnknown,
        icon: Icons.help_outline,
        color: scheme.tertiary,
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
      'ssh_connect' => context.l10n.agentToolSshConnect,
      'ssh_disconnect' => context.l10n.agentToolSshDisconnect,
      _ => toolName,
    };
  }

  IconData _toolIcon(String toolName) {
    return switch (toolName) {
      'run_shell_command' => Icons.terminal,
      'read_file' => Icons.description_outlined,
      'write_file' => Icons.edit_document,
      'serverbox' => Icons.dns_outlined,
      'ssh_connect' => Icons.cable,
      'ssh_disconnect' => Icons.link_off,
      _ => Icons.build_outlined,
    };
  }

  // -------------------------------------------------------------------- build

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final compact = widget.compact;
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
          AgentHeaderActions(showConversations: compact),
          ?widget.headerTrailing,
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

  /// The timeline as widgets, with each run of tool results folded into one.
  List<Widget> _buildTimeline(
    BuildContext context,
    ThemeData theme,
    List<AgentTimelineEntry> timeline,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < timeline.length; i++) {
      final entry = timeline[i];
      if (entry is AgentToolResultEntry) {
        final run = <AgentToolResultEntry>[entry];
        while (i + 1 < timeline.length &&
            timeline[i + 1] is AgentToolResultEntry) {
          run.add(timeline[++i] as AgentToolResultEntry);
        }
        widgets.add(
          run.length == 1
              ? _buildToolResultCard(context, theme, run.first)
              : _buildToolGroupCard(context, theme, run),
        );
      } else {
        widgets.add(_buildTimelineEntry(context, theme, entry));
      }
      widgets.add(const SizedBox(height: 14));
    }
    return widgets;
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

  /// The frame every tool row and every group of them shares.
  ///
  /// A finished tool is a log line, not a message: it collapses to one row so
  /// the answer it was gathered for stays on screen. The label and the
  /// duration sit beside the summary; anything longer is behind the expander.
  Widget _toolCard({
    required BuildContext context,
    required ThemeData theme,
    required bool succeeded,
    required String title,
    required String meta,
    required List<Widget> children,
    double metaMaxWidth = 170,
    EdgeInsets childrenPadding = const EdgeInsets.fromLTRB(12, 4, 12, 10),
    double indent = 12,
    bool framed = true,
  }) {
    final tile = ExpansionTile(
      shape: const RoundedRectangleBorder(),
      collapsedShape: const RoundedRectangleBorder(),
      minTileHeight: 40,
      tilePadding: EdgeInsets.only(left: indent, right: 12),
      visualDensity: VisualDensity.compact,
      childrenPadding: childrenPadding,
      title: Row(
        children: [
          Icon(
            succeeded ? Icons.check_circle : Icons.error,
            size: 17,
            color: succeeded
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metaMaxWidth),
            child: Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      children: children,
    );
    if (!framed) return tile;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Hairline.color(context)),
      ),
      child: tile,
    );
  }

  Widget _buildToolResultCard(
    BuildContext context,
    ThemeData theme,
    AgentToolResultEntry entry, {
    bool framed = true,
    double indent = 12,
  }) {
    final result = entry.result;
    final output = formatGlobalAgentToolResultOutput(
      result,
      cancelledLabel: libL10n.cancelled,
      timedOutLabel: libL10n.timedOut,
      noOutputLabel: context.l10n.askAiNoCommandOutput,
      truncatedLabel: context.l10n.askAiOutputTruncated,
    );
    return _toolCard(
      context: context,
      theme: theme,
      framed: framed,
      indent: indent,
      succeeded: result.succeeded,
      // A result's own summary is English on purpose — the model reads it.
      // A tool that never ran has nothing else to show, so the app says so
      // in its own words rather than passing that sentence on.
      title: result.localFailure
          ? context.l10n.agentToolFailed
          : result.summary,
      meta: [
        _toolLabel(context, entry.proposal.toolName),
        '${result.duration.inMilliseconds} ms',
        if (entry.autoApproved) context.l10n.askAiAutoApproved,
      ].join(' · '),
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
    );
  }

  /// One card for a run of tool calls with nothing said between them.
  ///
  /// Reading three files to answer one question is one step of that answer,
  /// and three cards for it pushed the answer itself off screen. The row names
  /// the tools the run used, in the order it used them; each call keeps its
  /// own row, and its own output, inside.
  Widget _buildToolGroupCard(
    BuildContext context,
    ThemeData theme,
    List<AgentToolResultEntry> entries,
  ) {
    final tally = <String, int>{};
    var totalMs = 0;
    var succeeded = true;
    for (final entry in entries) {
      final label = _toolLabel(context, entry.proposal.toolName);
      tally[label] = (tally[label] ?? 0) + 1;
      totalMs += entry.result.duration.inMilliseconds;
      succeeded &= entry.result.succeeded;
    }
    return _toolCard(
      context: context,
      theme: theme,
      succeeded: succeeded,
      title: tally.entries
          .map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key)
          .join(' · '),
      meta: '${context.l10n.agentToolCallsFmt(entries.length)} · $totalMs ms',
      metaMaxWidth: 210,
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final entry in entries) ...[
          Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          ),
          _buildToolResultCard(
            context,
            theme,
            entry,
            framed: false,
            indent: 22,
          ),
        ],
      ],
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
      // Its own summary: the host, user and port the connection would reach,
      // which is the whole of what there is to review.
      'ssh_connect' || 'ssh_disconnect' => proposal.displayValue,
      _ => proposal.displayValue,
    };
    final content = arguments['content'];
    final risk = _riskInfo(context, proposal.risk);
    // Named for why it is being reviewed, not for what `caution` usually
    // means: a read-only command on a host met this conversation is reviewed
    // because of the host, and a chip reading "changes system" over the
    // model's own "does not modify the system" is just wrong.
    final riskLabel = proposal.raisedByUnvettedHost
        ? context.l10n.askAiRiskUnvetted
        : risk.label;
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
                  label: Text(riskLabel),
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
    // follow the keystrokes — see the builder around it. Rebuilding the view
    // for each one redrew the timeline's markdown and every history row.
    //
    // Typing is only blocked by a tool waiting to be reviewed, which is a
    // question that has to be answered before anything else makes sense. A
    // running turn does not block it: composing the next thing to say while
    // the answer arrives is the normal way to use a chat box.
    final canType = session.pendingTool == null;
    final canSendWhatever = canType && !session.isWorking;
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
                            enabled: canType,
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
                        // One button, because they are the same question at
                        // two moments: while a turn is running the only thing
                        // to do to it is stop it, and a separate stop control
                        // elsewhere is one more place to look.
                        child: session.isWorking
                            ? IconButton.filled(
                                tooltip: libL10n.stop,
                                onPressed: _notifier.stopWork,
                                icon: const Icon(Icons.stop),
                              )
                            : ValueListenableBuilder(
                                valueListenable: _inputController,
                                builder: (_, value, _) => IconButton.filled(
                                  tooltip: context.l10n.askAiAgentSend,
                                  onPressed:
                                      canSendWhatever &&
                                          value.text.trim().isNotEmpty
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(agentSessionProvider);
    final compact = widget.compact;

    // Following the state rather than scrolling wherever this view last
    // appended something: the session moves on its own, so a turn started here
    // keeps going while the view is off screen and comes back further along
    // than it was left.
    ref.listen(agentSessionProvider, (previous, next) {
      final settled =
          previous?.timeline.length != next.timeline.length ||
          previous?.pendingTool != next.pendingTool;
      if (settled || previous?.streamingContent != next.streamingContent) {
        _scheduleAutoScroll(force: settled);
      }
    });

    final visibleTimeline = <Widget>[
      if (session.isEmpty) _buildEmptyState(context, theme),
      ..._buildTimeline(context, theme, session.timeline),
      if (session.isStreaming) ...[
        Builder(
          builder: (context) {
            // Answer text is many lines and starts at the top; the waiting
            // label is one line and belongs beside the spinner's middle.
            // Aligning both to the top left the label sitting visibly high.
            final streamed = session.streamingContent?.trim();
            final hasText = streamed?.isNotEmpty == true;
            return Row(
              crossAxisAlignment: hasText
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: hasText ? 4 : 0),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: hasText
                      ? SimpleMarkdown(data: session.streamingContent!)
                      : Text(context.l10n.askAiAwaitingResponse),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
      ],
      if (session.pendingTool != null)
        _buildProposalCard(context, theme, session),
    ];

    return Column(
      children: [
        if (widget.showHeader) ...[
          _buildHeader(context, theme),
          // The same seam as the one beside the history column, which these
          // two meet at a corner: at full strength they read as a brighter
          // line than it, which is the pane looking like a window of its own.
          Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          ),
        ],
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
}

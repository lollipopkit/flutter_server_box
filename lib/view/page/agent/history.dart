import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/view/widget/float_shell.dart';

/// Opens the conversation list as a sheet, for the layouts too narrow to give
/// it a column of its own.
Future<void> showAgentHistorySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: agentSheetAnimation,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.82,
      child: AgentHistoryPanel(inSheet: true),
    ),
  );
}

/// How the Agent's sheets arrive and leave.
///
/// Material's default for a modal sheet is one curve used in both directions,
/// which on the way out reads as the sheet being dropped. The rest of the
/// Agent's motion — the floating shell's reveal, its expand — is
/// `easeOutCubic` opening and `easeIn` closing, on the reasoning that opening
/// presents something and closing acknowledges it. These sheets are the same
/// gesture and had been the one thing not following it.
const agentSheetAnimation = AnimationStyle(
  curve: Curves.easeOutCubic,
  duration: Durations.medium2,
  reverseCurve: Curves.easeIn,
  reverseDuration: Durations.short4,
);

/// The conversation list, as a sheet you opened or as the column that is
/// always beside the page.
///
/// [inSheet] is the difference between the two: a sheet is done once you have
/// picked something from it, so picking closes it. The column stays.
class AgentHistoryPanel extends ConsumerStatefulWidget {
  const AgentHistoryPanel({super.key, required this.inSheet});

  final bool inSheet;

  @override
  ConsumerState<AgentHistoryPanel> createState() => _AgentHistoryPanelState();
}

class _AgentHistoryPanelState extends ConsumerState<AgentHistoryPanel> {
  AgentSession get _notifier => ref.read(globalAgentSessionProvider.notifier);

  // ------------------------------------------------------------------ actions

  void _closeIfSheet() {
    if (widget.inSheet && mounted) Navigator.pop(context);
  }

  Future<void> _rename(AgentConversation conversation) async {
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
      await _notifier.renameConversation(conversation.id, title);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _delete(AgentConversation conversation) async {
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
    // confirmation is on screen, and it would go on to append its result to
    // whichever conversation is active by then.
    await _notifier.deleteConversation(conversation.id);
  }

  Future<void> _clear() async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.agentClearHistoryTitle,
      child: Text(context.l10n.agentClearHistoryTip),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: libL10n.clearHistory,
          textStyle: UIs.textRed,
          onTap: () => dialogContext.pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _notifier.clearConversationHistory();
  }

  // -------------------------------------------------------------------- utils

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(globalAgentSessionProvider);
    final conversations = session.conversations;
    final activeId = session.conversation?.id;
    // The same rail as the terminal and file tabs: a right-aligned row of
    // actions, a heading with a rule running to the edge, and one line per
    // entry. It used to be a list of cards with a timestamp under each title —
    // its own vocabulary, in the one column of the app that had one.
    //
    // The timestamp went with the second line, which is [SideBarTile]'s own
    // trade-off: at two lines a row a rail stops being something you can take
    // in at a glance, and the conversation beside it says when it was.
    // Transparent rather than `colorScheme.surface`: in a column this rail
    // shows the `Scaffold`'s background like the terminal and file rails do,
    // and in a sheet it shows the sheet's. Both are slots `toAmoled`
    // overrides and `colorScheme.surface` is not, so painting that here left
    // the rail Material grey under an AMOLED theme while the page beside it
    // went black.
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (conversations.isNotEmpty) ...[
                  IconButton(
                    tooltip: libL10n.clearHistory,
                    onPressed: session.isWorking ? null : _clear,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: floatHeaderIconSize,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Plain, not `filledTonal`. A filled button beside a bare one
                // reads as the bigger of the two whatever their icons measure,
                // and this row is meant to be one weight — the rails on the
                // other tabs put their add button in it unfilled too.
                IconButton(
                  tooltip: context.l10n.askAiNewConversation,
                  onPressed: session.isWorking
                      ? null
                      : () async {
                          await _notifier.beginNewConversation();
                          _closeIfSheet();
                        },
                  icon: const Icon(Icons.add, size: floatHeaderIconSize),
                ),
              ],
            ),
          ),
          SideBarSection(context.l10n.askAiHistory),
          if (conversations.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Text(
                context.l10n.agentNoHistory,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final conversation in conversations)
              SideBarTile(
                title: conversation.title.isEmpty
                    ? context.l10n.askAiUntitledConversation
                    : conversation.title,
                selected: conversation.id == activeId,
                onTap: session.isWorking
                    ? null
                    : () async {
                        await _notifier.activateConversation(conversation);
                        _closeIfSheet();
                      },
                // The row's own tap is already refused while a tool is
                // running. Renaming is harmless, but deleting the conversation
                // being worked in clears the timeline the execution is about
                // to append its output to — and the execution keeps going,
                // since nothing but the stop button ends one.
                menuEnabled: !session.isWorking,
                onMenu: (at) => _showRowMenu(conversation, at),
              ),
        ],
      ),
    );
  }

  void _showRowMenu(AgentConversation conversation, Offset? at) {
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: context.l10n.askAiRenameConversation,
          icon: Icons.drive_file_rename_outline,
          onTap: () => _rename(conversation),
        ),
        ContextMenuAction(
          text: libL10n.delete,
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () => _delete(conversation),
        ),
      ],
      title: conversation.title.isEmpty
          ? context.l10n.askAiUntitledConversation
          : conversation.title,
      at: at,
    );
  }
}

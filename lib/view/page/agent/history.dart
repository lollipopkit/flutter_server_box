import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Chats, ChatMeta, LlmStores;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/view/page/agent/view.dart';

/// Opens [scope]'s chat list as a sheet, for the layouts too narrow to give it
/// a column of its own.
Future<void> showAgentHistorySheet(BuildContext context, {String? scope}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: agentSheetAnimation,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.82,
      child: AgentHistoryPanel(inSheet: true, scope: scope),
    ),
  );
}

/// How the Agent's sheets arrive and leave.
///
/// Material's default for a modal sheet is one curve used in both directions,
/// which on the way out reads as the sheet being dropped. The rest of the
/// Agent's motion — the floating shell's reveal, its expand — is
/// `easeOutCubic` opening and `easeIn` closing, on the reasoning that opening
/// presents something and closing acknowledges it.
const agentSheetAnimation = AnimationStyle(
  curve: Curves.easeOutCubic,
  duration: Durations.medium2,
  reverseCurve: Curves.easeIn,
  reverseDuration: Durations.short4,
);

/// [scope]'s chats, as a sheet you opened or as the column that is always
/// beside the page — see [AgentChats].
///
/// [inSheet] is the difference between the two: a sheet is done once you have
/// picked something from it, so picking closes it. The column stays.
class AgentHistoryPanel extends StatefulWidget {
  const AgentHistoryPanel({super.key, required this.inSheet, this.scope});

  final bool inSheet;
  final String? scope;

  @override
  State<AgentHistoryPanel> createState() => _AgentHistoryPanelState();
}

class _AgentHistoryPanelState extends State<AgentHistoryPanel> {
  /// The rail's search: what is typed, and whether the row is a field at all.
  final _search = InlineSearchController();

  /// The chats whose conversation mentions what was typed, as the search
  /// last answered; null while nothing is typed.
  Set<String>? _found;
  var _query = 0;

  String? get _scope => widget.scope;

  String _titleOf(ChatMeta chat) => switch (chat.title) {
    final t? when t.isNotEmpty => t,
    _ => context.l10n.askAiUntitledConversation,
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    super.dispose();
  }

  /// Asks the chats themselves, not only their titles: what a conversation was
  /// about is usually in it rather than in its name.
  Future<void> _searchChanged() async {
    final needle = _search.needle;
    final query = ++_query;
    if (needle.isEmpty) {
      setState(() => _found = null);
      return;
    }
    final hits = await Chats.search(needle, scope: _scope);
    if (!mounted || query != _query) return;
    setState(() => _found = {for (final m in hits) m.id});
  }

  // ------------------------------------------------------------------ actions

  void _closeIfSheet() {
    if (widget.inSheet && mounted) Navigator.pop(context);
  }

  Future<void> _rename(ChatMeta chat) async {
    final title = chat.title ?? '';
    final controller = TextEditingController(text: title)
      ..selection = TextSelection(baseOffset: 0, extentOffset: title.length);
    // Disposed with the field, not when the dialog answers. See [DisposeWith].
    final next = await context.showRoundDialog<String>(
      title: context.l10n.askAiRenameConversation,
      childBuilder: (dialogContext) => DisposeWith(
        notifiers: [controller],
        child: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => dialogContext.pop(value.trim()),
        ),
      ),
      actionsBuilder: (dialogContext) => [
        Btn.text(text: libL10n.cancel),
        Btn.text(
          text: libL10n.ok,
          onTap: () => dialogContext.pop(controller.text.trim()),
        ),
      ],
    );
    if (next == null || next.isEmpty || !mounted) return;
    Chats.rename(chat.id, next);
  }

  Future<void> _delete(ChatMeta chat) async {
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
    await AgentChats.delete(_scope, chat.id);
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
    for (final chat in LlmStores.chat.all(scope: _scope)) {
      await AgentChats.delete(_scope, chat.id);
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = AgentChats.of(_scope);
    // The same rail as the terminal and file tabs: a right-aligned row of
    // actions, a heading with a rule running to the edge, and one line per
    // entry. Transparent, so it shows the `Scaffold`'s background in a column
    // and the sheet's in a sheet — both slots an AMOLED theme overrides.
    return ListenableBuilder(
      listenable: Listenable.merge([
        LlmStores.chat.changes,
        current,
        _search,
        Chats.openChanges,
        Chats.runningChanges,
      ]),
      builder: (context, _) {
        final chats = LlmStores.chat.all(scope: _scope);
        final needle = _search.needle;
        final found = _found;
        final shown = [
          for (final chat in chats)
            if (needle.isEmpty ||
                _titleOf(chat).toLowerCase().contains(needle) ||
                (found?.contains(chat.id) ?? false))
              chat,
        ];
        final busy = AgentChats.busy(_scope);

        return Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              SideBarActions(
                search: _search,
                actions: [
                  if (chats.isNotEmpty)
                    Btn.icon(
                      text: libL10n.clearHistory,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      onTap: busy ? null : _clear,
                    ),
                  Btn.icon(
                    text: libL10n.search,
                    icon: const Icon(Icons.search, size: 18),
                    onTap: _search.start,
                  ),
                  Btn.icon(
                    text: context.l10n.askAiNewConversation,
                    icon: const Icon(Icons.add, size: 18),
                    onTap: () {
                      AgentChats.startNew(_scope);
                      _closeIfSheet();
                    },
                  ),
                ],
              ),
              SideBarSection(context.l10n.askAiHistory),
              // Two different nothings: no chats at all, and none that match
              // what was typed. The second says what was typed, since that is
              // the thing to change.
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Text(
                    needle.isEmpty ? context.l10n.agentNoHistory : needle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final chat in shown)
                  SideBarTile(
                    title: _titleOf(chat),
                    // A reply being written here, whichever chat is shown.
                    leading: switch (AgentActivity.of(chat.id)) {
                      AgentActivity.idle => null,
                      final activity => AgentActivityMark(activity, size: 13),
                    },
                    selected: chat.id == current.value,
                    onTap: () {
                      AgentChats.select(_scope, chat.id);
                      _closeIfSheet();
                    },
                    onMenu: (at) => _showRowMenu(chat, at),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _showRowMenu(ChatMeta chat, Offset? at) {
    // A chat writing a reply is not deleted from under it.
    final running = Chats.openOf(chat.id)?.running.value ?? false;
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: context.l10n.askAiRenameConversation,
          icon: Icons.drive_file_rename_outline,
          onTap: () => _rename(chat),
        ),
        if (!running)
          ContextMenuAction(
            text: libL10n.delete,
            icon: Icons.delete_outline,
            destructive: true,
            onTap: () => _delete(chat),
          ),
      ],
      title: _titleOf(chat),
      at: at,
    );
  }
}

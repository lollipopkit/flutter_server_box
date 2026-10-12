import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Chats, ChatMeta, LlmStores;
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/provider/ai/remote_agent.dart';
import 'package:server_box/view/page/agent/view.dart';
import 'package:server_box/view/page/setting/entry.dart';

/// Opens [scope]'s chat list as a sheet, for the layouts too narrow to give it
/// a column of its own.
Future<void> showAgentHistorySheet(BuildContext context, {String? scope}) {
  return showModalBottomSheet<void>(
    context: context,
    // From the foot of the screen, over the nav bar, as every other tab's
    // sheet is: the tab's own navigator stops above the bar.
    useRootNavigator: true,
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

  /// Per server, its tasks that match what was typed, as the agents last
  /// answered; null while nothing is typed or before they have.
  Map<String, List<MonitorAgentFlow>>? _remoteFound;

  /// The servers are being searched for what was typed.
  bool _searching = false;

  /// Rows the panel's list has held: one it had not arrives with a motion,
  /// unless it is part of what the panel opened with. Kept by what the list
  /// holds rather than what was drawn, so scrolling to a row is no arrival.
  final _known = <String>{};
  final _arriving = <String>{};
  bool _primed = false;
  var _query = 0;

  String? get _scope => widget.scope;

  /// Only the app-wide Agent lists the servers' tasks: a terminal's chats are
  /// about that terminal.
  bool get _withRemote => _scope == null;

  String _titleOf(ChatMeta chat) => switch (chat.title) {
    final t? when t.isNotEmpty => t,
    _ => context.l10n.askAiUntitledConversation,
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    if (_withRemote) RemoteAgentTasks.follow();
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    if (_withRemote) RemoteAgentTasks.unfollow();
    super.dispose();
  }

  /// Asks the chats themselves, not only their titles: what a conversation was
  /// about is usually in it rather than in its name.
  Future<void> _searchChanged() async {
    final needle = _search.needle;
    final query = ++_query;
    if (needle.isEmpty) {
      setState(() {
        _found = null;
        _remoteFound = null;
        _searching = false;
      });
      return;
    }
    if (_withRemote) setState(() => _searching = true);
    final (hits, remote) = await (
      Chats.search(needle, scope: _scope),
      _withRemote ? RemoteAgentTasks.search(needle) : Future.value(<String, List<MonitorAgentFlow>>{}),
    ).wait;
    if (!mounted || query != _query) return;
    setState(() {
      _found = {for (final m in hits) m.id};
      _remoteFound = remote;
      _searching = false;
    });
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

  Future<void> _deleteRemote(RemoteTaskRef ref, String title, String server) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.askAiDeleteConversationTitle,
      child: Text(context.l10n.agentDeleteRemoteTip(server)),
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
    try {
      await RemoteAgentTasks.client(ref.serverId)?.agentDelete(ref.flowId);
    } catch (e) {
      Toast.show('$e');
    }
  }

  Future<void> _stopRemote(RemoteTaskRef ref) async {
    try {
      await RemoteAgentTasks.client(ref.serverId)?.agentStop(ref.flowId);
    } catch (e) {
      Toast.show('$e');
    }
  }

  List<ContextMenuAction> _sources(List<({String id, String name})> servers) {
    final source = AgentHistorySource.shown.value;
    ContextMenuAction item(String text, String? value) => ContextMenuAction(
      text: text,
      icon: source == value ? Icons.check : null,
      onTap: () => AgentHistorySource.shown.value = value,
    );
    return [
      item(libL10n.all, null),
      item(context.l10n.agentThisDevice, AgentHistorySource.device),
      for (final s in servers) item(s.name, s.id),
    ];
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
        if (_withRemote) ...[
          RemoteAgentTasks.tasks,
          RemoteAgentTasks.more,
          RemoteAgentTasks.loading,
          RemoteAgentTasks.selected,
          AgentHistorySource.shown,
        ],
      ]),
      builder: (context, _) {
        final chats = LlmStores.chat.all(scope: _scope);
        final needle = _search.needle;
        final found = _found;
        final servers = _withRemote ? RemoteAgentTasks.servers() : const <({String id, String name})>[];
        // A server that left the list is no filter any more.
        final source = switch (AgentHistorySource.shown.value) {
          final id? when id != AgentHistorySource.device && !servers.any((s) => s.id == id) => null,
          final v => v,
        };
        final rows = <_Row>[
          if (source == null || source == AgentHistorySource.device)
            for (final chat in chats)
              if (needle.isEmpty ||
                  _titleOf(chat).toLowerCase().contains(needle) ||
                  (found?.contains(chat.id) ?? false))
                _LocalRow(chat),
          for (final server in servers)
            if (source == null || source == server.id)
              // Typed: what the agent found in all its tasks, once it has
              // answered; the pages read until then.
              for (final flow in switch (_remoteFound?[server.id]) {
                final found? when needle.isNotEmpty => found,
                _ => [
                  for (final f in RemoteAgentTasks.tasks.value[server.id] ?? const <MonitorAgentFlow>[])
                    if (needle.isEmpty || f.title.toLowerCase().contains(needle)) f,
                ],
              })
                _RemoteRow(server.id, server.name, flow),
        ]..sort((a, b) => b.at.compareTo(a.at));
        // A server with pages not read yet may have tasks between the rows
        // shown: nothing older than its oldest read is shown until they are.
        final unread = [
          if (needle.isEmpty)
            for (final server in servers)
              if ((source == null || source == server.id) && RemoteAgentTasks.more.value.containsKey(server.id))
                server.id,
        ];
        DateTime? horizon;
        for (final id in unread) {
          final oldest = RemoteAgentTasks.tasks.value[id]?.lastOrNull?.updatedAt;
          if (oldest != null && (horizon == null || oldest.isAfter(horizon))) horizon = oldest;
        }
        if (horizon != null) rows.removeWhere((r) => r.at.isBefore(horizon!));
        final busy = AgentChats.busy(_scope);

        final head = <Widget>[
              SideBarActions(
                search: _search,
                actions: [
                  if (chats.isNotEmpty)
                    BarAction(
                      icon: Icons.delete_sweep_outlined,
                      label: libL10n.clearHistory,
                      onTap: busy ? null : _clear,
                    ),
                  BarAction(
                    icon: Icons.search,
                    label: libL10n.search,
                    onTap: _search.start,
                  ),
                  if (servers.isNotEmpty)
                    BarAction.menu(
                      icon: source == null ? Icons.filter_alt_outlined : Icons.filter_alt,
                      label: context.l10n.agentSource,
                      color: source == null ? null : theme.colorScheme.primary,
                      menu: () => _sources(servers),
                    ),
                  BarAction(
                    icon: Icons.add,
                    label: context.l10n.askAiNewConversation,
                    onTap: () {
                      AgentChats.startNew(_scope);
                      _closeIfSheet();
                    },
                  ),
                  // Over the sheet rather than in place of it: back returns
                  // to the list it was opened from.
                  BarAction(
                    key: const ValueKey('agent-settings'),
                    icon: Icons.settings_outlined,
                    label: libL10n.setting,
                    onTap: () => SettingsSectionPage.route.go(
                      context,
                      SettingsSection.ai,
                      target: NavTarget.root,
                    ),
                  ),
                ],
              ),
              SideBarSection(context.l10n.askAiHistory),
              // A server's first page, or a search of them, on its way: the
              // rows it brings are not there yet.
              if (_searching ||
                  servers.any((s) => (source == null || source == s.id) && RemoteAgentTasks.loading.value.contains(s.id)))
                const Padding(
                  padding: EdgeInsets.fromLTRB(13, 0, 13, 7),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              // Two different nothings: no chats at all, and none that match
              // what was typed. The second says what was typed, since that is
              // the thing to change.
              if (rows.isEmpty && unread.isEmpty && RemoteAgentTasks.loading.value.isEmpty && !_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Text(
                    needle.isEmpty ? context.l10n.agentNoHistory : needle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ];
        final loader = unread.isNotEmpty;
        for (final row in rows) {
          if (_known.add(row.key) && _primed) _arriving.add(row.key);
        }
        // Only what arrives on screen moves: one below the fold is simply
        // there when it is scrolled to.
        if (_arriving.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _arriving.clear());
        // What the panel opened with is there: from now on a row is new.
        if (!_primed && rows.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _primed = true);
        }
        return Material(
          type: MaterialType.transparency,
          // Built as it scrolls: a server keeps hundreds of tasks.
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: head.length + rows.length + (loader ? 1 : 0),
            itemBuilder: (context, i) {
              if (i < head.length) return head[i];
              final r = i - head.length;
              if (r < rows.length) {
                final row = rows[r];
                return _Arrive(
                  key: ValueKey(row.key),
                  animate: _arriving.remove(row.key),
                  child: _tile(row, current.value, theme),
                );
              }
              // The end of what was read: read on.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final id in unread) {
                  unawaited(RemoteAgentTasks.loadMore(id));
                }
              });
              return const Padding(
                padding: EdgeInsets.all(13),
                child: Center(child: SizedLoading(20, padding: 2, builder: SizedLoading.circularBuilder)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _tile(_Row row, String? current, ThemeData theme) {
    return switch (row) {
      _LocalRow(:final chat) => SideBarTile(
        title: _titleOf(chat),
        // A reply being written here, whichever chat is shown.
        leading: switch (AgentActivity.of(chat.id)) {
          AgentActivity.idle => null,
          final activity => AgentActivityMark(activity, size: 13),
        },
        selected: RemoteAgentTasks.selected.value == null && chat.id == current,
        onTap: () {
          AgentChats.select(_scope, chat.id);
          _closeIfSheet();
        },
        onMenu: (at) => _showRowMenu(chat, at),
      ),
      _RemoteRow(:final serverId, :final server, :final flow) => SideBarTile(
        title: flow.title.isEmpty ? context.l10n.askAiUntitledConversation : flow.title,
        leading: switch (flow.status) {
          MonitorAgentStatus.waiting => const AgentActivityMark(AgentActivity.waiting, size: 13),
          MonitorAgentStatus.running || MonitorAgentStatus.queued =>
            const AgentActivityMark(AgentActivity.running, size: 13),
          _ => null,
        },
        // Where it lives: it runs there, not on this device.
        trailing: Text(
          server,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        selected: RemoteAgentTasks.selected.value == (serverId: serverId, flowId: flow.id),
        onTap: () {
          // Off this device's chat first: picking that clears a task.
          AgentChats.startNew(_scope);
          RemoteAgentTasks.select((serverId: serverId, flowId: flow.id));
          _closeIfSheet();
        },
        onMenu: (at) => _showRemoteMenu(serverId, server, flow, at),
      ),
    };
  }

  void _showRemoteMenu(String serverId, String server, MonitorAgentFlow flow, Offset? at) {
    final ref = (serverId: serverId, flowId: flow.id);
    showContextMenu(
      context,
      [
        if (flow.status.active)
          ContextMenuAction(text: libL10n.stop, icon: Icons.stop_circle_outlined, onTap: () => _stopRemote(ref))
        else
          ContextMenuAction(
            text: libL10n.delete,
            icon: Icons.delete_outline,
            destructive: true,
            onTap: () => _deleteRemote(ref, flow.title, server),
          ),
      ],
      title: flow.title,
      at: at,
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

/// Which chats the Agent's history shows: everything (null), this device's
/// ([device]), or one server's tasks (its id). Kept while the app runs, so the
/// sheet opens as it was left.
abstract final class AgentHistorySource {
  static const device = '';
  static final shown = ValueNotifier<String?>(null);
}

/// One line of the history: a chat of this device or a task of a server.
sealed class _Row {
  const _Row();
  DateTime get at;

  /// Which row this is, across rebuilds.
  String get key;
}

final class _LocalRow extends _Row {
  const _LocalRow(this.chat);
  final ChatMeta chat;
  @override
  DateTime get at => chat.updatedAt;
  @override
  String get key => 'local:${chat.id}';
}

final class _RemoteRow extends _Row {
  const _RemoteRow(this.serverId, this.server, this.flow);
  final String serverId;
  final String server;
  final MonitorAgentFlow flow;
  @override
  DateTime get at => flow.updatedAt;
  @override
  String get key => 'remote:$serverId:${flow.id}';
}

/// A row that comes in: it opens to its height, pushing what is below aside
/// rather than putting it somewhere else between two frames, and fades in.
/// One that was already there is drawn as it is.
class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: Durations.medium1, value: widget.animate ? 0 : 1);
  late final _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Reduced motion: there at once.
        if (MediaQuery.of(context).disableAnimations) {
          _controller.value = 1;
        } else {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}

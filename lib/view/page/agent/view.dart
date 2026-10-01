import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart'
    show Chats, Composer, LlmConversation, LlmStores, llmL10n;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/provider/ai/adhoc_ssh.dart';
import 'package:server_box/view/page/agent/history.dart';
import 'package:server_box/view/widget/float_shell.dart';

/// The buttons that act on the conversation rather than on the window around
/// it. Shared by the tab's header and the floating shell's title bar, which
/// otherwise have nothing in common.
class AgentHeaderActions extends StatelessWidget {
  const AgentHeaderActions({
    super.key,
    this.showConversations = false,
    this.scope,
    this.tabBar = false,
  });

  /// Drawn in the tab's bar, which is drawn as every other tab's — see
  /// [agentHeaderButton].
  final bool tabBar;

  /// Whether to carry the history and new-chat buttons.
  ///
  /// Only where nothing else does: the tab's own line names the chat and opens
  /// the list when tapped.
  final bool showConversations;

  final String? scope;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showConversations) ...[
          agentHeaderButton(
            tabBar: tabBar,
            tooltip: context.l10n.askAiHistory,
            onTap: () => showAgentHistorySheet(context, scope: scope),
            icon: Icons.history,
          ),
          agentHeaderButton(
            tabBar: tabBar,
            tooltip: context.l10n.askAiNewConversation,
            onTap: () => AgentChats.startNew(scope),
            icon: Icons.add,
          ),
        ],
        // Only the app-wide Agent opens connections of its own.
        if (scope == null) _AdHocSessionsButton(tabBar: tabBar),
      ],
    );
  }
}

/// One button of an Agent header.
///
/// In the tab's bar, the `Btn.icon` at 18pt that every other tab's bar draws
/// its actions with. Elsewhere — the floating shell's title bar, the terminal's
/// sheet — an `IconButton` at [floatHeaderIconSize], which those bars are
/// measured for.
///
/// [badge] is a count drawn on the icon's corner.
Widget agentHeaderButton({
  required bool tabBar,
  required String tooltip,
  required VoidCallback onTap,
  required IconData icon,
  int? badge,
}) {
  final glyph = Icon(icon, size: tabBar ? 18 : floatHeaderIconSize);
  final drawn = badge == null
      ? glyph
      : Badge.count(count: badge, child: glyph);
  if (tabBar) return Btn.icon(text: tooltip, icon: drawn, onTap: onTap);
  return IconButton(tooltip: tooltip, onPressed: onTap, icon: drawn);
}

/// How many hosts the Agent has open that are not configured servers.
///
/// Present only while there are any. They are invisible otherwise — no card,
/// no server row — and a connection the model opened and forgot about should
/// not be something only the model knows exists.
class _AdHocSessionsButton extends ConsumerWidget {
  const _AdHocSessionsButton({required this.tabBar});

  final bool tabBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(adHocSshSessionsProvider);
    if (sessions.isEmpty) return const SizedBox.shrink();
    return agentHeaderButton(
      tabBar: tabBar,
      tooltip: context.l10n.agentAdHocSessions,
      onTap: () => _show(context),
      icon: Icons.cable,
      badge: sessions.length,
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

/// A chat of [scope] and the box you type into: fl_pi_llm_ui's conversation
/// and composer, with the header that says which chat this is.
///
/// More than one of these can show the same scope — the tab and the floating
/// shell — and they follow the same [AgentChats.of].
class AgentConversationView extends StatelessWidget {
  const AgentConversationView({
    super.key,
    required this.compact,
    this.scope,
    this.showHeader = true,
    this.headerTrailing,
  });

  /// Too narrow for the chat list to sit beside it, so the header opens it.
  final bool compact;

  final String? scope;

  /// False where the container draws its own bar — the floating shell, whose
  /// bar has to be the thing you drag it by.
  final bool showHeader;

  /// After the chat's own buttons.
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final current = AgentChats.of(scope);
    return ValueListenableBuilder<String?>(
      valueListenable: current,
      builder: (context, id, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader) _buildHeader(context, id),
            Expanded(
              child: id == null
                  ? _buildEmpty(context)
                  // Keyed: a different chat is a different conversation, with
                  // its own scroll position.
                  // The header and the list of chats say it is running.
                  : LlmConversation(
                      key: ValueKey(id),
                      chatId: id,
                      showLoading: false,
                    ),
            ),
            // Inset and as wide as the messages above it.
            LayoutBuilder(
              builder: (context, cons) {
                final side = (cons.maxWidth * 0.03).clamp(9.0, 20.0);
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(side, 0, side, 13),
                    child: Center(
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Composer(
                          key: ValueKey(id ?? 'new:$scope'),
                          chatId: id,
                          scope: scope,
                          compact: compact,
                          onChatCreated: (created) =>
                              AgentChats.select(scope, created),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String? id) {
    return ListenableBuilder(
      listenable: LlmStores.chat.changes,
      builder: (context, _) {
        final title = switch (id == null ? null : LlmStores.chat.fetch(id)) {
          // As the list names it: an empty title is no title.
          final meta? when meta.title?.isNotEmpty ?? false => meta.title!,
          _? => context.l10n.askAiUntitledConversation,
          null => context.l10n.askAiNewConversation,
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(13, 7, 7, 0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  // Too narrow for the list beside it: the title is the way to
                  // it, as the terminal tab's session name is.
                  onTap: compact
                      ? () => showAgentHistorySheet(context, scope: scope)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (compact) const Icon(Icons.expand_more, size: 18),
                        // Writing a reply or running a tool: the one sign of
                        // it that stays when the reply is scrolled away.
                        AgentBusyBuilder(
                          scope: scope,
                          builder: (_, activity) =>
                              activity == AgentActivity.idle
                              ? UIs.placeholder
                              : Padding(
                                  padding: const EdgeInsets.only(left: 9),
                                  child: AgentActivityMark(activity),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Only where the list is out of sight: beside it, the list's
              // own `+` is the one, and a second here was the same button
              // twice in one window.
              if (id != null && compact)
                agentHeaderButton(
                  tabBar: true,
                  tooltip: context.l10n.askAiNewConversation,
                  onTap: () => AgentChats.startNew(scope),
                  icon: Icons.add,
                ),
              AgentHeaderActions(scope: scope, tabBar: true),
              ?headerTrailing,
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            UIs.height13,
            Text(
              scope == null
                  ? context.l10n.agentEmptyHint
                  : context.l10n.agentTerminalEmptyHint,
              textAlign: TextAlign.center,
              style: UIs.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether [scope]'s chat is writing a reply, for the floating shell's ring:
/// rebuilt as chats open and close, and as the one showing starts and ends a
/// run.
/// What a chat is doing, as the bar, the list and the floating pill show it.
enum AgentActivity {
  idle,

  /// Writing a reply or running a tool.
  running,

  /// Waiting on the user: a call to approve, or a form to fill in. Apart
  /// from [running] because only this one needs them.
  waiting;

  static AgentActivity of(String? chatId) {
    if (chatId == null) return idle;
    if (Chats.isWaiting(chatId)) return waiting;
    if (Chats.isRunning(chatId)) return running;
    return idle;
  }
}

/// [AgentActivity] as a mark [size] across: a spinner while it runs, a dot
/// while it waits on the user, nothing otherwise.
class AgentActivityMark extends StatelessWidget {
  const AgentActivityMark(this.activity, {super.key, this.size = 14});

  final AgentActivity activity;
  final double size;

  @override
  Widget build(BuildContext context) => switch (activity) {
    AgentActivity.idle => UIs.placeholder,
    AgentActivity.running => SizedLoading(
      size,
      padding: 0,
      builder: SizedLoading.circularBuilder,
    ),
    AgentActivity.waiting => Tooltip(
      message: llmL10n.waitingForYou,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  };
}

/// [builder] with what the chat [scope] shows is doing.
class AgentBusyBuilder extends StatelessWidget {
  const AgentBusyBuilder({super.key, this.scope, required this.builder});

  final String? scope;
  final Widget Function(BuildContext context, AgentActivity activity) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AgentChats.of(scope),
        Chats.openChanges,
        Chats.runningChanges,
      ]),
      builder: (context, _) =>
          builder(context, AgentActivity.of(AgentChats.of(scope).value)),
    );
  }
}

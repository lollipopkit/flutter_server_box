import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/view/page/agent/history.dart';
import 'package:server_box/view/page/agent/view.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// The Agent tab.
///
/// It owns no part of the conversation — that is [agentSessionProvider], and
/// the floating shell shows the same one. All this page adds is the history
/// column, which only a full tab is wide enough for.
class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

/// Kept alive not for the conversation — that outlives every widget now — but
/// for the scroll position and whatever is half-typed in the composer below,
/// which belong to this view and would be lost on a tab switch otherwise.
class _AgentPageState extends ConsumerState<AgentPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    // Selected rather than watched whole: this page rebuilds on nothing else,
    // and the conversation itself changes on every streamed token.
    final hasConversations = ref.watch(
      agentSessionProvider.select(
        (session) => session.conversations.isNotEmpty,
      ),
    );

    // The same judgement, width and seam as the server list and the terminal
    // tabs: whether a list gets a column of its own is a property of the
    // window, not of the page that happens to be in it.
    return Material(
      color: theme.colorScheme.surface,
      child: SbPaneList(
        // Nothing to sit beside until there is a conversation: the header
        // keeps its history and new-conversation buttons, so folding the
        // column away costs nothing and hands 320pt back to the answer.
        hasContent: hasConversations,
        sideBuilder: (_) => const AgentHistoryPanel(inSheet: false),
        builder: (_, split) => AgentConversationView(
          compact: !split,
          headerTrailing: const _FloatToggle(),
        ),
      ),
    );
  }
}

/// Sends this conversation floating, so it stays reachable from the other
/// tabs. Off by default: most of the time the tab is where you want it, and a
/// window over every other page would be in the way.
class _FloatToggle extends ConsumerWidget {
  const _FloatToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floating = ref.watch(agentShellProvider) != AgentShellMode.hidden;
    return IconButton(
      tooltip: context.l10n.agentFloat,
      isSelected: floating,
      onPressed: ref.read(agentShellProvider.notifier).toggle,
      icon: const Icon(Icons.picture_in_picture_alt_outlined),
      selectedIcon: const Icon(Icons.picture_in_picture_alt),
    );
  }
}

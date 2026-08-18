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

    // The same judgement, width and seam as the server list and the terminal
    // tabs: whether a list gets a column of its own is a property of the
    // window, not of the page that happens to be in it.
    return Material(
      color: theme.colorScheme.surface,
      child: SbPaneList(
        // The column is there from the start, empty or not — the same as the
        // terminal and file tabs, and for the reason they settled on. Folding
        // it away until there was a conversation to list saved 320pt of a
        // window wide enough not to need saving, and cost this tab a second
        // layout: it greeted a wide window as one column, then rearranged
        // itself into two the moment anything was said. Read from the outside
        // it was the Agent tab refusing to split at a width where every other
        // tab had.
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
      icon: const Icon(
        Icons.picture_in_picture_alt_outlined,
        size: agentHeaderIconSize,
      ),
      selectedIcon: const Icon(
        Icons.picture_in_picture_alt,
        size: agentHeaderIconSize,
      ),
    );
  }
}

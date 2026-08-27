import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/view/page/agent/view.dart';
import 'package:server_box/view/widget/float_shell.dart';

/// The Agent, over whatever else is on screen.
///
/// What it shows is the same [globalAgentSessionProvider] the Agent tab shows —
/// this is a second window onto one conversation, not a second conversation.
/// The window itself is [FloatShell], which the floating terminal shares.
class AgentFloatingShell extends ConsumerWidget {
  const AgentFloatingShell({super.key, required this.area});

  /// The box this is painted in, measured by the caller.
  final Size area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(agentShellProvider);
    final visible =
        mode != FloatShellMode.hidden &&
        // The tab is the better view of the same thing whenever it is the one
        // being looked at, and two of them at once is only confusing.
        ref.watch(currentHomeTabProvider) != AppTab.agent;
    final working = ref.watch(
      globalAgentSessionProvider.select((session) => session.isWorking),
    );
    final shell = ref.read(agentShellProvider.notifier);

    return FloatShell(
      area: area,
      visible: visible,
      mode: mode,
      geometry: agentShellGeometry,
      title: 'Agent',
      icon: Icons.auto_awesome,
      onExpand: shell.expand,
      onCollapse: shell.collapse,
      onHide: shell.hide,
      actions: const [AgentHeaderActions(showConversations: true)],
      pillOverlay: working ? const _WorkingRing() : null,
      builder: (_) =>
          const AgentConversationView(compact: true, showHeader: false),
    );
  }
}

/// A ring rather than a badge: the pill is the only sign the Agent is doing
/// anything while you are on another tab.
class _WorkingRing extends StatelessWidget {
  const _WorkingRing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Inset from the pill's own edge, so the ring reads as inside it rather
      // than as its outline.
      padding: const EdgeInsets.all(4),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

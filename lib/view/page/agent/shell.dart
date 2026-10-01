import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/view/page/agent/view.dart';
import 'package:server_box/view/widget/float_shell.dart';

/// The Agent, over whatever else is on screen.
///
/// What it shows is the chat the Agent tab shows — see `AgentChats` — a second
/// window onto one conversation, not a second conversation.
/// The window itself is [FloatShell], which the floating terminal shares.
class AgentFloatingShell extends ConsumerWidget {
  const AgentFloatingShell({super.key, required this.area});

  /// The box this is painted in, measured by the caller.
  final Size area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(agentShellProvider);
    final onTab =
        // The tab is the better view of the same thing whenever it is the one
        // being looked at, and two of them at once is only confusing.
        ref.watch(currentHomeTabProvider) == AppTab.agent;
    final shell = ref.read(agentShellProvider.notifier);

    return ValueListenableBuilder(
      valueListenable: AgentChats.engaged,
      builder: (context, engaged, _) => _build(
        visible: mode != FloatShellMode.hidden && !onTab && engaged,
        mode: mode,
        shell: shell,
      ),
    );
  }

  Widget _build({
    required bool visible,
    required FloatShellMode mode,
    required AgentShell shell,
  }) {
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
      pillOverlay: AgentBusyBuilder(
        builder: (_, activity) => switch (activity) {
          AgentActivity.idle => UIs.placeholder,
          AgentActivity.running => const _WorkingRing(),
          AgentActivity.waiting => const _WorkingRing(waiting: true),
        },
      ),
      titleTrailing: AgentBusyBuilder(
        builder: (_, activity) => activity == AgentActivity.idle
            ? UIs.placeholder
            : Padding(
                padding: const EdgeInsets.only(left: 9),
                child: AgentActivityMark(activity),
              ),
      ),
      builder: (_) =>
          const AgentConversationView(compact: true, showHeader: false),
    );
  }
}

/// A ring rather than a badge: the pill is the only sign the Agent is doing
/// anything while you are on another tab.
class _WorkingRing extends StatelessWidget {
  const _WorkingRing({this.waiting = false});

  /// Waiting on the user: a whole ring that stays, in the accent the list and
  /// the bar mark it with, not a spinner — there is nothing to wait out.
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Inset from the pill's own edge, so the ring reads as inside it rather
      // than as its outline.
      padding: const EdgeInsets.all(4),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: waiting ? 1 : null,
        color: waiting
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

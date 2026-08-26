import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
import 'package:server_box/view/page/agent/shell.dart';
import 'package:server_box/view/page/ssh/float.dart';

/// The windows that float over every tab, and the one rule they share.
///
/// Both can be up at once, and on a desktop they are simply two windows: they
/// keep their own size, their own position and their own collapsed state, they
/// start in different corners, and dragging one never moves the other.
///
/// A phone has no such room. The expanded panel there is a sheet across the
/// full width of the screen, so two of them are the same rectangle and the one
/// drawn second hides the other completely — including the buttons that would
/// have got it back. So on a phone, expanding one collapses the other to its
/// pill. Both are still there and either is one tap away; what is not offered
/// is the arrangement where one of them cannot be reached at all.
class FloatingPanels extends ConsumerWidget {
  const FloatingPanels({super.key, required this.area});

  /// The box these are painted in, measured by the caller.
  ///
  /// Not `MediaQuery.sizeOf`: that is the window, and a panel kept inside the
  /// window can still hang out of the area it is drawn in.
  final Size area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The breakpoint, not the platform: it is what each shell reads to decide
    // between the desktop panel and the phone sheet, and this rule is about
    // which of those two it drew.
    if (ResponsiveBreakpoints.of(context).isMobile) {
      ref.listen(agentShellProvider, (_, next) {
        if (next != FloatShellMode.expanded) return;
        // A no-op when no terminal is floating, so this cannot conjure a pill
        // for a window that is not open.
        ref.read(terminalShellProvider.notifier).collapse();
      });
      ref.listen(terminalShellProvider, (_, next) {
        if (next.mode != FloatShellMode.expanded) return;
        // Guarded, because `collapse` on a hidden Agent would *show* it: the
        // three modes are one value, and collapsed is a way of being on
        // screen.
        if (ref.read(agentShellProvider) != FloatShellMode.expanded) return;
        ref.read(agentShellProvider.notifier).collapse();
      });
    }

    // Expanded, because every child here is positioned — a stack with none
    // that are not takes the smallest size it is allowed, and the panels would
    // be laid out against nothing. Each shell unmounts to a `SizedBox` when it
    // is fully closed, which is the child that would otherwise decide the size
    // for both of them.
    return Stack(
      fit: StackFit.expand,
      children: [
        // Under the Agent, which is the one that follows a conversation you
        // are having *about* what the terminal is showing.
        TerminalFloatingShell(area: area),
        AgentFloatingShell(area: area),
      ],
    );
  }
}

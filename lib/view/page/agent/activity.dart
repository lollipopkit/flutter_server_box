import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show Chats, llmL10n;
import 'package:material_ui/material_ui.dart';

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

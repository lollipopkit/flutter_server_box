import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/view/widget/agent_common.dart';

/// A tool call waiting for the user, in the approval card: how much harm it
/// can do, what the model says it is for, and the call itself.
class AgentToolPreview extends StatelessWidget {
  const AgentToolPreview({super.key, required this.command, this.onInsert});

  final AskAiCommand command;

  /// Puts the command in the terminal instead of running it, where there is a
  /// terminal to put it in.
  final VoidCallback? onInsert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final risk = riskInfo(context, command.risk);
    final content = command.toolName == 'write_file'
        ? command.argumentString('content')
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(risk.icon, size: 17, color: risk.color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                risk.label,
                style: TextStyle(fontSize: 13, color: risk.color),
              ),
            ),
            if (onInsert case final insert?)
              Btn.text(text: context.l10n.askAiInsertTerminal, onTap: insert),
          ],
        ),
        if (command.description.isNotEmpty)
          Text(command.description, style: UIs.text13Grey),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(9),
          ),
          child: AgentCommandPreview(
            text: command.displayValue,
            language: command.toolName == 'run_shell_command' ? 'shell' : 'text',
          ),
        ),
        if (content != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: AgentCommandPreview(text: content, language: 'text'),
          ),
      ].joinWith(const SizedBox(height: 7)),
    );
  }

  /// How a risk reads: the same words and colours wherever a call is shown.
  static ({String label, IconData icon, Color color}) riskInfo(
    BuildContext context,
    AskAiCommandRisk risk,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (risk) {
      AskAiCommandRisk.readOnly => (
        label: context.l10n.askAiRiskReadOnly,
        icon: Icons.visibility_outlined,
        color: scheme.primary,
      ),
      AskAiCommandRisk.unknown => (
        label: context.l10n.askAiRiskUnknown,
        icon: Icons.help_outline,
        color: scheme.tertiary,
      ),
      AskAiCommandRisk.unvettedHost => (
        label: context.l10n.askAiRiskUnvetted,
        icon: Icons.shield_outlined,
        color: scheme.tertiary,
      ),
      AskAiCommandRisk.caution => (
        label: context.l10n.askAiRiskCaution,
        icon: Icons.warning_amber_rounded,
        color: scheme.tertiary,
      ),
      AskAiCommandRisk.destructive => (
        label: context.l10n.askAiRiskDestructive,
        icon: Icons.dangerous_outlined,
        color: scheme.error,
      ),
    };
  }
}

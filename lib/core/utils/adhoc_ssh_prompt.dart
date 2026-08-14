import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// Asks the user for the password to a host the Agent wants to connect to.
///
/// A dialog rather than a tool argument, and this is the whole point of it:
/// `AskAiCommand.rawArguments` is written into the conversation verbatim and
/// persisted with it, so a password passed that way would sit in the
/// transcript for as long as the conversation does — and go back to the model
/// on every following turn. What the model gets instead is an opaque session
/// id.
///
/// Lives beside `showHostKeyPrompt`, which reaches the screen the same way and
/// for the same reason: the code that needs to ask is not a widget.
///
/// Returns null when the user declines, which the caller must treat as "do not
/// connect" rather than "connect without a password".
Future<String?> promptAdHocSshPassword({
  required String user,
  required String host,
  required int port,
  BuildContext? context,
}) async {
  final ctx = context?.mounted == true ? context : AppNavigator.context;
  if (ctx == null) {
    Loggers.app.warning(
      'Ad-hoc SSH password prompt skipped: navigator context unavailable.',
    );
    return null;
  }

  final controller = TextEditingController();
  try {
    return await ctx.showRoundDialog<String>(
      title: ctx.l10n.agentSshConnectTitle,
      barrierDismiss: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ctx.l10n.agentSshConnectTip),
          const SizedBox(height: 12),
          SelectableText(
            '$user@$host:$port',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: libL10n.pwd),
            onSubmitted: (value) => ctx.pop(value),
          ),
        ],
      ),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: libL10n.ok,
          onTap: () => dialogContext.pop(controller.text),
        ),
      ],
    );
  } finally {
    controller.dispose();
  }
}

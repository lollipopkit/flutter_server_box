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

/// What the user decided to save an ad-hoc host as.
@immutable
class AdHocServerSaveResult {
  const AdHocServerSaveResult({
    required this.name,
    this.monitorAddr,
    this.monitorUser,
    this.monitorPwd,
  });

  final String name;

  /// Where this server's `monitor` agent answers, when it has one.
  final String? monitorAddr;
  final String? monitorUser;
  final String? monitorPwd;
}

/// Asks whether to keep an ad-hoc host as a server, and under what name.
///
/// This dialog is the review step for saving, which is why `add_server` does
/// not also raise a confirmation: what would be confirmed is exactly what is
/// being filled in here, and it can be cancelled from here.
///
/// The monitor agent's credentials are collected here for the same reason the
/// SSH password is: the alternative is the Agent reading them off the machine
/// with a shell command, whose output goes into the conversation.
Future<AdHocServerSaveResult?> promptSaveAdHocServer({
  required String suggestedName,
  String? suggestedMonitorAddr,
  BuildContext? context,
}) async {
  final ctx = context?.mounted == true ? context : AppNavigator.context;
  if (ctx == null) {
    Loggers.app.warning(
      'Save-server prompt skipped: navigator context unavailable.',
    );
    return null;
  }

  final name = TextEditingController(text: suggestedName);
  final addr = TextEditingController(text: suggestedMonitorAddr ?? '');
  final user = TextEditingController();
  final pwd = TextEditingController();
  String? trimmed(TextEditingController c) {
    final value = c.text.trim();
    return value.isEmpty ? null : value;
  }

  try {
    return await ctx.showRoundDialog<AdHocServerSaveResult>(
      title: ctx.l10n.agentSaveServerTitle,
      barrierDismiss: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.agentSaveServerTip),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: libL10n.name),
            ),
            const SizedBox(height: 16),
            Text(
              ctx.l10n.agentMonitorOptional,
              style: TextStyle(color: ctx.theme.colorScheme.onSurfaceVariant),
            ),
            TextField(
              controller: addr,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: libL10n.addr,
                hintText: 'http://127.0.0.1:3770',
              ),
            ),
            TextField(
              controller: user,
              decoration: InputDecoration(labelText: libL10n.user),
            ),
            TextField(
              controller: pwd,
              obscureText: true,
              decoration: InputDecoration(labelText: libL10n.pwd),
            ),
          ],
        ),
      ),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: libL10n.save,
          onTap: () {
            final value = name.text.trim();
            if (value.isEmpty) return;
            dialogContext.pop(
              AdHocServerSaveResult(
                name: value,
                monitorAddr: trimmed(addr),
                monitorUser: trimmed(user),
                monitorPwd: trimmed(pwd),
              ),
            );
          },
        ),
      ],
    );
  } finally {
    name.dispose();
    addr.dispose();
    user.dispose();
    pwd.dispose();
  }
}

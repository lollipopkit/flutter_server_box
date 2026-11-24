import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/rescue/scaffold.dart';

/// The whole app, when the launch threw before it had a screen (#1633).
///
/// The window starts hidden and is shown by the launch itself, so a throw
/// before that left a process with no window and the reason only in a file.
/// This says that it failed, what was thrown, and where the logs are.
class LaunchFailedPage extends StatelessWidget {
  const LaunchFailedPage({
    super.key,
    required this.err,
    required this.stack,
    this.logDir,
  });

  final Object err;
  final StackTrace stack;

  /// Null when the launch failed before it had one.
  final String? logDir;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mono = const TextStyle(fontFamily: 'monospace', fontSize: 12);
    return RescueScaffold(
      children: [
        RescueHeader(icon: Icons.error_outline, title: l10n.launchFailedTitle),
        UIs.height13,
        Text(
          l10n.launchFailedBody,
          style: UIs.textGrey,
          textAlign: TextAlign.center,
        ),
        if (logDir case final dir?) ...[
          UIs.height13,
          SelectableText(
            l10n.launchFailedLogs(dir),
            textAlign: TextAlign.center,
          ),
        ],
        UIs.height13,
        const Divider(),
        UIs.height13,
        SelectableText('$err', style: mono),
        UIs.height13,
        FilledButton.icon(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: '$err\n$stack')),
          icon: const Icon(Icons.copy),
          label: Text(libL10n.copy),
        ),
      ],
    );
  }
}

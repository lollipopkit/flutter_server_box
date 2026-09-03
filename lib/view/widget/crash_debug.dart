import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/service/crash_report.dart';

/// Exercises the crash report path without waiting for a crash.
///
/// Debug builds only, and reached from a button that is itself behind
/// [kDebugMode] — a `const`, so this whole file is dropped from a release by
/// tree shaking rather than merely hidden in one.
///
/// It exists because the path is otherwise unreachable on purpose: the prompt
/// appears once per crash, on the launch after it, which is not something to
/// arrange by hand every time the wording changes. What is being checked is
/// mostly the *text* — whether the report names a server, and whether the
/// dialog's claim about that is honest.
abstract final class CrashDebugMenu {
  static Future<void> show(BuildContext context) async {
    final action = await context.showRoundDialog<_Action>(
      title: 'Crash diagnostics (debug)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final action in _Action.values)
            ListTile(
              dense: true,
              title: Text(action.label),
              onTap: () => context.popDialog(action),
            ),
        ],
      ),
      actions: [Btn.cancel()],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _Action.throwUnhandled:
        // Through the framework's own reporter, which is the path
        // `CrashLog.handleErrors` wraps. The process keeps running — an
        // uncaught Dart error does not end it — so the marker is written and
        // the next launch is what shows the prompt.
        FlutterError.reportError(FlutterErrorDetails(
          exception: StateError('Deliberate crash from the debug menu'),
          stack: StackTrace.current,
          library: 'crash diagnostics',
        ));
        Toast.warn('Marked. Restart the app to see the notice.');

      case _Action.previewReport:
        // The report as it stands, without needing a crash first. This is the
        // one to read: it says what would actually be published.
        final report = await CrashReport.build();
        if (!context.mounted) return;
        await context.showRoundDialog(
          title: 'Report preview',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: SelectableText(
                report,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            Btn.text(text: libL10n.copy, onTap: () {
              Pfs.copy(report);
              context.popDialog();
            }),
            Btn.ok(),
          ],
        );

      case _Action.clear:
        await CrashLog.clear();
        Toast.success('Both logs and the marker are gone.');
    }
  }
}

enum _Action {
  throwUnhandled('Throw an unhandled error'),
  previewReport('Preview the report'),
  clear('Clear the logs');

  const _Action(this.label);

  final String label;
}

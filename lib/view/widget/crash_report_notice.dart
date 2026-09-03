import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/data/res/url.dart';

/// Offers to hand over what the previous run left behind, after it crashed.
///
/// Asked rather than sent. Nothing here reaches the network on its own: the
/// report goes on the clipboard and the issue page is opened, so the user is
/// the one who posts it and sees what they are posting first. That is what
/// keeps this out of F-Droid's Tracking anti-feature, and it is also the only
/// honest arrangement while the log can still name a server — see
/// [CrashReport].
///
/// Two steps on purpose. The first is small and says what happened; a user who
/// wants nothing to do with it dismisses it there. The report itself is built
/// only after they ask for it, since reading the file is work that an ignored
/// notice should not do.
///
/// That first step is a toast in the corner rather than a dialog. What the app
/// has to say here is "the last run ended badly" — which is worth telling
/// somebody and is not worth taking the screen away from them for. The app has
/// just started; whatever they opened it to do is what they should be able to
/// get on with.
abstract final class CrashReportNotice {
  static void showIfNeeded(BuildContext context) {
    // Consumed by the launch that read the marker, so this appears once per
    // crash rather than once per launch after one.
    if (!CrashLog.lastRunEndedBadly) return;
    if (!context.mounted) return;

    Toast.show(
      l10n.crashNoticeBody,
      level: ToastLevel.warn,
      // Stays until it is dismissed, which is not what a toast usually does.
      // The marker is read once and cleared, and outside a debug build there
      // is no other way to this report — so a notice that times out while
      // nobody is looking loses the log for good. Dismissed by the button, or
      // by dragging it off the way any toast is.
      duration: Duration.zero,
      action: ToastAction(
        label: libL10n.view,
        onTap: () => _showReport(context),
      ),
    );
  }

  static Future<void> _showReport(BuildContext context) async {
    if (!context.mounted) return;

    final report = await CrashReport.build();
    if (!context.mounted) return;

    final action = await context.showRoundDialog<_ReportAction>(
      title: l10n.crashReportTitle,
      child: _ReportBody(report: report),
      actionsBuilder: (ctx) => [
        Btn.text(
          text: libL10n.copy,
          onTap: () => ctx.popDialog(_ReportAction.copy),
        ),
        Btn.text(
          text: l10n.crashReportSubmit,
          onTap: () => ctx.popDialog(_ReportAction.submit),
        ),
      ],
    );

    // The work happens here rather than in the buttons: a callback on a dialog
    // button has to pop the right navigator itself, and doing the work there
    // too is how that gets forgotten.
    switch (action) {
      case null:
        return;
      case _ReportAction.copy:
        Pfs.copy(report);
      case _ReportAction.submit:
        // Copied before the page opens, so it is already on the clipboard when
        // the user gets to the text box.
        Pfs.copy(report);
        Urls.newIssue.launchUrl();
    }
  }
}

enum _ReportAction { copy, submit }

/// The report, above the sentence asking the user to read it.
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final String report;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.crashReportHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        UIs.height13,
        // Bounded, because the log is up to 24k of text and an unbounded
        // column in a dialog lays all of it out.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

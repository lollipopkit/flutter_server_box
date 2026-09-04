import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/crash_report.dart';
import 'package:server_box/data/res/url.dart';

/// Shows what the previous run left behind, after it crashed.
///
/// **Nothing here reaches the network.** The report goes on the clipboard and
/// the issue page is opened, so the user is the one who posts it and sees what
/// they are posting first. That is the only honest arrangement while the log
/// can still name a server — see [CrashReport] — and it is the reason the log
/// is never part of what an upload level sends, at any level.
///
/// **Reached from Settings → Privacy, not from a prompt.** A toast used to be
/// raised on the launch after a crash, which put the question in front of
/// somebody who had just opened the app to do something else, and put it there
/// exactly once. What replaced it is a row that waits: the report is kept on
/// disk until it is dropped or another crash replaces it, so a user who reads
/// about a bug a week later can still find the log for it.
abstract final class CrashReportDialog {
  /// Opens the report, and answers whether it is still on the device after.
  ///
  /// False only when the user dropped it, which is what the caller needs to
  /// know: the row that opened this stops existing at that point.
  static Future<bool> show(BuildContext context, String report) async {
    final action = await context.showRoundDialog<_ReportAction>(
      title: l10n.crashReportTitle,
      child: _ReportBody(report: report),
      actionsBuilder: (ctx) => [
        Btn.text(
          text: libL10n.delete,
          onTap: () => ctx.popDialog(_ReportAction.drop),
        ),
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
        return true;
      case _ReportAction.drop:
        await CrashReport.dropSaved();
        return false;
      case _ReportAction.copy:
        Pfs.copy(report);
        return true;
      case _ReportAction.submit:
        // Copied before the page opens, so it is already on the clipboard when
        // the user gets to the text box.
        Pfs.copy(report);
        Urls.newIssue.launchUrl();
        return true;
    }
  }
}

enum _ReportAction { drop, copy, submit }

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

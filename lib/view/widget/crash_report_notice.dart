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
/// Two steps on purpose. The first dialog is small and says what happened; a
/// user who wants nothing to do with it answers there. The report itself is
/// built only after they ask for it, since reading the file is work that a
/// dismissed prompt should not do.
abstract final class CrashReportNotice {
  static Future<void> showIfNeeded(BuildContext context) async {
    // Consumed by the launch that read the marker, so this asks once per
    // crash rather than once per launch after one.
    if (!CrashLog.lastRunEndedBadly) return;
    if (!context.mounted) return;

    final wants = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.crashNoticeBody),
      actions: Btnx.cancelOk,
    );
    if (wants != true || !context.mounted) return;

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

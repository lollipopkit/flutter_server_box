import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/cron_schedule.dart';
import 'package:server_box/src/rust/api/cron.dart' as ffi;

/// Why a line was refused, in the words the editor shows.
enum CronValidation {
  scheduleEmpty,
  commandEmpty,
  lineBreak,
  macro,
  fieldCount;

  String get message => switch (this) {
    scheduleEmpty => l10n.cronErrScheduleEmpty,
    commandEmpty => l10n.cronErrCommandEmpty,
    lineBreak => l10n.cronErrLineBreak,
    macro => l10n.cronErrMacro,
    fieldCount => l10n.cronErrFieldCount,
  };
}

final class CronJob {
  const CronJob({
    required this.lineIndex,
    required this.schedule,
    required this.command,
    required this.enabled,
  });

  final int lineIndex;
  final String schedule;
  final String command;
  final bool enabled;

  /// [schedule] expanded, or `null` for a syntax this app does not read.
  CronSchedule? get parsed => CronSchedule.tryParse(schedule);
}

/// A crontab as `sbm_parser::cron` reads it: every line, and the jobs read out
/// of them. Lines are authoritative — [render] writes back every one, so a
/// comment, an environment assignment or a syntax this app does not read
/// survives a save untouched. Each edit is made on the Rust side and answers
/// the whole new document.
final class CronDocument {
  CronDocument.fromFfi(this._data)
    : jobs = [
        for (final job in _data.jobs)
          CronJob(
            lineIndex: job.lineIndex,
            schedule: job.schedule,
            command: job.command,
            enabled: job.enabled,
          ),
      ];

  final ffi.CronDocumentData _data;
  final List<CronJob> jobs;

  List<String> get lines => _data.lines;

  /// Every line that is not a task: comments, environment assignments, and
  /// anything this app could not read as one. The page shows them so that a
  /// crontab another tool manages does not look like it lost them.
  List<String> get preserved => _data.preserved;

  String render() => _data.text;

  CronDocument upsert({
    CronJob? original,
    required String schedule,
    required String command,
    required bool enabled,
  }) => _edit(
    () => ffi.cronUpsert(
      lines: lines,
      lineIndex: original?.lineIndex,
      schedule: schedule,
      command: command,
      enabled: enabled,
    ),
  );

  CronDocument remove(CronJob job) =>
      _edit(() => ffi.cronRemove(lines: lines, lineIndex: job.lineIndex));

  CronDocument setEnabled(CronJob job, bool enabled) => _edit(
    () => ffi.cronSetEnabled(
      lines: lines,
      lineIndex: job.lineIndex,
      enabled: enabled,
    ),
  );

  /// What is wrong with the line these two would make, or `null`.
  ///
  /// It says nothing about whether the schedule will ever fire: what it
  /// refuses is what would damage the file — a line break splits one task
  /// into two — and what no crond accepts.
  static CronValidation? validate({
    required String schedule,
    required String command,
  }) => switch (ffi.cronValidate(schedule: schedule, command: command)) {
    null => null,
    final code => CronValidation.values.byName(code),
  };

  /// An edit the editor did not validate first, or one naming a line that is
  /// no longer a job, is a bug in the caller: thrown, as before.
  static CronDocument _edit(ffi.CronDocumentData Function() edit) {
    try {
      return CronDocument.fromFfi(edit());
    } on ffi.CronEditError catch (e) {
      throw ArgumentError(e.code);
    }
  }
}

final class CronCatalog {
  const CronCatalog({required this.user, required this.document, this.clock});

  final String user;
  final CronDocument document;

  /// The server's clock when this listing was read, or `null` when its `date`
  /// could not say. Every time on the page is worked out in it.
  final CronClock? clock;
}

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
}

final class CronDocument {
  CronDocument._(this.lines, this.jobs);

  static const disabledPrefix = '# ServerBox disabled: ';

  final List<String> lines;
  final List<CronJob> jobs;

  factory CronDocument.parse(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.isEmpty ? <String>[] : normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    return CronDocument._(lines, _parseJobs(lines));
  }

  CronDocument upsert({
    CronJob? original,
    required String schedule,
    required String command,
    required bool enabled,
  }) {
    final error = validate(schedule: schedule, command: command);
    if (error != null) throw ArgumentError(error);
    final next = List<String>.from(lines);
    final line = _renderJob(schedule.trim(), command.trim(), enabled);
    if (original == null) {
      next.add(line);
    } else {
      _checkIndex(original.lineIndex);
      next[original.lineIndex] = line;
    }
    return CronDocument._(next, _parseJobs(next));
  }

  CronDocument remove(CronJob job) {
    _checkIndex(job.lineIndex);
    final next = List<String>.from(lines)..removeAt(job.lineIndex);
    return CronDocument._(next, _parseJobs(next));
  }

  CronDocument setEnabled(CronJob job, bool enabled) {
    return upsert(
      original: job,
      schedule: job.schedule,
      command: job.command,
      enabled: enabled,
    );
  }

  String render() => lines.isEmpty ? '' : '${lines.join('\n')}\n';

  static String? validate({
    required String schedule,
    required String command,
  }) {
    final cleanSchedule = schedule.trim();
    final cleanCommand = command.trim();
    if (cleanSchedule.isEmpty) return 'Schedule is required';
    if (cleanCommand.isEmpty) return 'Command is required';
    if (_hasLineBreak(cleanSchedule) || _hasLineBreak(cleanCommand)) {
      return 'Cron fields cannot contain line breaks';
    }
    if (cleanSchedule.startsWith('@')) {
      if (!RegExp(r'^@\S+$').hasMatch(cleanSchedule)) {
        return 'Invalid cron schedule';
      }
      return null;
    }
    if (cleanSchedule.split(RegExp(r'\s+')).length != 5) {
      return 'A cron schedule must contain five fields';
    }
    return null;
  }

  static List<CronJob> _parseJobs(List<String> lines) {
    final jobs = <CronJob>[];
    for (var index = 0; index < lines.length; index++) {
      var candidate = lines[index].trimLeft();
      var enabled = true;
      if (candidate.startsWith(disabledPrefix)) {
        candidate = candidate.substring(disabledPrefix.length).trimLeft();
        enabled = false;
      } else if (candidate.isEmpty || candidate.startsWith('#')) {
        continue;
      }

      final parsed = _parseJobLine(candidate);
      if (parsed == null) continue;
      jobs.add(CronJob(
        lineIndex: index,
        schedule: parsed.$1,
        command: parsed.$2,
        enabled: enabled,
      ));
    }
    return jobs;
  }

  static (String, String)? _parseJobLine(String line) {
    final macro = RegExp(r'^(@\S+)\s+(.+)$').firstMatch(line);
    if (macro != null) return (macro.group(1)!, macro.group(2)!.trim());

    final standard = RegExp(
      r'^(\S+\s+\S+\s+\S+\s+\S+\s+\S+)\s+(.+)$',
    ).firstMatch(line);
    if (standard == null) return null;
    final schedule = standard.group(1)!.replaceAll(RegExp(r'\s+'), ' ');
    return (schedule, standard.group(2)!.trim());
  }

  static String _renderJob(String schedule, String command, bool enabled) {
    final line = '$schedule $command';
    return enabled ? line : '$disabledPrefix$line';
  }

  void _checkIndex(int index) {
    if (index < 0 || index >= lines.length) {
      throw RangeError.index(index, lines, 'lineIndex');
    }
  }

  static bool _hasLineBreak(String value) {
    return value.contains('\n') ||
        value.contains('\r') ||
        value.contains('\u0000');
  }
}

final class CronCatalog {
  const CronCatalog({required this.user, required this.document});

  final String user;
  final CronDocument document;
}

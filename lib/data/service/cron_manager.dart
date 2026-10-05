import 'package:server_box/data/model/server/cron.dart';
import 'package:server_box/data/model/server/cron_schedule.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/src/rust/api/cron.dart' as ffi;

final class CronManagerException implements Exception {
  const CronManagerException(this.message, {this.unavailable = false});

  final String message;
  final bool unavailable;

  @override
  String toString() => message;
}

/// The account's own crontab: what to run and how to read it, from
/// `sbm_parser::cron` — the rules the monitor agent's panel uses too. This
/// file only runs the commands and carries their results.
abstract final class CronManager {
  /// Handed to `sh` rather than run as the command: without an entry the
  /// script is parsed by the account's login shell, and fish rejects
  /// `LC_ALL=C` and `|| { ... }` outright — which the page reported as
  /// "crontab is not available" with fish's own diagnostic under it.
  static Future<CronCatalog> list(ServerExec exec) async {
    final result = await exec.run(ffi.cronListScript(), entry: 'sh');
    try {
      final listing = ffi.cronReadListing(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
        succeeded: result.succeeded,
      );
      final clock = listing.clock;
      return CronCatalog(
        user: listing.user,
        document: CronDocument.fromFfi(listing.document),
        clock: clock == null
            ? null
            : CronClock.fromServer(
                epochSeconds: clock.epochSeconds,
                offsetMinutes: clock.offsetMinutes,
              ),
      );
    } on ffi.CronFfiError catch (e) {
      throw _exception(e, 'Unable to list scheduled tasks');
    }
  }

  /// The document goes in on stdin, so it has no entry.
  static Future<void> save(ServerExec exec, CronDocument document) async {
    final result = await exec.run(
      ffi.cronSaveCommand(),
      stdin: document.render(),
    );
    try {
      ffi.cronCheckSave(
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
        succeeded: result.succeeded,
      );
    } on ffi.CronFfiError catch (e) {
      throw _exception(e, 'Unable to save scheduled tasks');
    }
  }

  static CronManagerException _exception(ffi.CronFfiError e, String fallback) =>
      CronManagerException(e.detail ?? fallback, unavailable: e.notInstalled);
}

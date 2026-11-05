part of 'single.dart';

/// How often [ShellFunc.statusExt] runs, independent of the status poll.
///
/// It carries the commands kept out of the poll (`sbm_parser::commands::
/// EXTENDED`), chiefly smartctl: reading SMART reaches the disk itself, so at
/// the status interval a disk with spin-down configured would never stay spun
/// down. The values it collects (SMART, AMD GPU) don't change meaningfully
/// faster than this anyway.
const _extendedStatusInterval = Duration(minutes: 5);

/// What the SSH and local paths share: the script installed on the machine,
/// the extended output cached between polls, and turning both into a status.
mixin _ScriptStatus on _ServerCore {
  /// Whether the generated script has been written to this server since the
  /// last time it was reachable.
  ///
  /// Not persisted: the script carries the app's build number, and a relaunch
  /// is exactly when it may need rewriting. Cleared whenever the server drops
  /// out, which is what covers a machine that rebooted and took `/tmp` with
  /// it — the script is gone and nothing else would notice, since a monitor
  /// server's status never reads it.
  bool _scriptWritten = false;

  /// Last [ShellFunc.statusExt] output, appended to every status refresh's raw
  /// output so its segments don't blank out on the polls in between — see
  /// [_extendedStatusInterval]
  String _extendedRaw = '';
  DateTime? _extendedFetchedAt;

  /// When [_extendedRaw] was last *replaced*, which is what its segments are
  /// as old as.
  ///
  /// Not when it was last read: the same copy is merged into every poll for
  /// the length of [_extendedStatusInterval], so stamping the parse would
  /// report a reading taken minutes ago as current — and saying how old it is
  /// is the whole reason the page carries it.
  DateTime? _extendedAcceptedAt;

  /// Marks the script as needing a rewrite. [extended] also drops the cached
  /// extended output, for when it may have come from another script or
  /// another machine.
  void _forgetInstalledScript({required bool extended}) {
    _scriptWritten = false;
    if (!extended) return;
    _extendedRaw = '';
    _extendedFetchedAt = null;
    _extendedAcceptedAt = null;
  }

  /// Runs [ShellFunc.statusExt] when [_extendedStatusInterval] has elapsed
  /// (or [force], for a user-initiated refresh) and returns its output,
  /// falling back to the last successful one.
  ///
  /// [run] executes one command and answers its stdout, or is null when
  /// there is nothing to run it on. Over SSH it is deliberately the exec path
  /// rather than the persistent shell: these commands can take seconds, and a
  /// timeout there would drop the whole connection to exec for good (see
  /// `_runStatusCommand`).
  Future<String> _refreshExtendedRaw({
    required bool force,
    required int operation,
    required Future<String> Function(String cmd)? run,
  }) async {
    final fetchedAt = _extendedFetchedAt;
    final due =
        force ||
        fetchedAt == null ||
        DateTime.now().difference(fetchedAt) >= _extendedStatusInterval;
    if (!due || run == null) return _extendedRaw;

    // Stamped before the run, so a remote that can't answer (an older script
    // without the function, until the next connect reinstalls it) is retried
    // on the extended schedule instead of on every poll
    _extendedFetchedAt = DateTime.now();
    final spi = state.spi;
    try {
      final cmd = ShellFunc.statusExt.exec(
        spi.id,
        systemType: state.status.system,
        customDir: spi.custom?.scriptDir,
      );
      final raw = await run(cmd);
      // The cache belongs to the notifier, not to this run: without the check
      // a refresh against the address the server used to have would leave the
      // old machine's SMART and GPU segments here, and the next poll of the
      // *new* one would find them still within the interval and merge them
      // into its status.
      if (!_isRefreshCurrent(operation, spi)) return _extendedRaw;
      if (ffi.containsStatusSegment(raw: raw)) {
        _extendedRaw = raw;
        _extendedAcceptedAt = DateTime.now();
      }
    } catch (e, s) {
      Loggers.app.warning('Extended status for ${spi.name} failed', e, s);
    }
    return _extendedRaw;
  }

  /// [raw] status output with [extended] merged in, parsed onto the current
  /// status.
  Future<ServerStatus> _parseScriptStatus(
    Spi spi,
    String extended,
    String raw,
  ) async {
    // Built-in markers are trusted only before the first custom section;
    // custom output may contain marker-looking text. Extended status has no
    // custom commands, so put it first and leave custom output last.
    final combined = extended.isEmpty ? raw : '$extended\n$raw';
    // Use the same conversion contract as the monitor path: raw transport
    // output becomes a ServerStatus plus one trend sample.
    final source = ScriptDataSource(spi: spi, runScript: () async => combined);
    final status = await source.fetchStatus(_copyStatus(state.status));
    // Shell output carries no sampling instant, so the nearest thing is when
    // the run that produced these segments came back.
    status.diskSmartAt = _extendedAcceptedAt;
    return status;
  }

  bool _hasEnabledStatusCommands(Spi spi, SystemType system) {
    final disabled = spi.disabledCmdTypes?.toSet() ?? const <String>{};
    final Iterable<ShellCmdType> commands = switch (system) {
      SystemType.linux => StatusCmdType.values,
      SystemType.bsd => BSDStatusCmdType.values,
      SystemType.windows => WindowsStatusCmdType.values,
    };
    return commands.any((command) => !disabled.contains(command.displayName));
  }
}

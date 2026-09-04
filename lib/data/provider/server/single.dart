import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/utils/monitor_exec.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/core/utils/ssh_exec.dart';
import 'package:server_box/data/helper/ssh_decoder.dart';
import 'package:server_box/data/helper/system_detector.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/data/provider/server/monitor_http_source.dart';
import 'package:server_box/data/provider/server/ssh_source.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/session_manager.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

part 'single.g.dart';
part 'single.freezed.dart';

/// How often [ShellFunc.statusExt] runs, independent of the status poll.
///
/// It carries the commands kept out of the poll (`sbm_parser::commands::
/// EXTENDED`), chiefly smartctl: reading SMART reaches the disk itself, so at
/// the status interval a disk with spin-down configured would never stay spun
/// down. The values it collects (SMART, AMD GPU) don't change meaningfully
/// faster than this anyway.
const _extendedStatusInterval = Duration(minutes: 5);

// Individual server state, including connection and status information
@freezed
abstract class ServerState with _$ServerState {
  const factory ServerState({
    required Spi spi,
    required ServerStatus status,
    @Default(ServerConn.disconnected) ServerConn conn,
    SSHClient? client,

    /// What the agent said it allows, or null before it has been asked.
    ///
    /// Asked rather than configured: whether this app can reach the machine
    /// without SSH is the agent's decision, it re-checks that decision when a
    /// request arrives, and it already answers the question over an
    /// authenticated endpoint. Putting the same question to the user meant
    /// asking them to assert something the server knows — and being wrong
    /// either way, since a "yes" the agent refuses is a row of dead buttons
    /// and a "no" it would have allowed hides features that are there.
    MonitorRemoteAccess? remoteAccess,
  }) = _ServerState;

  const ServerState._();

  /// What this server can do. The UI reads this instead of testing which
  /// transport is in use — see [ServerCapabilities].
  ///
  /// Across every way it is reachable, not just the one that leads: a server
  /// carrying both SSH and an agent really can do both sets of things, and
  /// hiding half of them behind a preference about *ordering* would take
  /// features away for no reason the user could see.
  ServerCapabilities get capabilities =>
      ServerCapabilities.ofSpi(spi, granted: remoteAccess);

  /// Whether running a command would have to open a connection first, i.e.
  /// whether a caller is about to make the user wait.
  ///
  /// Read off [capabilities] rather than off the transport:
  /// [ServerCapabilities.persistentSession] is already the question "is there a
  /// connection here at all", and a transport that answers no never waits for
  /// one. Testing [client] alone got this wrong for exactly that transport —
  /// it is always null there, and always will be.
  bool get execWillConnect =>
      capabilities.persistentSession && (client?.isClosed ?? true);
}

// Individual server state management
@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier {
  PersistentShell? _persistentShell;
  bool _usePersistentShellForStatus = true;
  int _operationGeneration = 0;

  /// Last [ShellFunc.statusExt] output, appended to every status refresh's raw
  /// output so its segments don't blank out on the polls in between — see
  /// [_extendedStatusInterval]
  String _extendedRaw = '';
  DateTime? _extendedFetchedAt;

  /// Reads status for whichever connection method this server uses. Rebuilt
  /// when the SPI's connection config changes.
  ServerDataSource? _source;

  int _cachedTimeout = 5;

  @override
  ServerState build(String serverId) {
    ref.onDispose(() {
      unawaited(_disposePersistentShell());
      _source?.close();
      try {
        state.client?.close();
      } catch (_) {}
    });

    // Cache timeout in memory; the DB read per poll is replaced by this.
    _cachedTimeout = Stores.setting.timeout.fetch();
    final timeoutListenable = Stores.setting.timeout.listenable();
    void timeoutListener() {
      _cachedTimeout = Stores.setting.timeout.fetch();
    }

    timeoutListenable.addListener(timeoutListener);
    ref.onDispose(() => timeoutListenable.removeListener(timeoutListener));

    final serverNotifier = ref.read(serversProvider);
    final spi = serverNotifier.servers[serverId];
    if (spi == null) {
      throw StateError('Server $serverId not found');
    }

    return ServerState(spi: spi, status: InitStatus.status);
  }

  Duration get _timeout =>
      Duration(seconds: _cachedTimeout <= 0 ? 5 : _cachedTimeout);

  // Update connection status
  void updateConnection(ServerConn conn) {
    state = state.copyWith(conn: conn);
  }

  // Update server status
  void updateStatus(ServerStatus status) {
    state = state.copyWith(status: status);
    _rememberDist(status);
  }

  /// Files what this poll said the machine is running.
  ///
  /// Here rather than in the parser, because this is the one place that knows
  /// *which server* a status belongs to. Written on every poll but only
  /// reaches the database when the answer changed, so a server polled every
  /// few seconds writes once and then never again.
  ///
  /// The reading is what lets a row draw the right mark without a live status
  /// — the pickers, the known-hosts page and the order page all hold only an
  /// id. See [ServerDistStore].
  void _rememberDist(ServerStatus status) {
    final dist = status.dist;
    if (dist == null) return;
    try {
      Stores.serverDist.put(state.spi.id, dist);
    } catch (e, s) {
      // A cache, so a failure to write one is not a failure to poll: the row
      // draws the neutral mark and the next poll tries again.
      Loggers.app.warning('Caching the distribution of ${state.spi.name}', e, s);
    }
  }

  ServerStatus _copyStatus(
    ServerStatus source, {
    Err? err,
    bool setErr = false,
    SystemType? system,
  }) {
    final status = ServerStatus(
      cpu: Cpus.copy(source.cpu),
      mem: source.mem,
      disk: source.disk.toList(),
      tcp: source.tcp,
      netSpeed: NetSpeed.copy(source.netSpeed),
      swap: source.swap,
      temps: Temperatures.copy(source.temps),
      system: system ?? source.system,
      diskIO: DiskIO.copy(source.diskIO),
      diskSmart: source.diskSmart.toList(),
      err: setErr ? err : source.err,
      nvidia: source.nvidia?.toList(),
      diskUsage: source.diskUsage,
      // Shared, unlike the rolling values above. It is append-only, so a
      // reader never sees it torn, and copying three hundred samples across
      // ten series every refresh would buy nothing.
      history: source.history,
    );
    status.amd = source.amd?.toList();
    status.osId = source.osId;
    status.osIdLike = source.osIdLike;
    // Carried, for the reason the mappers do not clear it: it refreshes on the
    // extended cadence, so most rebuilds of this object happen on a poll that
    // said nothing about addresses.
    status.ips = source.ips;
    status.batteries.addAll(source.batteries);
    status.more.addAll(source.more);
    status.sensors.addAll(source.sensors);
    status.customCmds.addAll(source.customCmds);
    return status;
  }

  // Update SSH client
  void _setClient(SSHClient? client) {
    if (!identical(state.client, client)) {
      unawaited(_disposePersistentShell());
      _usePersistentShellForStatus = true;
      // A different connection may be to a machine that has been rebooted
      // since, and a reboot takes `/tmp` — where the script lives — with it.
      _scriptWritten = false;
      // A new connection reinstalls the script, so drop the cache: the next
      // refresh re-runs the extended function against the current script
      _extendedRaw = '';
      _extendedFetchedAt = null;
    }
    state = state.copyWith(client: client);
  }

  // Update SPI configuration
  /// The record behind this server was edited.
  ///
  /// Editing is one code path for every field a server has, and most of them
  /// say nothing about the connection or about what runs over it. Dropping the
  /// client here regardless is what made adding a tag — or renaming a server,
  /// or turning off auto-connect — cost the session: the connection went, and
  /// [ServersNotifier.updateServer] then declined to reconnect, because by its
  /// own reckoning nothing had happened that called for one.
  void updateSpi(Spi spi) {
    final old = state.spi;
    final reconnect = spi.shouldReconnect(old);
    // What was written to the machine and what was read back from it. Both are
    // about the commands rather than the connection — the script directory and
    // the custom commands in it, and the extended output cached for five
    // minutes, which an edited address may have made another machine's.
    final rewrite =
        reconnect ||
        spi.custom != old.custom ||
        spi.customSystemType != old.customSystemType ||
        !listEquals(spi.disabledCmdTypes, old.disabledCmdTypes);

    if (rewrite) {
      _scriptWritten = false;
      _extendedRaw = '';
      _extendedFetchedAt = null;
    }

    if (!reconnect) {
      state = state.copyWith(spi: spi);
      // Installed now, not eventually. Clearing the flag is enough while the
      // server is between connections — the next one writes the script on its
      // way up — but on a connection that is staying open nothing else asks:
      // the install runs once, when the connection is made, and the status
      // poll after it just runs what is already there. So an edited command
      // would not take effect until the next reconnect.
      //
      // Not awaited and not fatal: the edit is saved either way, and the
      // failure a write can hit here is the one `ensureScriptExec` already
      // reports on the pages that call it.
      if (rewrite && state.client != null) {
        unawaited(() async {
          try {
            await ensureScriptExec();
          } catch (e, st) {
            Loggers.app.warning('Reinstalling script for ${spi.name}', e, st);
          }
        }());
      }
      return;
    }

    _operationGeneration++;
    unawaited(_disposePersistentShell());
    state.client?.close();
    _usePersistentShellForStatus = true;
    state = state.copyWith(
      spi: spi,
      client: null,
      conn: ServerConn.disconnected,
    );
  }

  void _setFailedState(ServerStatus status, {bool closeClient = false}) {
    final client = state.client;
    unawaited(_disposePersistentShell());
    // A server that went away may come back without what was on it: a reboot
    // clears `/tmp`, where the script lives by default.
    _scriptWritten = false;
    if (closeClient) {
      client?.close();
    }
    state = state.copyWith(
      status: status,
      client: closeClient ? null : client,
      conn: ServerConn.failed,
    );
  }

  // Close connection
  void closeConnection() {
    _operationGeneration++;
    unawaited(_disposePersistentShell());
    state.client?.close();
    _scriptWritten = false;
    state = state.copyWith(client: null, conn: ServerConn.disconnected);
  }

  // Refresh server status
  /// The generation of the refresh in flight, or null when there is none.
  ///
  /// Not a bare flag: editing a server bumps the generation, and the refresh
  /// that the edit kicks off must not be dropped because the one it superseded
  /// is still waiting for a socket to time out. That older refresh publishes
  /// nothing — every await re-checks — but it held the flag for the length of
  /// a connect timeout, which is exactly how long someone sat looking at a
  /// server still marked failed after they had fixed its address.
  int? _refreshingOperation;

  /// [interactive] means a person is waiting on this one — the Retry button on
  /// a failed card or on the detail page — as opposed to the poll timer. It
  /// decides both whether keyboard-interactive auth may raise a prompt and
  /// whether the wait is shown before the work starts.
  Future<void> refresh({bool interactive = false}) async {
    final operation = _operationGeneration;
    // Two refreshes of the *same* generation are the overlap worth stopping.
    if (_refreshingOperation == operation) return;

    _refreshingOperation = operation;
    try {
      // Somebody pressed Retry, and the first thing they are owed is that it
      // registered. Both paths raise a connecting/loading state of their own,
      // but the monitor path can fail *synchronously* — an address that is not
      // HTTPS is refused by `MonitorHttpClient._addr` before a request goes
      // out — so the attempt began and ended inside one microtask drain and no
      // frame ever carried the loading state. The button appeared dead.
      //
      // Only from a resting state: `finished` refreshing in place must not
      // blink a spinner over the readings it already has.
      final spi = state.spi;
      if (interactive && state.conn < ServerConn.connecting) {
        updateConnection(ServerConn.connecting);
        // Waited on rather than assumed. Yielding to the microtask queue is
        // not enough — a frame is scheduled on the event queue, and the whole
        // failure would still land before it ran.
        await SchedulerBinding.instance.endOfFrame;
        if (!_isRefreshCurrent(operation, spi)) return;
      }
      await _getData(interactive: interactive, operation: operation);
    } finally {
      // Only if it is still ours: a newer refresh may have taken over while
      // this one was finding out it had been superseded.
      if (_refreshingOperation == operation) _refreshingOperation = null;
    }
  }

  /// Whether the refresh identified by [operation] is still the current one
  /// and still targets [spi].
  ///
  /// [_refreshingOperation] stops two refreshes of the same generation
  /// overlapping, but nothing stops one that outlives what started it:
  /// editing the server or closing the connection bumps the generation, and
  /// an in-flight refresh that then finishes would publish a status for a
  /// server that no longer exists in that form. Every await in both paths
  /// re-checks this — including the ones a `catch` is reached from, which
  /// skip whatever check follows the await that threw.
  bool _isRefreshCurrent(int operation, Spi spi) =>
      operation == _operationGeneration && state.spi == spi;

  /// [interactive] only reaches the SSH path: it gates prompting the user for
  /// keyboard-interactive auth, which has no counterpart over monitor's HTTP
  /// API (credentials there are configured up front, never prompted for).
  Future<void> _getData({
    required bool interactive,
    required int operation,
  }) async {
    switch (ServerConnectCredential.fromSpi(state.spi)) {
      case ServerConnectCredentialSsh():
        // Connecting is inseparable from fetching here (auth prompts, script
        // install, session bookkeeping), so the SSH path drives the state
        // machine itself and hands the reading half to SshDataSource
        await _getDataSsh(interactive: interactive, operation: operation);
      case ServerConnectCredentialMonitorHttp(:final monitor):
        await _getDataMonitorHttp(monitor, operation);
    }
  }

  /// The [ServerDataSource] for the current SPI.
  ///
  /// Only the monitor HTTP source is cached: it owns a `Dio` session and a
  /// login token, so reusing it across refreshes avoids re-authenticating, and
  /// it must be rebuilt when the connection config changes. [SshDataSource] is
  /// stateless — the connection it reads through belongs to this notifier — so
  /// the SSH path constructs one per refresh instead.
  ServerDataSource _resolveSource(ServerConnectCredential credential) {
    switch (credential) {
      case ServerConnectCredentialSsh():
        return SshDataSource(
          spi: state.spi,
          runScript: () => throw StateError(
            'SSH status output is supplied by _getDataSsh, which runs the '
            'script as part of its connect-and-fetch flow',
          ),
        );
      case ServerConnectCredentialMonitorHttp():
        final existing = _source;
        if (existing is MonitorHttpDataSource && existing.matches(credential)) {
          return existing;
        }
        existing?.close();
        return _source = MonitorHttpDataSource(credential);
    }
  }

  /// Status polling via a `monitor` instance's HTTP API instead of SSH+shell
  /// (see `Spi.monitorHttp`). Deliberately does NOT fall back to SSH on
  /// failure — a misconfigured/unreachable monitor should surface as an
  /// error, not silently switch data sources.
  Future<void> _getDataMonitorHttp(
    MonitorHttpCredential monitor,
    int operation,
  ) async {
    final spi = state.spi;
    final sid = spi.id;

    if (!TryLimiter.canTry(sid)) {
      if (state.conn != ServerConn.failed) {
        updateConnection(ServerConn.failed);
      }
      return;
    }

    updateStatus(_copyStatus(state.status, err: null, setErr: true));
    if (state.conn < ServerConn.connecting) {
      updateConnection(ServerConn.connecting);
    }
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    final source = _resolveSource(
      ServerConnectCredentialMonitorHttp(spi: spi, monitor: monitor),
    );

    try {
      final status = await source.fetchStatus(_copyStatus(state.status));
      if (!_isRefreshCurrent(operation, spi)) return;
      updateStatus(status);
      // Alongside the status rather than once at connect: what the agent
      // allows is its own config, which can change under a running app, and
      // this poll is already authenticated and periodic. A failure here is
      // not a failure of the status — the app simply keeps the last answer,
      // or offers nothing until there is one.
      if (source is MonitorHttpDataSource) {
        try {
          final caps = await source.fetchCapabilities();
          // The server may have been edited while this was in flight, in which
          // case this answer describes the agent it used to point at — and the
          // platform it reports decides which script gets installed.
          if (!_isRefreshCurrent(operation, spi)) return;
          state = state.copyWith(remoteAccess: caps.remoteAccess);
          // The agent knows what it is running on. Over SSH this takes a
          // command and its output; here it arrives with the answer the app
          // was already asking for, and it decides which script gets
          // installed on the machine.
          final platform = caps.platform;
          if (platform != null && state.status.system != platform) {
            // The script that was written is the other platform's, and the
            // command about to run it is this platform's.
            _scriptWritten = false;
            updateStatus(_copyStatus(state.status, system: platform));
          }
        } catch (e, s) {
          Loggers.app.warning('Ask ${spi.name} what it allows', e, s);
        }
      }
      if (!_isRefreshCurrent(operation, spi)) return;
      updateConnection(ServerConn.finished);
      TryLimiter.reset(sid);
    } catch (e, s) {
      Loggers.app.warning(
        'Get status via monitor for ${spi.name} failed',
        e,
        s,
      );
      // A failure belongs to the server it was fetched for. Edit a server's
      // address and the poll still running against the old one eventually
      // times out; without this it counted that timeout against the retry
      // limiter and marked the server failed — overwriting the answer the
      // corrected address had already produced, so a fixed server went back
      // to looking broken a few seconds later.
      if (!_isRefreshCurrent(operation, spi)) return;
      TryLimiter.inc(sid);
      final err = e is MonitorHttpErr
          ? e
          : MonitorHttpErr(
              type: MonitorHttpErrType.unknown,
              message: e.toString(),
            );
      _setFailedState(_copyStatus(state.status, err: err, setErr: true));
    }
  }

  /// Prefills [ServerStatus.history] from whatever trend data the source
  /// already holds, so a freshly opened detail page shows a trend instead of
  /// building one up from scratch. A no-op for sources without
  /// [ServerCapabilities.storedHistory], and once live samples exist — see
  /// [StatusHistory.seed].
  Future<void> seedHistory({int minutes = 60}) async {
    final generation = _operationGeneration;
    final spi = state.spi;
    // Whichever transport *has* history, not whichever leads. On a server
    // carrying both, SSH usually leads and has none — so asking only the
    // leading one meant `capabilities.storedHistory` advertised a trend the
    // page then never seeded, and the chart built up from empty exactly where
    // an agent had months of it.
    final credential = _historyCredential(spi);
    if (credential == null) return;
    try {
      // Asking for exactly what the buffer holds. Any more is averaged down
      // on the agent's side instead of being carried here and dropped by
      // [StatusHistory.seed] as it walks past the capacity.
      final samples = await _resolveSource(credential).fetchHistory(
        minutes: minutes,
        maxPoints: StatusHistory.capacity,
      );
      if (!_isRefreshCurrent(generation, spi)) return;
      if (samples.isEmpty) return;
      state.status.history.seed(samples);
      // history is mutated in place, so hand out a fresh ServerStatus to make
      // the watchers rebuild
      updateStatus(_copyStatus(state.status));
    } catch (e, s) {
      if (!_isRefreshCurrent(generation, spi)) return;
      Loggers.app.warning('Seed history for ${spi.name}', e, s);
    }
  }

  /// The way in that keeps its own trend data, or null when neither does.
  ServerConnectCredential? _historyCredential(Spi spi) {
    final primary = ServerConnectCredential.fromSpi(spi);
    if (ServerCapabilities.of(primary).storedHistory) return primary;
    final fallback = ServerConnectCredential.fallbackOf(spi);
    if (fallback != null && ServerCapabilities.of(fallback).storedHistory) {
      return fallback;
    }
    return null;
  }

  String get _sshSessionId => 'ssh_${state.spi.id}';

  /// Retry-limiter key for connecting the shell, kept apart from the one the
  /// status poll uses.
  ///
  /// Opening a shell and polling status are separate failure domains, and a
  /// shell is opened long after the poll that established the server is
  /// reachable. Sharing one key meant a host whose sshd refuses would burn the
  /// limiter and stop the status page from refreshing too.
  String get _shellTryId => '${state.spi.id}#shell';

  /// Something that can run a command on this server.
  ///
  /// The one place that decides *how* a command reaches a server. Callers —
  /// the process list, services, containers, snippets, power control —
  /// take a [ServerExec] and never learn which transport answered, which is
  /// what keeps a second transport from being a condition inside each of
  /// them.
  ///
  /// A server with only an agent runs its commands through it, never through
  /// sshd: the agent is how that server is reachable at all, and reaching for
  /// SSH would mean asking for credentials the user chose not to give this
  /// app. A server carrying both falls through to the other on failure.
  ///
  /// Throws whatever the transport throws when it cannot be reached.
  Future<ServerExec> ensureExec() async {
    final spi = state.spi;
    final fallbackExists = spi.fallbackTransport != null;
    try {
      return await _execOver(
        ServerConnectCredential.fromSpi(spi),
        // Only when there is somewhere to fall through to. Handing back a
        // `MonitorExec` costs no request, so a dead agent is not discovered
        // until the *caller's* command runs — outside the catch below, and too
        // late to retry, since a command is not safe to run twice. One cheap
        // authenticated request makes that failure land here instead. The
        // agent-only case pays nothing: there is nothing to fall back to, so
        // the caller's own error is the answer either way.
        probe: fallbackExists,
      );
    } catch (e, s) {
      // Only a server the user gave *both* sets of credentials to has one of
      // these, and giving both is the request: reach this machine either way.
      // Refusing to use the second because the first was asked for first would
      // be honouring an ordering preference as though it were an exclusion.
      final fallback = ServerConnectCredential.fallbackOf(spi);
      if (fallback == null) rethrow;
      Loggers.app.info(
        'Exec over ${spi.transport.name} for ${spi.name} failed, '
        'falling back to ${spi.fallbackTransport?.name}',
        e,
        s,
      );
      return await _execOver(fallback);
    }
  }

  Future<ServerExec> _execOver(
    ServerConnectCredential credential, {
    bool probe = false,
  }) async {
    switch (credential) {
      case ServerConnectCredentialSsh():
        // Connecting *is* the probe here, and it always happens.
        return SshExec(await ensureShellClient());
      case ServerConnectCredentialMonitorHttp():
        final source = _resolveSource(credential);
        if (source is! MonitorHttpDataSource) {
          throw StateError(
            'A monitor credential resolved to a ${source.runtimeType}',
          );
        }
        // A GET the agent answers only to an authenticated caller, so it
        // covers both halves of "can this reach the machine": the agent is up,
        // and the login still works. Never the caller's command — that is what
        // must not be attempted twice.
        if (probe) await source.fetchCapabilities();
        return source.exec;
    }
  }

  bool isExecCurrent(ServerExec exec, Spi spi) {
    if (state.spi != spi) return false;
    if (exec is SshExec) {
      return identical(state.client, exec.client) && !exec.client.isClosed;
    }
    if (exec is MonitorExec) {
      final current = _source;
      final currentExec = current is MonitorHttpDataSource
          ? current.exec
          : null;
      return currentExec is MonitorExec &&
          identical(currentExec.client, exec.client);
    }
    return false;
  }

  /// Whether the generated script has been written to this server since the
  /// last time it was reachable.
  ///
  /// Not persisted: the script carries the app's build number, and a relaunch
  /// is exactly when it may need rewriting. Cleared whenever the server drops
  /// out, which is what covers a machine that rebooted and took `/tmp` with
  /// it — the script is gone and nothing else would notice, since a monitor
  /// server's status never reads it.
  bool _scriptWritten = false;

  /// Moves custom commands the app still holds locally onto the server, once.
  ///
  /// The server's directory is where they live now; this only exists to empty
  /// the old field, and does nothing for a server that has already been
  /// connected to since. Whatever is already on the server wins on a name
  /// collision, and the local extras are appended — nothing is dropped and the
  /// result does not depend on which side ran first.
  ///
  /// The local copy is cleared only after the install succeeds, so a failure
  /// here costs a retry rather than the commands. Failures are logged, not
  /// raised: a server whose status works and whose commands did not migrate is
  /// still a server worth showing.
  // TODO(migration): delete with [ServerCustom.cmds].
  Future<void> _migrateCustomCmds(
    Spi spi,
    SystemType system,
    ServerExec exec,
  ) async {
    final local = spi.custom?.cmds;
    if (local == null || local.isEmpty) return;

    try {
      final entry = ShellFuncManager.customCmdsEntry(system);
      final listing = await exec.run(
        ShellFuncManager.readCustomCmds(systemType: system),
        entry: entry,
      );
      if (!listing.succeeded) {
        throw 'read exited with ${listing.exitCode}: ${listing.combined}';
      }
      final onServer = ShellFuncManager.parseCustomCmds(listing.stdout);
      final existing = onServer?.map((c) => c.name).toSet() ?? const <String>{};
      final merged = [
        ...?onServer,
        for (final e in local.entries)
          if (!existing.contains(e.key))
            ffi.CustomCmd(name: e.key, cmd: e.value),
      ];

      // Reading the listing is an await, and an edit or a disconnect during it
      // leaves `exec` pointing at the host this started on. The check below
      // guards the database write; this one guards the write to the *server*,
      // which is the one that cannot be taken back.
      if (!isExecCurrent(exec, spi)) return;

      final install = await exec.run(
        ShellFuncManager.installCustomCmds(merged, systemType: system),
        entry: entry,
      );
      if (!install.succeeded) {
        throw 'install exited with ${install.exitCode}: ${install.combined}';
      }

      final custom = spi.custom;
      if (custom == null) return;
      // Don't overwrite newer edits that happened while we were reading/installing.
      final current = ref.read(serversProvider).servers[spi.id];
      if (current == null || current != spi) return;
      await ref
          .read(serversProvider.notifier)
          .updateServer(
            current,
            current.copyWith(custom: custom.withoutCmds()),
          );
      Loggers.app.info(
        'Migrated ${local.length} custom command(s) for ${spi.name}',
      );
    } catch (e, st) {
      Loggers.app.warning('Custom commands for ${spi.name}', e, st);
    }
  }

  /// A [ServerExec] with the generated script present on the server.
  ///
  /// What the process list wants, rather than plain [ensureExec]: it runs one
  /// of the script's functions, and the script only gets there because
  /// something put it there. The SSH status flow writes it while fetching and
  /// says so through [_scriptWritten]; a monitor server's status arrives as
  /// JSON and never touches the machine, so nothing has written it yet.
  ///
  /// Asked of the flag rather than of the transport: an SSH client can exist
  /// without a status fetch ever having run — the SFTP button and the AI agent
  /// tool both open one — and assuming otherwise runs a script that is not
  /// there.
  ///
  /// Throws when the script cannot be written, since the alternative is a page
  /// reporting an empty list on a server that has plenty of processes.
  Future<ServerExec> ensureScriptExec() async {
    final exec = await ensureExec();
    final gen = _operationGeneration;
    final origSpi = state.spi;
    if (_scriptWritten) {
      final spi = state.spi;
      if (spi.custom?.cmds?.isNotEmpty == true &&
          gen == _operationGeneration &&
          origSpi == spi) {
        try {
          await _migrateCustomCmds(spi, state.status.system, exec);
        } catch (_) {}
      }
      return exec;
    }

    final spi = state.spi;
    final system = state.status.system;
    final result = await exec.run(
      ShellFuncManager.installPayload(
        ShellFuncManager.allScript(
          systemType: system,
          disabledCmdTypes: spi.disabledCmdTypes,
        ),
        systemType: system,
      ),
      // The same shape the SSH path uses: the install command reads the script
      // on stdin, so its content never has to survive shell quoting.
      entry: ShellFuncManager.getInstallShellCmd(
        spi.id,
        systemType: system,
        customDir: spi.custom?.scriptDir,
      ),
    );
    if (!result.succeeded) {
      // The same fallback the SSH path takes: the default directory may be
      // read-only or mounted `noexec`, and the next attempt should try the
      // other one rather than the one that just failed. Skipped when the user
      // named a directory — that one is their decision, not ours to move.
      if (spi.custom?.scriptDir == null) {
        ShellFuncManager.switchScriptDir(spi.id, systemType: system);
      }
      // `SSHErrType.writeScript` names a transport this did not necessarily
      // use, but it is the app's existing name for this failure and carries
      // the advice that fits it.
      throw SSHErr(
        type: SSHErrType.writeScript,
        message: 'Write script to ${spi.name}: ${result.combined}',
      );
    }
    // A monitor-only server reaches this path too, which is the point: what
    // carries the commands is `ServerExec`, not SSH, so both kinds of server
    // reach the same directory.
    if (gen == _operationGeneration && origSpi == state.spi) {
      await _migrateCustomCmds(spi, system, exec);
      _scriptWritten = true;
    }
    return exec;
  }

  /// The [SSHClient] for this server, connecting on first use.
  ///
  /// The SSH path already holds a client from its connect-and-fetch flow, so
  /// this returns that one.
  ///
  /// Throws [SSHErr] when the server has no SSH configuration, or when the
  /// retry limiter has given up on it.
  Future<SSHClient> ensureShellClient() async {
    final existing = state.client;
    if (existing != null && !existing.isClosed) return existing;

    final spi = state.spi;
    final gen = _operationGeneration;
    final origSpi = spi;
    if (spi.ssh == null) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'No SSH credential configured for ${spi.name}',
      );
    }
    if (!TryLimiter.canTry(_shellTryId)) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'Reconnect limit reached for ${spi.name}',
      );
    }

    // Held so the `catch` can close it. Authentication is awaited before
    // `_setClient`, so a failure there would otherwise leak a connected client
    // that nothing holds a reference to.
    SSHClient? client;
    try {
      client = await genClient(
        spi,
        timeout: _timeout,
        onKeyboardInteractive: KeyboardInteractiveAuth.handle,
      );
      await client.authenticated;
      // Checked after, as every await in the refresh paths already does.
      // Authenticating takes as long as the far side and the user take, and
      // editing the server or disconnecting it bumps the generation — so
      // without this the client that eventually arrived was installed into the
      // state of a server that is now somewhere else, and the next caller ran
      // its commands on the old host.
      if (!_isRefreshCurrent(gen, origSpi)) {
        try {
          client.close();
        } catch (_) {}
        throw StateError('superseded shell connect for ${origSpi.name}');
      }
      TryLimiter.reset(_shellTryId);
      _setClient(client);
      return client;
    } catch (e, s) {
      // Authentication is awaited before _setClient, so a failure would leak
      // the newly created client if we only close state.client.
      if (client != null) {
        try {
          client.close();
        } catch (_) {}
      }
      // Not counted when it is this server that moved: the limiter is keyed on
      // an id an edit keeps, so charging a superseded attempt to it would stop
      // the *corrected* server reconnecting. `_failSsh` skips it for the same
      // reason.
      if (!_isRefreshCurrent(gen, origSpi)) {
        Loggers.app.info('Discarded superseded shell connect for ${spi.name}');
        rethrow;
      }
      TryLimiter.inc(_shellTryId);
      Loggers.app.warning('Connect shell for ${spi.name}', e, s);
      rethrow;
    }
  }

  /// The failure ritual every SSH branch repeated: count the attempt against
  /// the retry limiter, record the error on the status, drop to `failed`, and
  /// mark the terminal session dead. Nine copies of it made the actual control
  /// flow of `_getDataSsh` hard to see, and each copy was a chance to forget
  /// one of the four steps.
  ///
  /// [countAttempt] is false for the one case that must not burn a retry:
  /// a connection that only failed because keyboard-interactive auth needed a
  /// prompt this non-interactive refresh could not show.
  ///
  /// [operation] is checked here rather than at each call site: a `catch` is
  /// reached by throwing out of an `await`, so it skips whatever currency
  /// check follows that await. Edit a server's address and the connection
  /// still being attempted against the old one eventually fails; without this
  /// it counted against the retry limiter and marked the server failed,
  /// undoing the refresh the corrected address had already completed.
  void _failSsh(
    SSHErrType type,
    Object e, {
    required int operation,
    bool closeClient = false,
    bool countAttempt = true,
    String? message,
  }) {
    if (!_isRefreshCurrent(operation, state.spi)) {
      Loggers.app.info('SSH ${state.spi.name}: dropping a superseded failure');
      return;
    }
    if (countAttempt) TryLimiter.inc(state.spi.id);
    final err = SSHErr(type: type, message: message ?? e.toString());
    _setFailedState(
      _copyStatus(state.status, err: err, setErr: true),
      closeClient: closeClient,
    );
    TermSessionManager.updateStatus(
      _sshSessionId,
      TermSessionStatus.disconnected,
    );
    Loggers.app.warning('SSH ${state.spi.name}', err);
  }

  Future<void> _getDataSsh({
    required bool interactive,
    required int operation,
  }) async {
    final spi = state.spi;
    final sid = spi.id;
    var keyboardInteractiveRequested = false;

    if (!TryLimiter.canTry(sid)) {
      if (state.conn != ServerConn.failed) {
        updateConnection(ServerConn.failed);
      }
      return;
    }

    final newStatus = _copyStatus(
      state.status,
      err: null,
      setErr: true,
    ); // Clear previous error
    updateStatus(newStatus);

    if (state.conn < ServerConn.connecting ||
        (state.client?.isClosed ?? true)) {
      updateConnection(ServerConn.connecting);

      // Wake on LAN
      final wol = spi.wolCfg;
      if (wol != null) {
        try {
          await wol.wake();
          if (!_isRefreshCurrent(operation, spi)) return;
        } catch (e) {
          Loggers.app.warning('Wake on lan failed', e);
        }
        if (!_isRefreshCurrent(operation, spi)) return;
      }

      final time1 = DateTime.now();
      try {
        final client = await genClient(
          spi,
          timeout: _timeout,
          onKeyboardInteractive: (server, request) {
            keyboardInteractiveRequested = true;
            if (!interactive) return null;
            return KeyboardInteractiveAuth.handle(server, request);
          },
        );
        await client.authenticated;
        if (!_isRefreshCurrent(operation, spi)) {
          client.close();
          return;
        }
        _setClient(client);

        final time2 = DateTime.now();
        final spentTime = time2.difference(time1).inMilliseconds;
        if (spi.resolvedJumpIds.isEmpty) {
          Loggers.app.info('Connected to ${spi.name} in $spentTime ms.');
        } else {
          Loggers.app.info('Jump to ${spi.name} in $spentTime ms.');
        }

        try {
          await Stores.connectionStats.recordConnection(
            ConnectionStat(
              serverId: spi.id,
              serverName: spi.name,
              timestamp: time1,
              result: ConnectionResult.success,
              durationMs: spentTime,
            ),
          );
        } catch (e) {
          Loggers.app.warning('Failed to record connection success', e);
        }
        if (!_isRefreshCurrent(operation, spi)) return;

        final sessionId = 'ssh_${spi.id}';
        TermSessionManager.add(
          id: sessionId,
          title: spi.name,
          subtitle: spi.oldId,
          startTimeMs: time1.millisecondsSinceEpoch,
          disconnect: () =>
              ref.read(serversProvider.notifier).closeOneServer(spi.id),
          status: TermSessionStatus.connecting,
          setAsActive: false,
        );
        TermSessionManager.setActive(sessionId, hasTerminal: false);
      } catch (e) {
        if (!_isRefreshCurrent(operation, spi)) return;
        if (!keyboardInteractiveRequested || interactive) {
          TryLimiter.inc(sid);
        }

        final durationMs = DateTime.now().difference(time1).inMilliseconds;

        ConnectionResult failureResult;
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('timed out') || errStr.contains('timeout')) {
          failureResult = ConnectionResult.timeout;
        } else if (errStr.contains('auth') ||
            errStr.contains('authentication') ||
            errStr.contains('permission denied') ||
            errStr.contains('access denied')) {
          failureResult = ConnectionResult.authFailed;
        } else if (errStr.contains('connection refused') ||
            errStr.contains('no route to host') ||
            errStr.contains('network') ||
            errStr.contains('socket')) {
          failureResult = ConnectionResult.networkError;
        } else {
          failureResult = ConnectionResult.unknownError;
        }

        try {
          await Stores.connectionStats.recordConnection(
            ConnectionStat(
              serverId: spi.id,
              serverName: spi.name,
              timestamp: time1,
              result: failureResult,
              errorMessage: e.toString(),
              durationMs: durationMs,
            ),
          );
        } catch (recErr) {
          Loggers.app.warning('Failed to record connection failure', recErr);
        }
        if (!_isRefreshCurrent(operation, spi)) return;

        final SSHErrType errType;
        if (keyboardInteractiveRequested && !interactive) {
          errType = SSHErrType.interactiveAuth;
        } else if (e is SSHAuthError) {
          errType = SSHErrType.auth;
        } else {
          errType = SSHErrType.connect;
        }
        _setFailedState(
          _copyStatus(
            state.status,
            err: SSHErr(type: errType, message: e.toString()),
            setErr: true,
          ),
          closeClient: true,
        );
        // Removed, not just marked dead: there is no session to reconnect to
        TermSessionManager.remove(_sshSessionId);
        Loggers.app.warning('Connect to ${spi.name} failed', e);
        return;
      }

      updateConnection(ServerConn.connected);

      // Update SSH session status to connected
      final sessionId = 'ssh_${spi.id}';
      TermSessionManager.updateStatus(sessionId, TermSessionStatus.connected);

      try {
        // Detect system type
        final detectedSystemType = await SystemDetector.detect(
          state.client!,
          spi,
        );
        if (!_isRefreshCurrent(operation, spi)) return;
        final newStatus = _copyStatus(state.status, system: detectedSystemType);
        updateStatus(newStatus);

        Loggers.app.info(
          'Writing script for ${spi.name} (${detectedSystemType.name})',
        );

        final writeScriptResult = await state.client!.execSafe(
          (session) async {
            final scriptRaw = ShellFuncManager.installPayload(
              ShellFuncManager.allScript(
                systemType: detectedSystemType,
                disabledCmdTypes: spi.disabledCmdTypes,
              ),
              systemType: detectedSystemType,
            ).uint8List;
            session.stdin.add(scriptRaw);
            session.stdin.close();
          },
          entry: ShellFuncManager.getInstallShellCmd(
            spi.id,
            systemType: detectedSystemType,
            customDir: spi.custom?.scriptDir,
          ),
          systemType: detectedSystemType,
          context: 'WriteScript<${spi.name}>',
        );
        if (!_isRefreshCurrent(operation, spi)) return;

        if (writeScriptResult.stdout.isNotEmpty) {
          Loggers.app.info(
            'Script write stdout for ${spi.name}: ${writeScriptResult.stdout}',
          );
        }

        // The commands themselves live in their own directory and are written
        // separately: the script changes when the app does, they when the user
        // does, and neither has to reinstall the other.
        await _migrateCustomCmds(
          spi,
          detectedSystemType,
          SshExec(state.client!),
        );

        if (writeScriptResult.stderr.isNotEmpty) {
          Loggers.app.warning(
            'Script write stderr for ${spi.name}: ${writeScriptResult.stderr}',
          );
        }

        if (!writeScriptResult.succeeded) {
          if (spi.custom?.scriptDir == null) {
            ShellFuncManager.switchScriptDir(
              spi.id,
              systemType: detectedSystemType,
            );
          }
          final output = writeScriptResult.stderr.isNotEmpty
              ? writeScriptResult.stderr
              : writeScriptResult.stdout;
          throw 'Script installation exited with code '
              '${writeScriptResult.exitCode}: $output';
        } else {
          Loggers.app.info('Script written successfully for ${spi.name}');
          _scriptWritten = true;
        }
      } on SSHAuthAbortError catch (e) {
        _failSsh(SSHErrType.auth, e, operation: operation, closeClient: true);
        return;
      } on SSHAuthFailError catch (e) {
        _failSsh(SSHErrType.auth, e, operation: operation, closeClient: true);
        return;
      } catch (e) {
        _failSsh(
          SSHErrType.writeScript,
          e,
          operation: operation,
          closeClient: true,
        );
        return;
      }
    }

    if (state.conn == ServerConn.connecting) return;

    // Keep finished status to prevent UI from refreshing to loading state
    if (state.conn != ServerConn.finished) {
      updateConnection(ServerConn.loading);
    }

    String? raw;

    try {
      final statusCmd = ShellFunc.status.exec(
        spi.id,
        systemType: state.status.system,
        customDir: spi.custom?.scriptDir,
      );
      raw = await _runStatusCommand(statusCmd);
      if (!_isRefreshCurrent(operation, spi)) return;

      // Output carrying no segment marker parses into an empty status: the
      // page keeps whatever its rolling state still holds (cpu, net speeds)
      // and blanks the rest, with nothing saying why. It is what a host
      // answers once the script is gone from under it — the default script
      // directory is /tmp — so it is reported as a failure, which puts the
      // connection back through the connect path and reinstalls the script.
      //
      // Was `raw.split(separator).isEmpty`, which `String.split` never
      // returns: unparseable output reached the parser as if it were fine.
      //
      // Custom commands carry their own separator, and with every built-in
      // command disabled they are the only output there is.
      //
      // Empty output is only a failure if the server was asked for anything.
      // A host with every status command disabled legitimately returns nothing.
      final hasSegment = ffi.containsScriptSegment(raw: raw);
      if (!hasSegment && _hasEnabledStatusCommands(spi, state.status.system)) {
        if (Stores.setting.keepStatusWhenErr.fetch()) {
          // Keep previous server status when error occurs
          if (state.conn != ServerConn.failed && state.status.more.isNotEmpty) {
            return;
          }
        }
        _failSsh(
          SSHErrType.segments,
          '',
          operation: operation,
          message: raw.isEmpty
              ? 'Empty response from server'
              : 'No status segments in response, raw:\n$raw',
        );
        return;
      }
    } on TimeoutException catch (e, s) {
      Loggers.app.warning('Get status from ${spi.name} timed out', e, s);
      // Reached by throwing out of an await, so it skips the check that
      // follows that await: a read that timed out against the address this
      // server used to have must not stamp its error onto the one it has now.
      if (!_isRefreshCurrent(operation, spi)) return;
      // Not _failSsh: a timed-out status read leaves the connection itself
      // intact, so the session stays connected and the attempt isn't counted
      updateStatus(
        _copyStatus(
          state.status,
          err: SSHErr(type: SSHErrType.getStatus, message: e.toString()),
          setErr: true,
        ),
      );
      if (state.client != null && state.conn != ServerConn.finished) {
        updateConnection(ServerConn.connected);
      }
      TermSessionManager.updateStatus(
        _sshSessionId,
        TermSessionStatus.connected,
      );
      return;
    } catch (e) {
      _failSsh(SSHErrType.getStatus, e, operation: operation);
      return;
    }

    try {
      // Segments the status function no longer carries, refreshed on their own
      // schedule and concatenated here: the parser splits by separator, so one
      // combined output parses exactly as the two runs would have
      final extended = await _refreshExtendedRaw(
        force: interactive,
        operation: operation,
      );
      // Built-in markers are trusted only before the first custom section;
      // custom output may contain marker-looking text. Extended status has no
      // custom commands, so put it first and leave custom output last.
      final combined = extended.isEmpty ? raw : '$extended\n$raw';

      // Same conversion contract as the monitor path: raw transport output in,
      // ServerStatus (plus a trend sample) out
      final source = SshDataSource(spi: spi, runScript: () async => combined);
      final status = await source.fetchStatus(_copyStatus(state.status));
      // The last two awaits are the longest in this method — the extended
      // commands take seconds by design. A refresh that started before the
      // server was edited arrives here holding the old host's status.
      if (!_isRefreshCurrent(operation, spi)) return;
      updateStatus(status);
    } catch (e, trace) {
      _failSsh(
        SSHErrType.getStatus,
        e,
        operation: operation,
        message: 'Parse failed: $e\n\n$raw',
      );
      Loggers.app.warning('Server status', e, trace);
      return;
    }

    if (!_isRefreshCurrent(operation, spi)) return;
    // Set Server.isBusy to false each time this method is called
    updateConnection(ServerConn.finished);
    // Reset retry count only after successful preparation
    TryLimiter.reset(sid);
  }

  /// Runs [ShellFunc.statusExt] when [_extendedStatusInterval] has elapsed
  /// (or [force], for a user-initiated refresh) and returns its output,
  /// falling back to the last successful one.
  ///
  /// Deliberately on the exec path rather than the persistent shell: these
  /// commands can take seconds, and a timeout there would drop the whole
  /// connection to exec for good (see [_runStatusCommand]).
  Future<String> _refreshExtendedRaw({
    required bool force,
    required int operation,
  }) async {
    final fetchedAt = _extendedFetchedAt;
    final due =
        force ||
        fetchedAt == null ||
        DateTime.now().difference(fetchedAt) >= _extendedStatusInterval;
    final client = state.client;
    if (!due || client == null) return _extendedRaw;

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
      final raw = await _runStatusCommandWithExec(
        client,
        cmd,
        isWindows: state.status.system == SystemType.windows,
      );
      // The cache belongs to the notifier, not to this run: without the check
      // a refresh against the address the server used to have would leave the
      // old machine's SMART and GPU segments here, and the next poll of the
      // *new* one would find them still within the interval and merge them
      // into its status.
      if (!_isRefreshCurrent(operation, spi)) return _extendedRaw;
      if (ffi.containsStatusSegment(raw: raw)) _extendedRaw = raw;
    } catch (e, s) {
      Loggers.app.warning('Extended status for ${spi.name} failed', e, s);
    }
    return _extendedRaw;
  }

  Future<String> _runStatusCommand(String statusCmd) async {
    final client = state.client;
    final spi = state.spi;

    if (client == null) {
      Loggers.app.warning(
        'Client for ${spi.name} is null, skipping status fetch',
      );
      return '';
    }

    if (state.status.system == SystemType.windows) {
      return _runStatusCommandWithExec(client, statusCmd, isWindows: true);
    }

    if (!_usePersistentShellForStatus) {
      return _runStatusCommandWithExec(client, statusCmd);
    }

    try {
      final shell = await _getPersistentShell();
      final result = await shell.run(statusCmd, timeout: _timeout);
      return result.output;
    } on TimeoutException catch (e, s) {
      _usePersistentShellForStatus = false;
      await _disposePersistentShell();
      Loggers.app.warning(
        'Persistent shell status command timed out for ${spi.name}; fallback to exec for this connection',
        e,
        s,
      );
      return _runStatusCommandWithExec(client, statusCmd);
    }
  }

  bool _hasEnabledStatusCommands(Spi spi, SystemType system) {
    if (spi.custom?.cmds?.isNotEmpty == true) return true;
    final disabled = spi.disabledCmdTypes?.toSet() ?? const <String>{};
    final Iterable<ShellCmdType> commands = switch (system) {
      SystemType.linux => StatusCmdType.values,
      SystemType.bsd => BSDStatusCmdType.values,
      SystemType.windows => WindowsStatusCmdType.values,
    };
    return commands.any((command) => !disabled.contains(command.displayName));
  }

  Future<String> _runStatusCommandWithExec(
    SSHClient client,
    String statusCmd, {
    bool isWindows = false,
  }) async {
    final spi = state.spi;
    final execResult = await client
        .run(statusCmd)
        .timeout(const Duration(seconds: 30));
    return SSHDecoder.decode(
      execResult,
      isWindows: isWindows,
      context: 'GetStatus<${spi.name}>',
    );
  }

  Future<PersistentShell> _getPersistentShell() async {
    final client = state.client;
    if (client == null) {
      throw StateError('SSH client is not connected');
    }

    final shell = _persistentShell;
    if (shell != null) {
      return shell;
    }

    final newShell = PersistentShell(client);
    _persistentShell = newShell;
    return newShell;
  }

  Future<void> _disposePersistentShell() async {
    final shell = _persistentShell;
    _persistentShell = null;
    await shell?.close();
  }
}

extension IndividualServerStateExtension on ServerState {
  bool get canViewDetails => conn == ServerConn.finished;

  String get id => spi.id;
}

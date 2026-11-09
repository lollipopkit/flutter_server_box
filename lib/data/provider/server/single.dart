import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/scheduler.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/local/server.dart';
import 'package:server_box/core/monitor/exec.dart';
import 'package:server_box/core/ssh/auth.dart';
import 'package:server_box/core/ssh/client.dart';
import 'package:server_box/core/ssh/decoder.dart';
import 'package:server_box/core/ssh/exec.dart';
import 'package:server_box/core/ssh/system_detector.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/connection_stat.dart';
import 'package:server_box/data/model/server/monitor/monitor_access.dart';
import 'package:server_box/data/model/server/monitor/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/status/cpu.dart';
import 'package:server_box/data/model/server/status/disk.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
import 'package:server_box/data/model/server/status/status_history.dart';
import 'package:server_box/data/model/server/status/temp.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/monitor_http_source.dart';
import 'package:server_box/data/provider/server/script_source.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/terminal/persistent_shell.dart';
import 'package:server_box/data/terminal/session_manager.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

part 'single.g.dart';
part 'single.freezed.dart';
part 'single_history.dart';
part 'single_local.dart';
part 'single_monitor.dart';
part 'single_script.dart';
part 'single_ssh.dart';

@freezed
abstract class ServerState with _$ServerState {
  const factory ServerState({
    required Spi spi,
    required ServerStatus status,
    @Default(ServerConn.disconnected) ServerConn conn,

    /// How long the last successful status read took, in milliseconds.
    ///
    /// The read, not the connect: a handshake happens once and then never
    /// again, so showing it would pin a number taken minutes ago — and over a
    /// jump chain it measures the whole chain rather than this server.
    ///
    /// What the read *is* differs by transport, and the two figures are not
    /// interchangeable. Over SSH it is the status script running on the
    /// machine, so it carries that machine's load as well as the network; over
    /// a monitor agent it is one HTTP request for a sample the agent had
    /// already taken, so it carries little but the network. A server reachable
    /// both ways reports whichever transport led that poll. What neither
    /// includes is the work of turning the answer into a [ServerStatus], which
    /// happens on the isolate drawing frames and is not the machine's doing.
    ///
    /// Null when there has been no successful read since the server was last
    /// reachable. Every path that gives up on a connection clears it, and so
    /// does publishing a status that carries an error, because a latency left
    /// behind reads as a live measurement of a machine that is no longer
    /// answering — and survives an edit pointing the server at a different
    /// host.
    int? latencyMs,
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
    MonitorAccess? agentAccess,

    /// The agent's version, as it reported it, or null for a server with no
    /// agent — and for an agent built before it said so.
    String? agentVersion,

    /// What the agent said it can answer for: how long it keeps readings and
    /// the oldest one it still has.
    ///
    /// What a window picker may offer is this, rather than a list of fixed
    /// windows the app decided on: an agent keeping three days and one keeping
    /// ninety are both ordinary, and offering "30 d" to the first draws an
    /// empty chart and calls it a machine that was idle.
    MonitorCapabilities? agentCapabilities,
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
      ServerCapabilities.ofSpi(spi, granted: agentAccess);

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

/// What the status mixins (`single_*.dart`) take from [ServerNotifier]: the
/// connection state and the generation every refresh checks against.
mixin _ServerCore on _$ServerNotifier {
  /// The status connection's entry in [TermSessionManager].
  String get _statusSessionId => TermSessionManager.statusSessionId(state.spi.id);

  int get _operationGeneration;
  Duration get _timeout;
  bool _isRefreshCurrent(int operation, Spi spi);
  bool _beginRefresh(Spi spi);
  void updateConnection(ServerConn conn);
  void updateStatus(ServerStatus status, {int? latencyMs});
  ServerStatus _copyStatus(
    ServerStatus source, {
    Err? err,
    bool setErr = false,
    SystemType? system,
  });
  void _setClient(SSHClient? client);
  void _setFailedState(ServerStatus status, {bool closeClient = false});
  Future<CommandExec> ensureScriptExec({VoidCallback? onSshDial});
}

@Riverpod(keepAlive: true)
class ServerNotifier extends _$ServerNotifier
    with
        _ServerCore,
        _ScriptStatus,
        _MonitorStatus,
        _History,
        _LocalStatus,
        _SshStatus {
  @override
  int _operationGeneration = 0;

  /// The SSH client this notifier owns, kept beside [state].
  ///
  /// The dispose listener cannot close it through [state]: it runs while the
  /// element is being invalidated, and reading the state then rebuilds the
  /// provider — a rebuild whose result no longer carries this client, so the
  /// connection was left open. Every path that installs or drops a client keeps
  /// this in step with [ServerState.client].
  SSHClient? _client;

  int _cachedTimeout = 5;

  @override
  ServerState build(String serverId) {
    ref.onDispose(() {
      // Supersedes whatever is in flight, so it ends at its next
      // [_isRefreshCurrent] — which compares this before reading `state`,
      // and reading `state` after disposal throws.
      _operationGeneration++;
      unawaited(_disposePersistentShell());
      _monitorSource?.close();
      try {
        _client?.close();
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
      // The server is gone — deleted, or removed by a sync pull — while this
      // notifier was still alive and something was still watching it. Riverpod
      // refreshes an *active* element after an invalidation, so the delete path
      // cannot avoid this rebuild; throwing here turned deleting a server into
      // an unhandled error and left this provider stuck in an error state for
      // every watcher still on screen.
      //
      // Keep what it last had instead: the record's readings, marked
      // disconnected. Nothing polls it again — `refresh` walks the servers that
      // still exist — and a restore that reuses the id is picked up by the
      // lookup above on the next rebuild.
      final last = stateOrNull;
      if (last == null) {
        throw StateError('Server $serverId not found');
      }
      return last.copyWith(
        conn: ServerConn.disconnected,
        client: null,
        latencyMs: null,
      );
    }

    return ServerState(spi: spi, status: InitStatus.status);
  }

  @override
  Duration get _timeout =>
      Duration(seconds: _cachedTimeout <= 0 ? 5 : _cachedTimeout);

  @override
  void updateConnection(ServerConn conn) {
    state = state.copyWith(conn: conn);
  }

  /// Update server status.
  ///
  /// [latencyMs] rides along rather than being published on its own: a status
  /// and the time it took to fetch are one answer, and two assignments to
  /// [state] are two rebuilds of every card watching this server.
  /// Null leaves the previous reading alone — most callers here are clearing
  /// an error rather than reporting a read.
  ///
  /// A [status] carrying an error drops it instead, whatever was passed. A
  /// read that errored is not a reading, and the paths that report one are not
  /// the paths that clear the connection: a status read that timed out leaves
  /// the session up, so nothing else was going to, and the last good figure
  /// sat in the About card beside the error that replaced it.
  @override
  void updateStatus(ServerStatus status, {int? latencyMs}) {
    state = state.copyWith(
      status: status,
      latencyMs: status.err != null ? null : (latencyMs ?? state.latencyMs),
    );
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

  @override
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
      diskSmartAt: source.diskSmartAt,
      err: setErr ? err : source.err,
      nvidia: source.nvidia?.toList(),
      gpus: source.gpus.toList(),
      // Shared, unlike the rolling values above. It is append-only, so a
      // reader never sees it torn, and copying three hundred samples across
      // ten series every refresh would buy nothing.
      history: source.history,
    );
    status.amd = source.amd?.toList();
    status.diskUsage = source.diskUsage;
    status.blockDevices = source.blockDevices;
    status.osId = source.osId;
    status.osIdLike = source.osIdLike;
    // Carried, for the reason the mappers do not clear it: it refreshes on the
    // extended cadence, so most rebuilds of this object happen on a poll that
    // said nothing about addresses.
    status.ips = source.ips;
    status.batteries.addAll(source.batteries);
    status.more.addAll(source.more);
    // Carried like `more`: a section that failed stays failed until the pass
    // that parses it again clears it, and most passes touch only some of them.
    status.sectionErrs.addAll(source.sectionErrs);
    status.sensors.addAll(source.sensors);
    status.customCmds.addAll(source.customCmds);
    return status;
  }

  @override
  void _setClient(SSHClient? client) {
    if (!identical(state.client, client)) {
      unawaited(_disposePersistentShell());
      _usePersistentShellForStatus = true;
      // A different connection may be to a machine that has been rebooted
      // since, and a reboot takes `/tmp` — where the script lives — with it.
      // The next refresh re-runs the extended function against the new script.
      _forgetInstalledScript(extended: true);
    }
    _client = client;
    state = state.copyWith(client: client);
  }

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

    if (rewrite) _forgetInstalledScript(extended: true);

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
    _client = null;
    _usePersistentShellForStatus = true;
    state = state.copyWith(
      spi: spi,
      client: null,
      conn: ServerConn.disconnected,
      // The edit may have pointed this server at another machine entirely.
      latencyMs: null,
      // Including at another agent, whose retention and oldest reading are
      // not this one's. Kept, they decide which windows the range picker
      // offers until the next capabilities fetch lands.
      agentCapabilities: null,
    );
  }

  @override
  void _setFailedState(ServerStatus status, {bool closeClient = false}) {
    final client = state.client;
    unawaited(_disposePersistentShell());
    // A server that went away may come back without what was on it: a reboot
    // clears `/tmp`, where the script lives by default.
    _forgetInstalledScript(extended: false);
    if (closeClient) {
      client?.close();
      _client = null;
    }
    state = state.copyWith(
      status: status,
      client: closeClient ? null : client,
      conn: ServerConn.failed,
      latencyMs: null,
    );
  }

  void closeConnection() {
    _operationGeneration++;
    unawaited(_disposePersistentShell());
    state.client?.close();
    _client = null;
    _forgetInstalledScript(extended: false);
    state = state.copyWith(
      client: null,
      conn: ServerConn.disconnected,
      latencyMs: null,
    );
  }

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
    // Alongside the first poll rather than after it: the card in the list
    // draws the same trend as the page, and built up from live samples alone
    // its first point waited for two agent cycles — rates need a pair.
    unawaited(seedHistory());
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
      await _refreshStatus(interactive: interactive, operation: operation);
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
  @override
  bool _isRefreshCurrent(int operation, Spi spi) =>
      operation == _operationGeneration && state.spi == spi;

  /// The start every transport's refresh shares: stop at the retry limit,
  /// otherwise clear the previous error. False when the refresh stops here.
  ///
  /// The move to `connecting` stays with each transport, since SSH connects
  /// inside that branch.
  @override
  bool _beginRefresh(Spi spi) {
    if (!TryLimiter.canTry(spi.id)) {
      if (state.conn != ServerConn.failed) {
        updateConnection(ServerConn.failed);
      }
      return false;
    }
    updateStatus(_copyStatus(state.status, err: null, setErr: true));
    return true;
  }

  /// [interactive] only reaches the SSH path: it gates prompting the user for
  /// keyboard-interactive auth, which has no counterpart over monitor's HTTP
  /// API (credentials there are configured up front, never prompted for).
  Future<void> _refreshStatus({
    required bool interactive,
    required int operation,
  }) async {
    switch (ServerConnectCredential.fromSpi(state.spi)) {
      case ServerConnectCredentialSsh():
        // Connecting is inseparable from fetching here (auth prompts, script
        // install, session bookkeeping), so the SSH path drives the state
        // machine itself and hands the reading half to ScriptDataSource
        await _refreshStatusSsh(interactive: interactive, operation: operation);
      case ServerConnectCredentialMonitorHttp(:final monitor):
        await _refreshStatusMonitorHttp(monitor, operation);
      case ServerConnectCredentialLocal():
        await _refreshStatusLocal(interactive: interactive, operation: operation);
    }
  }

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
  /// take a [CommandExec] and never learn which transport answered, which is
  /// what keeps a second transport from being a condition inside each of
  /// them.
  ///
  /// A server with only an agent runs its commands through it, never through
  /// sshd: the agent is how that server is reachable at all, and reaching for
  /// SSH would mean asking for credentials the user chose not to give this
  /// app. A server carrying both falls through to the other on failure.
  ///
  /// Throws whatever the transport throws when it cannot be reached.
  ///
  /// [onSshDial] runs at the moment this is about to open an SSH connection,
  /// and is how a caller that has somewhere to show one finds out — which
  /// transport *leads* does not answer that, because a server carrying both
  /// falls through to sshd when the agent does not reply. Not called when a
  /// client is already open, since nothing is dialled and nothing prompts.
  Future<CommandExec> ensureExec({VoidCallback? onSshDial}) async {
    final spi = state.spi;
    final fallbackExists = spi.fallbackTransport != null;
    try {
      return await _execOver(
        ServerConnectCredential.fromSpi(spi),
        onSshDial: onSshDial,
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
      return await _execOver(fallback, onSshDial: onSshDial);
    }
  }

  Future<CommandExec> _execOver(
    ServerConnectCredential credential, {
    bool probe = false,
    VoidCallback? onSshDial,
  }) async {
    switch (credential) {
      case ServerConnectCredentialSsh():
        // Connecting *is* the probe here, and it always happens.
        return SshExec(
          await ensureShellClient(onDial: onSshDial),
          sudoPassword: () => SudoPassword.known(state.spi.id),
        );
      case ServerConnectCredentialMonitorHttp():
        final source = _monitorSourceFor(credential);
        // A GET the agent answers only to an authenticated caller, so it
        // covers both halves of "can this reach the machine": the agent is up,
        // and the login still works. Never the caller's command — that is what
        // must not be attempted twice.
        if (probe) await source.capabilities();
        return source.exec;
      case ServerConnectCredentialLocal():
        if (!LocalServer.isSupported) {
          throw const LocalServerErr(type: LocalServerErrType.unsupported);
        }
        return LocalServer.exec();
    }
  }

  bool isExecCurrent(CommandExec exec, Spi spi) {
    if (state.spi != spi) return false;
    if (exec is SshExec) {
      return identical(state.client, exec.client) && !exec.client.isClosed;
    }
    if (exec is MonitorExec) {
      final currentExec = _monitorSource?.exec;
      return currentExec is MonitorExec &&
          identical(currentExec.client, exec.client);
    }
    // Nothing is held open, so the only way one stops being current is the
    // server stopping being this device — which the check above already saw.
    if (exec is ProcessExec) return spi.local;
    return false;
  }

  /// A [CommandExec] with the generated script present on the server.
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
  /// Throws a [ScriptErr] when the script cannot be written, since the
  /// alternative is a page reporting an empty list on a server that has plenty
  /// of processes. [onSshDial] as for [ensureExec].
  @override
  Future<CommandExec> ensureScriptExec({VoidCallback? onSshDial}) async {
    // Before the connect: a server edited or reconnected while it is pending
    // must not have this one's script written for it.
    final gen = _operationGeneration;
    final origSpi = state.spi;
    final exec = await ensureExec(onSshDial: onSshDial);
    if (_scriptWritten) return exec;

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
      throw ScriptErr(
        type: ScriptErrType.writeScript,
        message: 'Write script to ${spi.name}: ${result.combined}',
      );
    }
    if (gen == _operationGeneration && origSpi == state.spi) {
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
  Future<SSHClient> ensureShellClient({VoidCallback? onDial}) async {
    final existing = state.client;
    if (existing != null && !existing.isClosed) return existing;

    final spi = state.spi;
    final gen = _operationGeneration;
    final origSpi = spi;
    // [Spix.sshOn], not the stored credential: SSH switched off, or parked
    // behind `Spi.local`, is configuration the user asked this app not to
    // dial.
    if (spi.sshOn == null) {
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

    // Past the early return and the try limiter, so this fires exactly when a
    // connection is going to be made — which is what raises the host key and
    // keyboard-interactive prompts, and so what a caller wanting to show them
    // somewhere is waiting for.
    onDial?.call();

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
}

extension IndividualServerStateExtension on ServerState {
  bool get canViewDetails => conn == ServerConn.finished;

  String get id => spi.id;
}

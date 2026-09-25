import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show MapEquality;
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server.dart' show ServerConn;
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/data/provider/virt/libvirt_backend.dart';
import 'package:server_box/data/provider/virt/pve_backend.dart';
import 'package:server_box/data/res/store.dart';

part 'virt.freezed.dart';
part 'virt.g.dart';

// -----------------------------------------------------------------------------
// PVE configuration
// -----------------------------------------------------------------------------

/// Every server's PVE configuration (`server_pve`), by server id, read again
/// whenever `PveStore.watch` announces a change — the editor saving, a
/// certificate confirmed, a sync or restore landing.
///
/// What the Virtualization providers watch instead of reading the store once:
/// a server that gains a PVE row becomes a PVE host, and one that loses it
/// goes back to being probed for libvirt, without a restart.
@Riverpod(keepAlive: true)
class PveConfigs extends _$PveConfigs {
  static const _equality = MapEquality<String, PveConfig>();

  @override
  Map<String, PveConfig> build() {
    final sub = Stores.pve.watch().listen((_) {
      final next = Stores.pve.fetchAll();
      // An announcement is not always a change (a restore announces once for
      // everything), and every watcher rebuilding on a copy is not free.
      if (!_equality.equals(next, state)) state = next;
    });
    ref.onDispose(sub.cancel);
    return Stores.pve.fetchAll();
  }
}

// -----------------------------------------------------------------------------
// Host list
// -----------------------------------------------------------------------------

enum VirtProbeStatus {
  /// `command -v virsh` is running.
  probing,

  /// `virsh` answered, or refused this account (it is there; the host's own
  /// error says what to change).
  found,

  /// No `virsh` on this server.
  absent,

  /// The server could not be asked: [VirtProbe.error] says why.
  failed,
}

/// What probing one server for libvirt found.
@freezed
abstract class VirtProbe with _$VirtProbe {
  const factory VirtProbe({
    required VirtProbeStatus status,

    /// libvirt's version, when found and readable.
    String? version,
    VirtErr? error,
  }) = _VirtProbe;
}

@freezed
abstract class VirtHostsState with _$VirtHostsState {
  const VirtHostsState._();

  const factory VirtHostsState({
    /// Virtualization hosts in the server list's order, with their kind.
    @Default(<String, VirtHostKind>{}) Map<String, VirtHostKind> hosts,

    /// The other servers, in order: not probed yet, probed and not a host,
    /// or not reachable. The host switcher offers them under "Check this
    /// server" ([VirtHosts.probe]).
    @Default(<String>[]) List<String> others,

    /// libvirt probe results by server id, this session's.
    @Default(<String, VirtProbe>{}) Map<String, VirtProbe> probes,
  }) = _VirtHostsState;

  List<String> get hostIds => hosts.keys.toList();
}

/// Which servers are virtualization hosts.
///
/// PVE: a server with a `server_pve` row — explicit, and followed as it
/// changes ([pveConfigsProvider]). libvirt: `virsh`
/// answers through `ensureExec()`, probed on demand, cached for the session.
/// A server that is both is shown as PVE and not probed.
///
/// **Who is probed without being asked.** A probe is a connection, so the
/// tab's first listing and a pull to refresh probe only the servers the
/// server list is connected to or connecting anyway ([autoProbeable]):
/// `probeAll(onlyConnected: true)`. Everything else is probed only when the
/// user asks — "Check this server" ([probe]) or "Check all" ([refresh]) —
/// which is also what connects a server whose `autoConnect` is off.
///
/// Kept alive: the probe cache is the point, and a probe is a connection to
/// every server.
@Riverpod(keepAlive: true)
class VirtHosts extends _$VirtHosts {
  static const _maxConcurrentProbes = 4;

  final _probes = <String, VirtProbe>{};
  final _inFlight = <String, Future<void>>{};

  @override
  VirtHostsState build() {
    final servers = ref.watch(serversProvider);
    final pve = ref.watch(pveConfigsProvider);
    return _compose(servers.serverOrder, servers.servers.keys.toSet(), pve);
  }

  VirtHostsState _compose(
    List<String> order,
    Set<String> known,
    Map<String, PveConfig> pve,
  ) {
    final hosts = <String, VirtHostKind>{};
    final others = <String>[];
    // The order the server list shows, then anything it has not placed.
    final ids = [...order, ...known.where((id) => !order.contains(id))];
    for (final id in ids) {
      if (!known.contains(id)) continue;
      if (pve.containsKey(id)) {
        hosts[id] = VirtHostKind.pve;
      } else if (_probes[id]?.status == VirtProbeStatus.found) {
        hosts[id] = VirtHostKind.libvirt;
      } else {
        others.add(id);
      }
    }
    _probes.removeWhere((id, _) => !known.contains(id));
    return VirtHostsState(
      hosts: hosts,
      others: others,
      probes: Map.unmodifiable(_probes),
    );
  }

  void _publish() {
    if (!ref.mounted) return;
    final servers = ref.read(serversProvider);
    state = _compose(
      servers.serverOrder,
      servers.servers.keys.toSet(),
      ref.read(pveConfigsProvider),
    );
  }

  /// Probes [serverId] for libvirt, unless this session already has — or
  /// always with [force].
  Future<void> probe(String serverId, {bool force = false}) {
    final running = _inFlight[serverId];
    if (running != null) return running;
    if (!force && _probes.containsKey(serverId)) return Future.value();
    if (ref.read(pveConfigsProvider).containsKey(serverId)) {
      return Future.value();
    }
    // A block body: `remove` answers the future itself, and `whenComplete`
    // waits on what its callback returns.
    final future = _probe(serverId).whenComplete(() {
      _inFlight.remove(serverId);
    });
    _inFlight[serverId] = future;
    return future;
  }

  Future<void> _probe(String serverId) async {
    // A re-probe keeps the last answer on screen until the new one lands,
    // so a host does not drop out of the list for the length of a refresh.
    if (!_probes.containsKey(serverId)) {
      _probes[serverId] = const VirtProbe(status: VirtProbeStatus.probing);
      _publish();
    }
    final backend = LibvirtBackend.of(ref, serverId);
    VirtProbe result;
    try {
      final version = await backend.probe();
      result = VirtProbe(
        status: VirtProbeStatus.found,
        version: version.libvirt,
      );
    } on VirtErr catch (e) {
      result = switch (e.type) {
        VirtErrType.notInstalled => const VirtProbe(
          status: VirtProbeStatus.absent,
        ),
        VirtErrType.permissionDenied ||
        VirtErrType.sudoPasswordRequired ||
        VirtErrType.sudoPasswordRejected => VirtProbe(
          status: VirtProbeStatus.found,
          error: e,
        ),
        _ => VirtProbe(status: VirtProbeStatus.failed, error: e),
      };
    } catch (e, s) {
      Loggers.app.warning('libvirt probe failed', e, s);
      result = VirtProbe(
        status: VirtProbeStatus.failed,
        error: VirtErr(type: VirtErrType.unknown, message: '$e', cause: e),
      );
    } finally {
      await backend.close();
    }
    if (!ref.mounted) return;
    _probes[serverId] = result;
    _publish();
  }

  /// Whether [spi] may be probed without the user asking: what the server
  /// list's own refresh would connect, less what is not connecting now.
  ///
  /// - Connected, or on its way ([ServerConn.connecting] and after): the
  ///   connection is there or coming whatever this does.
  /// - Disconnected with `autoConnect` on: the server list connects it by
  ///   itself.
  /// - Not otherwise. Disconnected with `autoConnect` off is a server the
  ///   user connects by hand; failed is one the list's own retry owns;
  ///   disconnected by hand ([manuallyDisconnected]) the list leaves alone,
  ///   and so does one waiting on a keyboard-interactive login, which a
  ///   probe would answer with a prompt nobody asked for.
  static bool autoProbeable(
    Spi spi,
    ServerState server, {
    required bool manuallyDisconnected,
  }) {
    if (manuallyDisconnected) return false;
    final err = server.status.err;
    if (err is SSHErr && err.type == SSHErrType.interactiveAuth) return false;
    return switch (server.conn) {
      ServerConn.failed => false,
      ServerConn.disconnected => spi.autoConnect,
      ServerConn.connecting ||
      ServerConn.connected ||
      ServerConn.loading ||
      ServerConn.finished => true,
    };
  }

  /// Probes every server not probed yet ([force]: every server), a few at a
  /// time. [onlyConnected] limits it to [autoProbeable] servers: what runs
  /// without the user asking.
  Future<void> probeAll({bool force = false, bool onlyConnected = false}) async {
    final servers = ref.read(serversProvider);
    bool eligible(String id) {
      if (!onlyConnected) return true;
      final spi = servers.servers[id];
      if (spi == null) return false;
      return autoProbeable(
        spi,
        ref.read(serverProvider(id)),
        manuallyDisconnected: servers.manualDisconnectedIds.contains(id),
      );
    }

    final pending = [
      for (final id in [...state.others, ...state.hosts.keys])
        if (state.hosts[id] != VirtHostKind.pve &&
            (force || !_probes.containsKey(id)) &&
            eligible(id))
          id,
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final id = pending[next++];
        await probe(id, force: force);
      }
    }

    await Future.wait([
      for (var i = 0; i < _maxConcurrentProbes; i++) worker(),
    ]);
  }

  /// Probes again: every server ("Check all"), or with [onlyConnected] the
  /// [autoProbeable] ones (a pull to refresh, which is about the host on
  /// screen and must not connect servers the user keeps closed).
  Future<void> refresh({bool onlyConnected = false}) async {
    _publish();
    await probeAll(force: true, onlyConnected: onlyConnected);
  }
}

// -----------------------------------------------------------------------------
// One host
// -----------------------------------------------------------------------------

@freezed
abstract class VirtHostState with _$VirtHostState {
  const VirtHostState._();

  const factory VirtHostState({
    required String serverId,

    /// Null only for a server that no longer exists.
    VirtHostKind? kind,

    /// The last successful load. Kept while [error] is set, so the list does
    /// not blank on one failed refresh.
    VirtSnapshot? data,

    /// Why the last refresh failed; null after a success.
    VirtErr? error,

    /// A refresh someone asked for is running (an automatic one is not
    /// announced).
    @Default(false) bool loading,

    /// Guests with a power action in flight, and which.
    @Default(<String, VirtPowerAction>{}) Map<String, VirtPowerAction> busy,

    /// This session's readings per guest, oldest first, capped at
    /// [VirtHostNotifier.sampleLimit] — the chart for a host without
    /// `storedHistory`, and the live tail for one with it.
    @Default(<String, List<VirtStats>>{}) Map<String, List<VirtStats>> samples,
    DateTime? updatedAt,
  }) = _VirtHostState;

  VirtGuest? guest(String id) =>
      data?.guests.firstWhereOrNull((g) => g.id == id);

  VirtStats? statsOf(String id) => data?.stats[id];

  /// [guest]'s state as it should read now: the transient state of an action
  /// this app has in flight, otherwise what the host reported.
  VirtGuestState displayState(VirtGuest guest) =>
      busy[guest.id]?.transientState ?? guest.state;

  /// What [guest] offers now: nothing while an action of this app's is in
  /// flight on it.
  Set<VirtPowerAction> actionsOf(VirtGuest guest) =>
      busy.containsKey(guest.id) ? const {} : guest.actions;
}

/// One virtualization host: its backend, periodic refresh, actions in flight
/// and the answers the user gives (TOTP, certificate, sudo password).
///
/// Refreshes every `serverStatusRefreshInterval()`, the status page's
/// setting, while something listens; auto-disposed with the page, which ends
/// the backend's session. An automatic refresh does nothing while the last
/// error needs the user ([VirtErr.needsInput]): repeating it would ask the
/// server the same refused question every few seconds.
///
/// **What the UI does with [VirtHostState.error]:**
/// - `needTfa` → ask for the code, [submitTfa].
/// - `certUnconfirmed` / `certChanged` → show [VirtErr.cert] (and
///   [VirtErr.previousFingerprint]), [confirmCert] with its fingerprint if the
///   user accepts.
/// - `sudoPasswordRequired` / `sudoPasswordRejected` → ask for the sudo
///   password, [provideSudoPassword].
/// - anything else → show it; [refresh] retries.
@riverpod
class VirtHostNotifier extends _$VirtHostNotifier {
  static const sampleLimit = 120;

  late VirtBackend _backend;
  Timer? _timer;
  bool _refreshing = false;

  /// A requested refresh arrived while one was running: run once more after
  /// it, since what was asked for (the state after an action) may be newer
  /// than what the running one reads.
  bool _again = false;

  /// The load [build] starts, done when it has finished (whatever came of
  /// it). A caller that needs the host loaded awaits this rather than asking
  /// for a second load on top of the one already running.
  Future<void> _firstLoad = Future.value();

  VirtBackend get backend => _backend;

  /// See [_firstLoad].
  Future<void> get firstLoad => _firstLoad;

  @override
  VirtHostState build(String serverId) {
    final spi = ref.watch(
      serversProvider.select((s) => s.servers[serverId]),
    );
    if (spi == null) {
      // Its own error rather than "not configured": there is no server left
      // to configure, and the host list has already dropped it.
      _backend = _MissingBackend(serverId);
      _firstLoad = Future.value();
      return VirtHostState(
        serverId: serverId,
        error: const VirtErr(type: VirtErrType.serverRemoved),
      );
    }
    // Which backend follows whether there is a PVE row, and nothing else
    // about it: gaining or losing one rebuilds as the other kind. A change to
    // the row itself is handed to the running backend below, which keeps its
    // session where the change does not touch the API (a confirmed
    // certificate is written back to the row by the backend that confirmed
    // it).
    final isPve = ref.watch(
      pveConfigsProvider.select((m) => m.containsKey(serverId)),
    );
    final pve = isPve ? ref.read(pveConfigsProvider)[serverId] : null;
    final backend = pve != null
        ? PveBackend.of(ref, spi, pve)
        : LibvirtBackend.of(ref, serverId);
    _backend = backend;
    if (backend is PveBackend) {
      ref.listen(pveConfigsProvider.select((m) => m[serverId]), (_, next) {
        if (next == null || next == backend.config) return;
        backend.updateConfig(next);
        unawaited(refresh());
      });
    }
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      unawaited(backend.close());
    });
    final interval = serverStatusRefreshInterval();
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => refresh(auto: true));
    }
    _firstLoad = Future<void>.microtask(refresh);
    return VirtHostState(serverId: serverId, kind: backend.kind, loading: true);
  }

  /// Loads the host again. [auto] is the timer's: unannounced, and skipped
  /// while the error waits for the user.
  Future<void> refresh({bool auto = false}) async {
    if (!ref.mounted) return;
    if (_refreshing) {
      if (!auto) _again = true;
      return;
    }
    if (auto && (state.error?.needsInput ?? false)) return;
    final backend = _backend;
    if (backend is _MissingBackend) return;
    _refreshing = true;
    if (!auto) state = state.copyWith(loading: true);
    try {
      final snapshot = await backend.load();
      if (!ref.mounted || !identical(backend, _backend)) return;
      state = state.copyWith(
        data: snapshot,
        error: null,
        loading: false,
        samples: _appendSamples(state.samples, snapshot),
        updatedAt: DateTime.now(),
      );
    } on VirtErr catch (e) {
      if (!ref.mounted || !identical(backend, _backend)) return;
      state = state.copyWith(error: e, loading: false);
    } catch (e, s) {
      Loggers.app.warning('Virtualization refresh failed', e, s);
      if (!ref.mounted || !identical(backend, _backend)) return;
      state = state.copyWith(
        error: VirtErr(type: VirtErrType.unknown, message: '$e', cause: e),
        loading: false,
      );
    } finally {
      _refreshing = false;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(refresh());
      }
    }
  }

  static Map<String, List<VirtStats>> _appendSamples(
    Map<String, List<VirtStats>> previous,
    VirtSnapshot snapshot,
  ) {
    final out = <String, List<VirtStats>>{};
    for (final guest in snapshot.guests) {
      final list = [...?previous[guest.id]];
      final stats = snapshot.stats[guest.id];
      if (stats != null) list.add(stats);
      if (list.length > sampleLimit) {
        list.removeRange(0, list.length - sampleLimit);
      }
      out[guest.id] = list;
    }
    return out;
  }

  /// Drops the session and loads again: a new login, a new sudo probe.
  Future<void> reconnect() async {
    await _backend.reset();
    await refresh();
  }

  VirtGuest _guest(String guestId) {
    final guest = state.guest(guestId);
    if (guest == null) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'No guest $guestId on this host',
      );
    }
    return guest;
  }

  /// Runs [action] on the guest [guestId] and refreshes. Throws [VirtErr];
  /// the host's [VirtHostState.error] is left for the refresh to decide.
  ///
  /// One action per guest at a time: a second while one is in flight throws
  /// [VirtErrType.unsupported].
  Future<void> power(String guestId, VirtPowerAction action) async {
    final guest = _guest(guestId);
    if (state.busy.containsKey(guestId)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is busy',
      );
    }
    state = state.copyWith(busy: {...state.busy, guestId: action});
    try {
      await _backend.power(guest, action);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(busy: {...state.busy}..remove(guestId));
        unawaited(refresh());
      }
    }
  }

  Future<VirtGuestDetail> detail(String guestId) =>
      _backend.detail(_guest(guestId));

  /// A fresh console handle — see [VirtConsole] for what each kind needs.
  Future<VirtConsole> console(String guestId, VirtConsoleKind kind) =>
      _backend.console(_guest(guestId), kind);

  /// For a [PveConsole]: its websocket, over the host's transport and login.
  Future<WebSocket> openPveConsoleSocket(PveConsole console) {
    final backend = _backend;
    if (backend is! PveBackend) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    return backend.openConsoleSocket(console);
  }

  /// Usage over [window]: the host's stored history where it keeps one,
  /// otherwise this session's [VirtHostState.samples].
  Future<List<VirtStats>> history(
    String guestId, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async {
    final stored = await _backend.history(_guest(guestId), window: window);
    return stored ?? state.samples[guestId] ?? const [];
  }

  /// Answers [VirtErrType.needTfa], then loads.
  Future<void> submitTfa(String code) async {
    final backend = _backend;
    if (backend is! PveBackend) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    try {
      await backend.submitTfa(code);
    } on VirtErr catch (e) {
      if (ref.mounted) state = state.copyWith(error: e);
      rethrow;
    }
    await refresh();
  }

  /// Pins [fingerprint] (from [VirtErr.cert]) and loads.
  Future<void> confirmCert(String fingerprint) async {
    final backend = _backend;
    if (backend is! PveBackend) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    await backend.confirmCert(fingerprint);
    await refresh();
  }

  /// Answers [VirtErrType.sudoPasswordRequired] or
  /// [VirtErrType.sudoPasswordRejected], then loads. The password is kept in
  /// memory for this host's session only.
  Future<void> provideSudoPassword(String password) async {
    final backend = _backend;
    if (backend is! LibvirtBackend) {
      throw const VirtErr(type: VirtErrType.unsupported);
    }
    backend.provideSudoPassword(password);
    await refresh();
  }
}

/// The backend of a server that is gone: every call fails.
final class _MissingBackend implements VirtBackend {
  const _MissingBackend(this.serverId);

  @override
  final String serverId;

  @override
  VirtHostKind get kind => VirtHostKind.libvirt;

  static Never _fail() =>
      throw const VirtErr(type: VirtErrType.serverRemoved);

  @override
  Future<VirtSnapshot> load() async => _fail();

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async =>
      _fail();

  @override
  Future<VirtGuestDetail> detail(VirtGuest guest) async => _fail();

  @override
  Future<VirtConsole> console(VirtGuest guest, VirtConsoleKind kind) async =>
      _fail();

  @override
  Future<List<VirtStats>?> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => _fail();

  @override
  Future<void> reset() async {}

  @override
  Future<void> close() async {}
}

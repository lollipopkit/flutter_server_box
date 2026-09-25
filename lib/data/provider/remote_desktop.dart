import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;

part 'remote_desktop.g.dart';

const _retryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 5),
];

class RemoteDesktopCertificatePrompt {
  const RemoteDesktopCertificatePrompt({
    required this.sha256,
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
    this.previousSha256,
  });

  final String sha256;
  final String subject;
  final String issuer;
  final String validFrom;
  final String validTo;
  final String? previousSha256;

  bool get replacesExisting => previousSha256 != null;
}

class RemoteDesktopCursor {
  const RemoteDesktopCursor({
    this.visible = true,
    this.useDefault = true,
    this.x = 0,
    this.y = 0,
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.hotspotX = 0,
    this.hotspotY = 0,
  });

  final bool visible;
  final bool useDefault;
  final int x;
  final int y;
  final Uint8List? rgba;
  final int width;
  final int height;
  final int hotspotX;
  final int hotspotY;

  RemoteDesktopCursor copyWith({
    bool? visible,
    bool? useDefault,
    int? x,
    int? y,
    Uint8List? rgba,
    bool clearBitmap = false,
    int? width,
    int? height,
    int? hotspotX,
    int? hotspotY,
  }) => RemoteDesktopCursor(
    visible: visible ?? this.visible,
    useDefault: useDefault ?? this.useDefault,
    x: x ?? this.x,
    y: y ?? this.y,
    rgba: clearBitmap ? null : (rgba ?? this.rgba),
    width: width ?? this.width,
    height: height ?? this.height,
    hotspotX: hotspotX ?? this.hotspotX,
    hotspotY: hotspotY ?? this.hotspotY,
  );
}

class RemoteDesktopSessionView {
  RemoteDesktopSessionView({
    required this.profile,
    this.connectionState = ffi.RemoteDesktopConnectionState.connecting,
    this.reconnectAttempt = 0,
    this.width = 0,
    this.height = 0,
    this.frameBgra,
    BigInt? frameSequence,
    this.cursor = const RemoteDesktopCursor(),
    this.error,
    this.endReason,
    this.certificate,
    this.visible = false,
    bool? viewOnly,
  }) : frameSequence = frameSequence ?? BigInt.zero,
       viewOnly = viewOnly ?? profile.viewOnly;

  final RemoteDesktopProfile profile;
  final ffi.RemoteDesktopConnectionState connectionState;
  final int reconnectAttempt;
  final int width;
  final int height;
  final Uint8List? frameBgra;
  final BigInt frameSequence;
  final RemoteDesktopCursor cursor;
  final String? error;
  final ffi.RemoteDesktopEndReason? endReason;
  final RemoteDesktopCertificatePrompt? certificate;
  final bool visible;
  final bool viewOnly;

  String get id => profile.id;
  bool get connected =>
      connectionState == ffi.RemoteDesktopConnectionState.connected;

  RemoteDesktopSessionView copyWith({
    RemoteDesktopProfile? profile,
    ffi.RemoteDesktopConnectionState? connectionState,
    int? reconnectAttempt,
    int? width,
    int? height,
    Uint8List? frameBgra,
    bool clearFrame = false,
    BigInt? frameSequence,
    RemoteDesktopCursor? cursor,
    String? error,
    bool clearError = false,
    ffi.RemoteDesktopEndReason? endReason,
    bool clearEndReason = false,
    RemoteDesktopCertificatePrompt? certificate,
    bool clearCertificate = false,
    bool? visible,
    bool? viewOnly,
  }) => RemoteDesktopSessionView(
    profile: profile ?? this.profile,
    connectionState: connectionState ?? this.connectionState,
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
    width: width ?? this.width,
    height: height ?? this.height,
    frameBgra: clearFrame ? null : (frameBgra ?? this.frameBgra),
    frameSequence: frameSequence ?? this.frameSequence,
    cursor: cursor ?? this.cursor,
    error: clearError ? null : (error ?? this.error),
    endReason: clearEndReason ? null : (endReason ?? this.endReason),
    certificate: clearCertificate ? null : (certificate ?? this.certificate),
    visible: visible ?? this.visible,
    viewOnly: viewOnly ?? this.viewOnly,
  );

  @override
  String toString() =>
      'RemoteDesktopSessionView(id: $id, protocol: ${profile.protocol.name}, '
      'state: ${connectionState.name}, attempt: $reconnectAttempt, '
      'size: ${width}x$height, hasFrame: ${frameBgra != null}, '
      'hasError: ${error != null}, hasCertificate: ${certificate != null}, '
      'visible: $visible, viewOnly: $viewOnly)';
}

class RemoteDesktopSessionsState {
  const RemoteDesktopSessionsState({
    this.sessions = const {},
    this.activeId,
    this.consoles = const {},
  });

  /// The remote desktop tab's sessions, one per profile.
  final Map<String, RemoteDesktopSessionView> sessions;
  final String? activeId;

  /// Sessions a page other than the remote desktop tab opened and shows — a
  /// virtual machine's graphical console. Kept apart so that tab neither
  /// lists them nor switches to them.
  final Map<String, RemoteDesktopSessionView> consoles;

  RemoteDesktopSessionView? get active => sessions[activeId];
  List<RemoteDesktopSessionView> get ordered => sessions.values.toList();

  /// A session of either kind, by id — what the viewer shows.
  RemoteDesktopSessionView? byId(String id) => sessions[id] ?? consoles[id];

  /// Whether input for [id] — keys, pointer, wheel, clipboard — is sent: a
  /// session of either kind that is not view-only.
  bool acceptsInput(String id) => !(byId(id)?.viewOnly ?? true);

  RemoteDesktopSessionsState put(RemoteDesktopSessionView session) {
    if (consoles.containsKey(session.id)) {
      return RemoteDesktopSessionsState(
        sessions: sessions,
        activeId: activeId,
        consoles: Map.unmodifiable({...consoles, session.id: session}),
      );
    }
    return RemoteDesktopSessionsState(
      sessions: Map.unmodifiable({...sessions, session.id: session}),
      activeId: activeId,
      consoles: consoles,
    );
  }

  RemoteDesktopSessionsState putConsole(RemoteDesktopSessionView session) =>
      RemoteDesktopSessionsState(
        sessions: sessions,
        activeId: activeId,
        consoles: Map.unmodifiable({...consoles, session.id: session}),
      );

  RemoteDesktopSessionsState remove(String id) {
    if (consoles.containsKey(id)) {
      return RemoteDesktopSessionsState(
        sessions: sessions,
        activeId: activeId,
        consoles: Map.unmodifiable(
          Map<String, RemoteDesktopSessionView>.from(consoles)..remove(id),
        ),
      );
    }
    final next = Map<String, RemoteDesktopSessionView>.from(sessions)
      ..remove(id);
    final nextActive = activeId == id
        ? (next.isEmpty ? null : next.keys.last)
        : activeId;
    return RemoteDesktopSessionsState(
      sessions: Map.unmodifiable(next),
      activeId: nextActive,
      consoles: consoles,
    );
  }

  RemoteDesktopSessionsState select(String? id) => RemoteDesktopSessionsState(
    sessions: sessions,
    activeId: id != null && sessions.containsKey(id) ? id : activeId,
    consoles: consoles,
  );
}

/// Where one connection attempt of a session goes: the loopback listener the
/// engine connects to, and the password to give it.
typedef RemoteDesktopTarget = ({SshLocalTunnel tunnel, String? password});

/// Makes a [RemoteDesktopTarget] for each connection attempt — so a target
/// whose password is a one-use ticket fetches a new one every time.
typedef RemoteDesktopTargetOpener = Future<RemoteDesktopTarget> Function();

@Riverpod(keepAlive: true)
class RemoteDesktopProfiles extends _$RemoteDesktopProfiles {
  @override
  List<RemoteDesktopProfile> build(String serverId) =>
      Stores.remoteDesktop.fetchForServer(serverId);

  void reload() {
    state = Stores.remoteDesktop.fetchForServer(serverId);
  }

  void add(RemoteDesktopProfile profile) {
    final value = profile.copyWith(serverId: serverId);
    Stores.remoteDesktop.put(value);
    reload();
  }

  void update(RemoteDesktopProfile previous, RemoteDesktopProfile next) {
    final value = next.copyWith(serverId: serverId);
    if (previous.id != value.id) Stores.remoteDesktop.delete(previous);
    Stores.remoteDesktop.put(value);
    reload();
  }

  void remove(RemoteDesktopProfile profile) {
    Stores.remoteDesktop.delete(profile);
    reload();
  }
}

/// Every remote desktop session there is — the remote desktop tab's and the
/// consoles other pages show — and their connections.
///
/// A session off screen is not closed here: each is registered with
/// [SessionKeepAlive], told whenever it comes on or goes off screen, and
/// closed through [close] when that decides it has been left long enough.
@Riverpod(keepAlive: true)
class RemoteDesktopSessions extends _$RemoteDesktopSessions {
  final Map<String, _SessionEntry> _entries = {};
  /// Not final: `build` runs again on the same notifier when the provider is
  /// rebuilt, and sets these afresh.
  late SessionKeepAlive _keepAlive;
  bool _disposed = false;
  bool _appVisible = true;
  bool _surfaceVisible = false;

  @override
  RemoteDesktopSessionsState build() {
    _disposed = false;
    _keepAlive = ref.read(sessionKeepAliveProvider.notifier);
    final lifecycle = AppLifecycleListener(
      onResume: _resume,
      onPause: _pause,
      onHide: _pause,
      onDetach: _pause,
    );
    ref.onDispose(() {
      _disposed = true;
      lifecycle.dispose();
      for (final entry in _entries.values.toList()) {
        unawaited(_disposeEntry(entry));
      }
      _entries.clear();
    });
    return const RemoteDesktopSessionsState();
  }

  /// Hands [profile]'s session to [SessionKeepAlive], named for its notice by
  /// the profile and the server it goes through.
  void _registerKeepAlive(RemoteDesktopProfile profile) {
    final id = profile.id;
    _keepAlive.register(
      id,
      name: profile.name,
      host:
          ref.read(serversProvider).servers[profile.serverId]?.name ??
          profile.host,
      onClose: () => close(id),
    );
  }

  /// Opens a profile once; repeated launches focus the existing session.
  String open(
    RemoteDesktopProfile profile, {
    String? sessionPassword,
    int width = 1280,
    int height = 720,
    int scaleFactor = 100,
  }) {
    final existing = _entries[profile.id];
    if (existing != null) {
      select(profile.id);
      return profile.id;
    }

    final entry = _SessionEntry(
      profile: profile,
      password: sessionPassword ?? profile.password,
      width: width.clamp(1, 8192),
      height: height.clamp(1, 8192),
      scaleFactor: scaleFactor.clamp(100, 500),
    );
    _entries[profile.id] = entry;
    _registerKeepAlive(profile);
    state = state
        .put(RemoteDesktopSessionView(profile: profile, visible: true))
        .select(profile.id);
    _syncVisibility();
    unawaited(_connect(entry));
    return profile.id;
  }

  /// Opens a session shown by a page of its own rather than by the remote
  /// desktop tab — see [RemoteDesktopSessionsState.consoles].
  ///
  /// [profile] is not stored anywhere; [target] says where each connection
  /// attempt goes and with which password, in place of the profile's host,
  /// port and password. Opening an id that is already open reconnects it.
  String openConsole(
    RemoteDesktopProfile profile, {
    required RemoteDesktopTargetOpener target,
  }) {
    final existing = _entries[profile.id];
    if (existing != null) {
      unawaited(reconnect(profile.id));
      return profile.id;
    }
    final entry = _SessionEntry(
      profile: profile,
      password: null,
      width: 1280,
      height: 720,
      scaleFactor: 100,
      target: target,
    );
    _entries[profile.id] = entry;
    _registerKeepAlive(profile);
    state = state.putConsole(RemoteDesktopSessionView(profile: profile));
    _syncVisibility();
    unawaited(_connect(entry));
    return profile.id;
  }

  /// Whether the page showing console [id] is on screen. Frames are decoded
  /// only while it is, and while the app is.
  void setConsoleVisible(String id, bool visible) {
    final entry = _entries[id];
    if (entry == null || entry.target == null) return;
    entry.consoleVisible = visible;
    _syncVisibility();
  }

  void select(String id) {
    if (!_entries.containsKey(id) || state.activeId == id) return;
    state = state.select(id);
    _syncVisibility();
  }

  Future<void> close(String id) async {
    final entry = _entries.remove(id);
    if (entry == null) return;
    _keepAlive.unregister(id);
    entry.closed = true;
    entry.generation++;
    await _disposeEntry(entry);
    state = state.remove(id);
    _syncVisibility();
  }

  Future<void> closeForProfile(String profileId) => close(profileId);

  Future<void> closeForServer(String serverId) async {
    final ids = _entries.values
        .where((entry) => entry.profile.serverId == serverId)
        .map((entry) => entry.profile.id)
        .toList();
    for (final id in ids) {
      await close(id);
    }
  }

  Future<void> reconnect(String id, {String? sessionPassword}) async {
    final entry = _entries[id];
    if (entry == null) return;
    if (sessionPassword != null) entry.password = sessionPassword;
    entry.closed = false;
    entry.retryCount = 0;
    entry.generation++;
    await _disposeConnection(entry);
    if (!_disposed && _entries[id] == entry) unawaited(_connect(entry));
  }

  Future<void> trustCertificate(String id) async {
    final entry = _entries[id];
    final prompt = state.byId(id)?.certificate;
    if (entry == null || prompt == null) return;
    final trusted = entry.profile.copyWith(trustedCertSha256: prompt.sha256);
    // What is written is the stored record, not the draft the session may have
    // been opened from: Test connects with unsaved edits,
    // and persisting those here would save a form nobody pressed Save on — or
    // create a record for a profile that does not exist yet. Trusting a
    // certificate is a decision about a connection, and it must not carry a
    // form's contents into the database with it.
    final stored = Stores.remoteDesktop.fetchOneRaw(id);
    if (stored != null &&
        stored.protocol == trusted.protocol &&
        stored.host == trusted.host &&
        stored.port == trusted.port) {
      Stores.remoteDesktop.put(
        stored.copyWith(trustedCertSha256: prompt.sha256),
      );
    }
    // In memory either way, including for a draft: the session about to
    // reconnect is this one, and it has to remember what it just accepted.
    entry.profile = trusted;
    _replaceView(
      id,
      (view) => view.copyWith(
        profile: trusted,
        clearCertificate: true,
        clearError: true,
        clearEndReason: true,
      ),
    );
    ref.invalidate(remoteDesktopProfilesProvider(trusted.serverId));
    await reconnect(id);
  }

  void setViewOnly(String id, bool value) {
    _replaceView(id, (view) => view.copyWith(viewOnly: value));
  }

  void setSurfaceVisible(bool visible) {
    if (_surfaceVisible == visible) return;
    _surfaceVisible = visible;
    _syncVisibility();
  }

  void sendKey(String id, int code, bool down, {bool extended = false}) {
    final entry = _writableEntry(id);
    entry?.handle?.sendKey(code: code, down: down, extended: extended);
  }

  void sendUnicodeText(String id, String text) {
    if (text.isEmpty) return;
    _writableEntry(id)?.handle?.sendUnicodeText(text: text);
  }

  void sendPointer(String id, int x, int y, int buttons) {
    _writableEntry(id)?.handle?.sendPointer(
      x: x.clamp(0, 65535),
      y: y.clamp(0, 65535),
      buttons: buttons.clamp(0, 255),
    );
  }

  void sendWheel(String id, int x, int y, {int deltaX = 0, int deltaY = 0}) {
    _writableEntry(id)?.handle?.sendWheel(
      x: x.clamp(0, 65535),
      y: y.clamp(0, 65535),
      deltaX: deltaX.clamp(-32768, 32767),
      deltaY: deltaY.clamp(-32768, 32767),
    );
  }

  Future<void> sendClipboard(String id) async {
    final entry = _writableEntry(id);
    if (entry == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    entry.handle?.sendClipboardText(text: text);
  }

  void resize(
    String id,
    int width,
    int height, {
    int scaleFactor = 100,
    int? physicalWidthMm,
    int? physicalHeightMm,
  }) {
    final entry = _entries[id];
    if (entry == null || entry.profile.protocol != RemoteDesktopProtocol.rdp) {
      return;
    }
    entry.width = width.clamp(1, 8192);
    entry.height = height.clamp(1, 8192);
    entry.scaleFactor = scaleFactor.clamp(100, 500);
    entry.handle?.resize(
      width: entry.width,
      height: entry.height,
      scaleFactor: entry.scaleFactor,
      physicalWidthMm: physicalWidthMm,
      physicalHeightMm: physicalHeightMm,
    );
  }

  void releaseAllKeys(String id) {
    _entries[id]?.handle?.releaseAllKeys();
  }

  _SessionEntry? _writableEntry(String id) {
    if (!state.acceptsInput(id)) return null;
    return _entries[id];
  }

  Future<void> _connect(_SessionEntry entry) async {
    if (_disposed || entry.closed || _entries[entry.profile.id] != entry) {
      return;
    }
    final generation = ++entry.generation;
    _replaceView(
      entry.profile.id,
      (view) => view.copyWith(
        connectionState: entry.retryCount == 0
            ? ffi.RemoteDesktopConnectionState.connecting
            : ffi.RemoteDesktopConnectionState.reconnecting,
        reconnectAttempt: entry.retryCount,
        clearError: true,
        clearEndReason: true,
        clearCertificate: true,
      ),
    );

    SshLocalTunnel? tunnel;
    try {
      final String? password;
      if (entry.target case final target?) {
        final opened = await target();
        tunnel = opened.tunnel;
        password = opened.password;
      } else {
        tunnel = await _openTunnel(entry);
        password = entry.password;
      }
      if (tunnel == null || !_isCurrent(entry, generation)) {
        await tunnel?.close();
        return;
      }
      final handle = switch (entry.profile.protocol) {
        RemoteDesktopProtocol.rdp => ffi.RemoteDesktopSessionHandle.startRdp(
          params: ffi.RdpSessionParams(
            connectHost: tunnel.address.address,
            connectPort: tunnel.port,
            accessToken: tunnel.accessToken,
            serverName: entry.profile.host,
            serverPort: entry.profile.port,
            username: entry.profile.username ?? '',
            password: password ?? '',
            domain: entry.profile.domain,
            trustedCertSha256: entry.profile.trustedCertSha256,
            width: entry.width,
            height: entry.height,
            scaleFactor: entry.scaleFactor,
          ),
        ),
        RemoteDesktopProtocol.vnc => ffi.RemoteDesktopSessionHandle.startVnc(
          params: ffi.VncSessionParams(
            connectHost: tunnel.address.address,
            connectPort: tunnel.port,
            accessToken: tunnel.accessToken,
            password: password,
            shared: entry.profile.shared,
          ),
        ),
      };
      if (!_isCurrent(entry, generation)) {
        handle.close();
        await tunnel.close();
        return;
      }
      entry.tunnel = tunnel;
      entry.handle = handle;
      handle.setVisible(visible: _shown(entry));
      await _pump(entry, generation, handle);
    } catch (error, stackTrace) {
      final failedTunnel = tunnel;
      if (failedTunnel != null && !identical(entry.tunnel, failedTunnel)) {
        await failedTunnel.close().catchError((_) {});
      }
      if (!_isCurrent(entry, generation)) return;
      Loggers.app.warning('Remote desktop session failed', error, stackTrace);
      Diag.crumb(
        SbDiag.forward,
        'remote desktop failed',
        level: DiagLevel.warning,
        data: {
          'protocol': entry.profile.protocol.name,
          'error': Redact.error(error),
        },
      );
      _replaceView(
        entry.profile.id,
        (view) => view.copyWith(
          connectionState: ffi.RemoteDesktopConnectionState.disconnected,
          error: error.toString(),
          endReason: ffi.RemoteDesktopEndReason.transportError,
        ),
      );
      await _connectionEnded(
        entry,
        generation,
        ffi.RemoteDesktopEndReason.transportError,
        error.toString(),
        retryable: true,
      );
    }
  }

  /// The local loopback a session connects to, carried by whichever transport
  /// can reach the target — see [ServerTcpDialer], which owns the ordering and
  /// the fall-through between a server's two transports.
  ///
  /// `LocalCapabilities.tcpRelay` is false, and that policy is this feature's:
  /// this device reaches its own desktop without a relay, and the page is not
  /// offered for it. So `local` is left out of the transports the dialer may
  /// use, although it could open a direct socket.
  Future<SshLocalTunnel?> _openTunnel(_SessionEntry entry) async {
    final spi = ref.read(serversProvider).servers[entry.profile.serverId];
    if (spi == null) return null;
    final dialer = ServerTcpDialer.of(
      ref,
      spi,
      transports: const {ServerTransport.ssh, ServerTransport.monitorHttp},
    );
    try {
      return await dialer.loopback(entry.profile.host, entry.profile.port);
    } finally {
      // The tunnel owns what it runs on; the dialer holds nothing it needs.
      dialer.close();
    }
  }

  Future<void> _pump(
    _SessionEntry entry,
    int generation,
    ffi.RemoteDesktopSessionHandle handle,
  ) async {
    while (_isCurrent(entry, generation) && identical(entry.handle, handle)) {
      final event = await handle.nextEvent();
      if (!_isCurrent(entry, generation)) return;
      if (event == null) {
        await _connectionEnded(
          entry,
          generation,
          ffi.RemoteDesktopEndReason.serverDisconnected,
          'Remote desktop connection ended unexpectedly',
          retryable: true,
        );
        return;
      }
      switch (event) {
        case ffi.RemoteDesktopEvent_ConnectionState(
          :final state,
          :final attempt,
        ):
          if (state == ffi.RemoteDesktopConnectionState.connected) {
            entry.retryCount = 0;
          }
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              connectionState: state,
              reconnectAttempt: attempt,
              clearError: state == ffi.RemoteDesktopConnectionState.connected,
              clearEndReason:
                  state == ffi.RemoteDesktopConnectionState.connected,
            ),
          );
        case ffi.RemoteDesktopEvent_Frame(
          :final bgra,
          :final width,
          :final height,
          :final sequence,
        ):
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              frameBgra: bgra,
              frameSequence: sequence,
              width: width,
              height: height,
            ),
          );
        case ffi.RemoteDesktopEvent_Resolution(:final width, :final height):
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(width: width, height: height),
          );
        case ffi.RemoteDesktopEvent_CursorDefault():
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              cursor: view.cursor.copyWith(
                visible: true,
                useDefault: true,
                clearBitmap: true,
              ),
            ),
          );
        case ffi.RemoteDesktopEvent_CursorHidden():
          _replaceView(
            entry.profile.id,
            (view) =>
                view.copyWith(cursor: view.cursor.copyWith(visible: false)),
          );
        case ffi.RemoteDesktopEvent_CursorPosition(:final x, :final y):
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              cursor: view.cursor.copyWith(x: x, y: y),
            ),
          );
        case ffi.RemoteDesktopEvent_CursorBitmap(
          :final rgba,
          :final width,
          :final height,
          :final hotspotX,
          :final hotspotY,
        ):
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              cursor: view.cursor.copyWith(
                visible: true,
                useDefault: false,
                rgba: rgba,
                width: width,
                height: height,
                hotspotX: hotspotX,
                hotspotY: hotspotY,
              ),
            ),
          );
        case ffi.RemoteDesktopEvent_ClipboardText(:final text):
          await Clipboard.setData(ClipboardData(text: text));
        case ffi.RemoteDesktopEvent_CertificateRequest(
          :final sha256,
          :final subject,
          :final issuer,
          :final validFrom,
          :final validTo,
          :final previousSha256,
        ):
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              certificate: RemoteDesktopCertificatePrompt(
                sha256: sha256,
                subject: subject,
                issuer: issuer,
                validFrom: validFrom,
                validTo: validTo,
                previousSha256: previousSha256,
              ),
            ),
          );
        case ffi.RemoteDesktopEvent_Error(:final message, :final retryable):
          entry.lastErrorRetryable = retryable;
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(error: message),
          );
        case ffi.RemoteDesktopEvent_Ended(:final reason, :final message):
          await _connectionEnded(
            entry,
            generation,
            reason,
            message,
            retryable:
                entry.lastErrorRetryable ||
                reason == ffi.RemoteDesktopEndReason.transportError ||
                reason == ffi.RemoteDesktopEndReason.serverDisconnected,
          );
          return;
      }
    }
  }

  Future<void> _connectionEnded(
    _SessionEntry entry,
    int generation,
    ffi.RemoteDesktopEndReason reason,
    String? message, {
    required bool retryable,
  }) async {
    if (!_isCurrent(entry, generation)) return;
    await _disposeConnection(entry);
    _replaceView(
      entry.profile.id,
      (view) => view.copyWith(
        connectionState: ffi.RemoteDesktopConnectionState.disconnected,
        endReason: reason,
        error: message,
      ),
    );
    if (!retryable || entry.closed || entry.retryCount >= _retryDelays.length) {
      return;
    }
    final delay = _retryDelays[entry.retryCount++];
    _replaceView(
      entry.profile.id,
      (view) => view.copyWith(
        connectionState: ffi.RemoteDesktopConnectionState.reconnecting,
        reconnectAttempt: entry.retryCount,
      ),
    );
    await Future<void>.delayed(delay);
    if (_isCurrent(entry, generation)) unawaited(_connect(entry));
  }

  Future<void> _disposeConnection(_SessionEntry entry) async {
    final handle = entry.handle;
    final tunnel = entry.tunnel;
    entry.handle = null;
    entry.tunnel = null;
    handle?.close();
    await tunnel?.close().catchError((_) {});
  }

  Future<void> _disposeEntry(_SessionEntry entry) async {
    entry.closed = true;
    entry.generation++;
    await _disposeConnection(entry);
  }

  bool _isCurrent(_SessionEntry entry, int generation) =>
      !_disposed &&
      !entry.closed &&
      entry.generation == generation &&
      identical(_entries[entry.profile.id], entry);

  void _replaceView(
    String id,
    RemoteDesktopSessionView Function(RemoteDesktopSessionView) update,
  ) {
    if (_disposed || !ref.mounted) return;
    final current = state.byId(id);
    if (current == null) return;
    state = state.put(update(current));
  }

  /// Whether [entry]'s frames are wanted: its page is on screen, and so is
  /// the app.
  bool _shown(_SessionEntry entry) => _appVisible && _onScreen(entry);

  /// Whether the page showing [entry] is the one on screen, whether or not
  /// the app is. What [SessionKeepAlive] is told: leaving the app is not
  /// leaving the session.
  bool _onScreen(_SessionEntry entry) {
    if (entry.target != null) return entry.consoleVisible;
    return _surfaceVisible && state.activeId == entry.profile.id;
  }

  void _syncVisibility() {
    if (_disposed || !ref.mounted) return;
    var next = state;
    for (final session in [
      ...state.sessions.values,
      ...state.consoles.values,
    ]) {
      final entry = _entries[session.id];
      final visible = entry != null && _shown(entry);
      entry?.handle?.setVisible(visible: visible);
      if (entry != null) _keepAlive.setVisible(session.id, _onScreen(entry));
      if (session.visible != visible) {
        next = next.put(session.copyWith(visible: visible));
      }
    }
    state = next;
  }

  void _pause() {
    _appVisible = false;
    for (final entry in _entries.values) {
      entry.handle?.setVisible(visible: false);
    }
  }

  void _resume() {
    _appVisible = true;
    _syncVisibility();
    // A console on screen that dropped while the app was away: the same as
    // the tab's active session below.
    for (final console in state.consoles.values) {
      final entry = _entries[console.id];
      if (entry != null &&
          entry.consoleVisible &&
          console.connectionState ==
              ffi.RemoteDesktopConnectionState.disconnected) {
        unawaited(reconnect(console.id));
      }
    }
    final active = state.activeId;
    if (active == null) return;
    final entry = _entries[active];
    final view = state.sessions[active];
    if (entry != null &&
        view?.connectionState ==
            ffi.RemoteDesktopConnectionState.disconnected &&
        view?.certificate == null) {
      unawaited(reconnect(active));
    }
  }
}

class _SessionEntry {
  _SessionEntry({
    required this.profile,
    required this.password,
    required this.width,
    required this.height,
    required this.scaleFactor,
    this.target,
  });

  RemoteDesktopProfile profile;

  /// Where a console's connections go, in place of [profile]'s address and
  /// [password]. Null for the remote desktop tab's sessions.
  final RemoteDesktopTargetOpener? target;

  /// For a console: whether the page showing it is on screen.
  bool consoleVisible = false;
  String? password;
  int width;
  int height;
  int scaleFactor;
  int generation = 0;
  int retryCount = 0;
  bool lastErrorRetryable = false;
  bool closed = false;
  SshLocalTunnel? tunnel;
  ffi.RemoteDesktopSessionHandle? handle;
}

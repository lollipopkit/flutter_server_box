import 'dart:async';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/server/single.dart';
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
    certificate: clearCertificate
        ? null
        : (certificate ?? this.certificate),
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
  });

  final Map<String, RemoteDesktopSessionView> sessions;
  final String? activeId;

  RemoteDesktopSessionView? get active => sessions[activeId];
  List<RemoteDesktopSessionView> get ordered => sessions.values.toList();

  RemoteDesktopSessionsState put(RemoteDesktopSessionView session) =>
      RemoteDesktopSessionsState(
        sessions: Map.unmodifiable({...sessions, session.id: session}),
        activeId: activeId,
      );

  RemoteDesktopSessionsState remove(String id) {
    final next = Map<String, RemoteDesktopSessionView>.from(sessions)
      ..remove(id);
    final nextActive = activeId == id
        ? (next.isEmpty ? null : next.keys.last)
        : activeId;
    return RemoteDesktopSessionsState(
      sessions: Map.unmodifiable(next),
      activeId: nextActive,
    );
  }

  RemoteDesktopSessionsState select(String? id) => RemoteDesktopSessionsState(
    sessions: sessions,
    activeId: id != null && sessions.containsKey(id) ? id : activeId,
  );
}

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

@Riverpod(keepAlive: true)
class RemoteDesktopSessions extends _$RemoteDesktopSessions {
  final Map<String, _SessionEntry> _entries = {};
  late final AppLifecycleListener _lifecycle;
  bool _disposed = false;
  bool _appVisible = true;
  bool _surfaceVisible = false;

  @override
  RemoteDesktopSessionsState build() {
    _lifecycle = AppLifecycleListener(
      onResume: _resume,
      onPause: _pause,
      onHide: _pause,
      onDetach: _pause,
    );
    ref.onDispose(() {
      _disposed = true;
      _lifecycle.dispose();
      for (final entry in _entries.values.toList()) {
        unawaited(_disposeEntry(entry));
      }
      _entries.clear();
    });
    return const RemoteDesktopSessionsState();
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
    state = state
        .put(RemoteDesktopSessionView(profile: profile, visible: true))
        .select(profile.id);
    _syncVisibility();
    unawaited(_connect(entry));
    return profile.id;
  }

  void select(String id) {
    if (!_entries.containsKey(id) || state.activeId == id) return;
    state = state.select(id);
    _syncVisibility();
  }

  Future<void> close(String id) async {
    final entry = _entries.remove(id);
    if (entry == null) return;
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
    final prompt = state.sessions[id]?.certificate;
    if (entry == null || prompt == null) return;
    final trusted = entry.profile.copyWith(
      trustedCertSha256: prompt.sha256,
    );
    Stores.remoteDesktop.put(trusted);
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

  void setVisible(String id, bool visible) {
    final entry = _entries[id];
    final effective = visible && _appVisible && _surfaceVisible;
    entry?.handle?.setVisible(visible: effective);
    _replaceView(id, (view) => view.copyWith(visible: effective));
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

  void sendWheel(
    String id,
    int x,
    int y, {
    int deltaX = 0,
    int deltaY = 0,
  }) {
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
    if (state.sessions[id]?.viewOnly ?? true) return null;
    return _entries[id];
  }

  Future<void> _connect(_SessionEntry entry) async {
    if (_disposed || entry.closed || _entries[entry.profile.id] != entry) return;
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
      final client = await ref
          .read(serverProvider(entry.profile.serverId).notifier)
          .ensureShellClient();
      if (!_isCurrent(entry, generation)) return;
      tunnel = await SshLocalTunnel.loopback(
        client: client,
        remoteHost: entry.profile.host,
        remotePort: entry.profile.port,
      );
      if (!_isCurrent(entry, generation)) {
        await tunnel.close();
        return;
      }

      final handle = switch (entry.profile.protocol) {
        RemoteDesktopProtocol.rdp => ffi.RemoteDesktopSessionHandle.startRdp(
          params: ffi.RdpSessionParams(
            connectHost: tunnel.address.address,
            connectPort: tunnel.port,
            serverName: entry.profile.host,
            serverPort: entry.profile.port,
            username: entry.profile.username ?? '',
            password: entry.password ?? '',
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
            password: entry.password,
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
      handle.setVisible(
        visible:
            _appVisible &&
            _surfaceVisible &&
            state.activeId == entry.profile.id,
      );
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

  Future<void> _pump(
    _SessionEntry entry,
    int generation,
    ffi.RemoteDesktopSessionHandle handle,
  ) async {
    while (_isCurrent(entry, generation) && identical(entry.handle, handle)) {
      final event = await handle.nextEvent();
      if (event == null || !_isCurrent(entry, generation)) break;
      switch (event) {
        case ffi.RemoteDesktopEvent_ConnectionState(:final state, :final attempt):
          if (state == ffi.RemoteDesktopConnectionState.connected) {
            entry.retryCount = 0;
          }
          _replaceView(
            entry.profile.id,
            (view) => view.copyWith(
              connectionState: state,
              reconnectAttempt: attempt,
              clearError: state == ffi.RemoteDesktopConnectionState.connected,
              clearEndReason: state == ffi.RemoteDesktopConnectionState.connected,
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
            (view) => view.copyWith(
              cursor: view.cursor.copyWith(visible: false),
            ),
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
    final current = state.sessions[id];
    if (current == null) return;
    state = state.put(update(current));
  }

  void _syncVisibility() {
    if (_disposed || !ref.mounted) return;
    final activeId = state.activeId;
    var next = state;
    for (final session in state.sessions.values) {
      final visible =
          session.id == activeId && _appVisible && _surfaceVisible;
      _entries[session.id]?.handle?.setVisible(
        visible: visible,
      );
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
  });

  RemoteDesktopProfile profile;
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

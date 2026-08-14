import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

part 'adhoc_ssh.g.dart';

/// A host the Agent connected to for this conversation, which is not — or not
/// yet — a server in the app.
///
/// Held open across tool calls on purpose. The reason this exists at all is a
/// sequence: test the connection, install something, then configure the
/// server. Reconnecting per call would re-authenticate, re-ask for the host
/// key and re-ask for the password every time.
@immutable
class AdHocSshSession {
  const AdHocSshSession({
    required this.id,
    required this.spi,
    required this.client,
    this.fingerprint,
  });

  /// What tool calls name this connection by. Opaque, and meaningless after a
  /// restart — see [AdHocSshSessions].
  final String id;

  /// Carries the password. Never persisted, and never put in a tool result:
  /// tool arguments and results are written into the conversation verbatim.
  ///
  /// Its [Spi.id] is generated up front rather than when the host is saved, so
  /// that the host key accepted now is filed under the same key the saved
  /// server will use and the user is not asked about it twice.
  final Spi spi;

  final SSHClient client;

  /// The host key the user accepted, when they were asked. Null for a host
  /// already known, which is not asked about again.
  final String? fingerprint;

  String get label => '${spi.ssh?.user}@${spi.ssh?.ip}:${spi.ssh?.port}';

  /// Builds the unsaved server this session runs on.
  static Spi spiFor({
    required String host,
    required int port,
    required String user,
    required String? password,
  }) {
    return Spi(
      name: '$user@$host',
      id: ShortId.generate(),
      ssh: SshCredential(ip: host, port: port, user: user, pwd: password),
    );
  }
}

/// Every host the Agent has open that is not a configured server.
///
/// In memory only. Nothing here is written to storage, so a restart ends every
/// one of them — which is also why a `session_id` from a restored conversation
/// resolves to nothing rather than to somebody else's connection.
@Riverpod(keepAlive: true)
class AdHocSshSessions extends _$AdHocSshSessions {
  /// The same map as [state], kept separately so that tearing the provider
  /// down can still close what is open: [state] cannot be read once disposal
  /// has begun, and that is exactly when the clients need closing.
  final _open = <String, AdHocSshSession>{};

  @override
  Map<String, AdHocSshSession> build() {
    _open.clear();
    ref.onDispose(_closeEveryClient);
    return const {};
  }

  void add(AdHocSshSession session) {
    _open[session.id] = session;
    _publish();
  }

  /// Ends one and forgets it. Safe to call for an id that is already gone.
  void close(String id) {
    final session = _open.remove(id);
    if (session == null) return;
    _publish();
    _close(session);
  }

  void closeAll() {
    if (_open.isEmpty) return;
    _closeEveryClient();
    _publish();
  }

  void _publish() => state = Map.unmodifiable(_open);

  void _closeEveryClient() {
    final sessions = _open.values.toList(growable: false);
    _open.clear();
    sessions.forEach(_close);
  }

  void _close(AdHocSshSession session) {
    try {
      session.client.close();
    } catch (e) {
      // Already gone. Nothing above this can act on it either way, and the
      // session is out of the map regardless.
      Loggers.app.warning('Closing ad-hoc SSH session ${session.label}', e);
    }
  }
}

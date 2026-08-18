import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

/// One end of a transfer: somewhere files live, and a path in it.
///
/// Serializable, because a transfer runs in an isolate and a live `SSHClient`
/// does not cross one. What travels is everything needed to *build* the
/// backend on the other side, which is why [SftpFileRef] carries a whole
/// credential bundle rather than a connection.
///
/// The counterpart of `FileBackend`: that one is a connection somebody already
/// has, this one is a description of how to get it.
sealed class FileRef {
  const FileRef();

  String get path;

  /// The last component. What a transfer list calls the job.
  String get name {
    final normalized = path.replaceAll(r'\', '/');
    final trimmed = normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    // The root has no last component but is still somewhere; without this it
    // would name itself the empty string.
    if (trimmed == '/') return '/';
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  /// A path inside this one, for naming a destination after its source.
  FileRef child(String name);
}

/// This device.
final class LocalFileRef extends FileRef {
  const LocalFileRef(this.path);

  @override
  final String path;

  @override
  LocalFileRef child(String name) =>
      LocalFileRef(path.joinPath(name, separator: '/'));

  @override
  bool operator ==(Object other) =>
      other is LocalFileRef && other.path == path;

  @override
  int get hashCode => Object.hash(LocalFileRef, path);

  @override
  String toString() => 'LocalFileRef($path)';
}

/// A server, over SFTP.
final class SftpFileRef extends FileRef {
  const SftpFileRef({required this.creds, required this.path});

  /// Built from a server the app knows about, resolving its keys now, on the
  /// isolate that has the stores.
  factory SftpFileRef.forServer(Spi spi, String path) =>
      SftpFileRef(creds: SshTransferCreds.forServer(spi), path: path);

  final SshTransferCreds creds;

  @override
  final String path;

  Spi get spi => creds.spi;

  /// Always `/`: the far side is a Linux-like system, whatever this device is.
  @override
  SftpFileRef child(String name) =>
      SftpFileRef(creds: creds, path: path.joinPath(name, separator: '/'));

  @override
  bool operator ==(Object other) =>
      other is SftpFileRef && other.path == path && other.spi.id == spi.id;

  @override
  int get hashCode => Object.hash(SftpFileRef, spi.id, path);

  @override
  String toString() => 'SftpFileRef(${spi.id}:$path)';
}

/// A server, through its `monitor` agent's file API.
///
/// Carries the credential rather than a client, for the same reason
/// [SftpFileRef] carries one — except that this one need not cross an isolate
/// at all: the agent is reached over HTTPS, whose crypto is native rather than
/// pure Dart, so a transfer with this at either end does not peg the UI
/// thread the way an SSH one would.
final class MonitorFileRef extends FileRef {
  const MonitorFileRef({required this.spi, required this.monitor, required this.path});

  factory MonitorFileRef.forServer(Spi spi, String path) {
    final credential = ServerConnectCredential.fromSpi(spi);
    return MonitorFileRef(
      spi: spi,
      monitor: (credential as ServerConnectCredentialMonitorHttp).monitor,
      path: path,
    );
  }

  final Spi spi;
  final MonitorHttpCredential monitor;

  @override
  final String path;

  /// Always `/`: the agent describes a POSIX-shaped filesystem whatever it is
  /// running on.
  @override
  MonitorFileRef child(String name) => MonitorFileRef(
    spi: spi,
    monitor: monitor,
    path: path.joinPath(name, separator: '/'),
  );

  @override
  bool operator ==(Object other) =>
      other is MonitorFileRef && other.path == path && other.spi.id == spi.id;

  @override
  int get hashCode => Object.hash(MonitorFileRef, spi.id, path);

  @override
  String toString() => 'MonitorFileRef(${spi.id}:$path)';
}

/// Everything needed to open an SSH connection somewhere else.
///
/// Read out of the stores when the transfer is queued rather than when it
/// runs, because the isolate that runs it has no stores — this is the whole
/// reason a transfer carries a bundle and not a server id.
class SshTransferCreds {
  SshTransferCreds.forServer(this.spi) {
    privateKeysByKeyId = {};

    final keyId = spi.ssh?.keyId;
    if (keyId != null) {
      privateKey = getPrivateKey(keyId);
      if (privateKey != null) privateKeysByKeyId![keyId] = privateKey!;
    }

    final allServers = {
      for (final server in Stores.server.fetch()) server.id: server,
    };
    jumpSpisById = collectJumpServers(spi: spi, serversById: allServers);

    final firstJumpId = spi.firstJumpId;
    if (firstJumpId != null) {
      jumpSpi = jumpSpisById?[firstJumpId];
      jumpPrivateKey = Stores.key.fetchOne(jumpSpi?.ssh?.keyId)?.key;
      if (jumpSpi?.ssh?.keyId case final jumpKeyId?) {
        if (jumpPrivateKey != null) {
          privateKeysByKeyId![jumpKeyId] = jumpPrivateKey!;
        }
      }
    }

    for (final jump in jumpSpisById?.values ?? const <Spi>[]) {
      final jumpKeyId = jump.ssh?.keyId;
      if (jumpKeyId == null || privateKeysByKeyId!.containsKey(jumpKeyId)) {
        continue;
      }
      final key = Stores.key.fetchOne(jumpKeyId)?.key;
      if (key == null) continue;
      privateKeysByKeyId![jumpKeyId] = key;
    }

    if (jumpSpisById != null && jumpSpisById!.isEmpty) jumpSpisById = null;
    if (privateKeysByKeyId != null && privateKeysByKeyId!.isEmpty) {
      privateKeysByKeyId = null;
    }

    try {
      knownHostFingerprints = Map<String, String>.from(
        Stores.setting.sshKnownHostFingerprints.get(),
      );
    } catch (e, s) {
      Loggers.app.warning('Failed to load SSH known host fingerprints', e, s);
      knownHostFingerprints = null;
    }
  }

  final Spi spi;
  String? privateKey;
  Spi? jumpSpi;
  String? jumpPrivateKey;
  Map<String, Spi>? jumpSpisById;
  Map<String, String>? privateKeysByKeyId;
  Map<String, String>? knownHostFingerprints;
}

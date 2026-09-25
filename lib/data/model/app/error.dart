import 'package:fl_lib/fl_lib.dart';
import 'package:redfish/redfish.dart' show CertInfo;
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

enum SSHErrType {
  unknown,
  connect,
  auth,
  interactiveAuth,
  noPrivateKey,
  segments,
  writeScript,
  getStatus,
}

class SSHErr extends Err<SSHErrType> {
  const SSHErr({required super.type, super.message});

  @override
  String? get solution => switch (type) {
    SSHErrType.auth => l10n.authFailTip,
    SSHErrType.interactiveAuth =>
        '${libL10n.authRequired}. ${libL10n.tapToAuth}.',
    SSHErrType.writeScript => l10n.writeScriptFailTip,
    SSHErrType.noPrivateKey => l10n.noPrivateKeyTip,
    _ => null,
  };
}

enum LocalServerErrType {
  /// This build cannot run processes on this device — see
  /// `LocalServer.isSupported`. What a synced or restored local server reads
  /// as on a phone.
  unsupported,
  writeScript,
  getStatus,
}

/// Reading this device as a server failed. Its own type rather than an
/// [SSHErr], because the advice SSH errors carry — keys, passwords, sshd — is
/// about a connection this server does not make.
class LocalServerErr extends Err<LocalServerErrType> {
  const LocalServerErr({required super.type, super.message});

  @override
  String? get solution => switch (type) {
    LocalServerErrType.unsupported => l10n.localServerUnsupported,
    LocalServerErrType.writeScript => l10n.writeScriptFailTip,
    LocalServerErrType.getStatus => null,
  };
}

enum ContainerErrType {
  unknown,
  noClient,
  notInstalled,
  invalidVersion,
  segmentsNotMatch,
  parsePs,
  parseImages,
  parseStats,
  podmanDetected,
  sudoPasswordRequired,
  sudoPasswordIncorrect,
}

class ContainerErr extends Err<ContainerErrType> {
  const ContainerErr({required super.type, super.message});

  /// What to say instead of the type's name.
  ///
  /// The page shows this where a list would have been, so it has to read as a
  /// sentence about the machine rather than as an error class: "no container
  /// runtime here" is something the user can act on, `ContainerErr<unknown>`
  /// is not.
  String get title => switch (type) {
    ContainerErrType.notInstalled => l10n.containerNoRuntime,
    ContainerErrType.noClient => l10n.serverUnreachable,
    ContainerErrType.sudoPasswordRequired => l10n.containerSudoPasswordRequired,
    ContainerErrType.sudoPasswordIncorrect =>
      l10n.containerSudoPasswordIncorrect,
    ContainerErrType.invalidVersion ||
    ContainerErrType.segmentsNotMatch ||
    ContainerErrType.parsePs ||
    ContainerErrType.parseImages ||
    ContainerErrType.parseStats => l10n.containerUnreadable,
    ContainerErrType.podmanDetected => l10n.switchTo('Podman'),
    ContainerErrType.unknown => libL10n.error,
  };

  @override
  String? get solution => switch (type) {
    ContainerErrType.notInstalled => l10n.containerNoRuntimeTip,
    _ => null,
  };
}

enum MonitorHttpErrType {
  unknown,
  net,
  loginFailed,
  auth,
  invalidResponse,

  /// The agent answered, and its `remote_access` grants withhold what was
  /// asked for: a command, a terminal, or a relayed connection. A 403 from
  /// `/exec` or `/ws-ticket` — never retried, since only its config changes
  /// the answer.
  notGranted,
}

class MonitorHttpErr extends Err<MonitorHttpErrType> {
  const MonitorHttpErr({required super.type, super.message});

  @override
  String? get solution => switch (type) {
    MonitorHttpErrType.auth => l10n.authFailTip,
    MonitorHttpErrType.notGranted => l10n.monitorNoRemoteAccess,
    _ => null,
  };
}

enum ServerTcpErrType {
  /// The agent will not relay a connection: its `stream` grant is off, or it
  /// predates the endpoint. Decided before anything is dialled.
  relayNotGranted,

  /// The caller does not use this transport for what it is connecting — a
  /// remote desktop to this device, say.
  notOffered,

  /// This device is the server, but this build cannot stand for it — see
  /// `LocalServer.isSupported`. A local server synced onto a phone names
  /// another machine, and dialling `localhost` there would reach the phone.
  localUnsupported,

  /// The transport was tried and could not open the connection.
  dial,
}

/// A TCP connection to an address as seen from a server could not be opened.
///
/// Names the [transport] that failed, and, when the server has two, what
/// happened on the [other] one: a server given both sets of credentials was
/// tried both ways, and the second failure alone would hide why the first did
/// not answer.
class ServerTcpErr extends Err<ServerTcpErrType> {
  const ServerTcpErr({
    required super.type,
    required this.transport,
    super.message,
    this.cause,
    this.other,
  });

  final ServerTransport transport;

  /// What the transport threw, for a [ServerTcpErrType.dial].
  final Object? cause;

  /// The other transport's failure, when there was a second one to try.
  final ServerTcpErr? other;

  @override
  String? get solution => switch (type) {
    ServerTcpErrType.relayNotGranted => l10n.monitorNoRemoteAccess,
    ServerTcpErrType.localUnsupported => l10n.localServerUnsupported,
    _ => cause is Err ? (cause as Err).solution : null,
  };

  @override
  String toString() {
    final head = '$runtimeType<${type.name}> over ${transport.name}: $message';
    final other = this.other;
    return other == null ? head : '$head; also $other';
  }
}

enum VirtErrType {
  /// The host could not be reached: the transport failed (see
  /// [VirtErr.cause], often a [ServerTcpErr]), or the API did not answer.
  unreachable,

  /// The server has no usable configuration for this host — no PVE address,
  /// no password or token to log in with.
  notConfigured,

  /// The server this host was is gone — deleted, here or by a sync. Nothing
  /// is retried and there is nothing to edit.
  serverRemoved,

  /// PVE refused the login, the session or the token (HTTP 401), or its
  /// permission check refused this account something the host view needs
  /// (HTTP 403 outside a guest action — which keeps the session).
  authFailed,

  /// PVE wants a TOTP code: `VirtHostNotifier.submitTfa`.
  needTfa,

  /// The PVE certificate is not signed by a trusted CA and none has been
  /// confirmed: [VirtErr.cert] is what the server presented, for
  /// `VirtHostNotifier.confirmCert`.
  certUnconfirmed,

  /// The PVE certificate is not the one confirmed before:
  /// [VirtErr.previousFingerprint] was pinned, [VirtErr.cert] is presented.
  certChanged,

  /// The monitor agent does not relay TCP connections, and nothing else
  /// reaches the PVE API.
  relayNotGranted,

  /// The monitor agent does not run commands (`full_access` is off), and
  /// nothing else reaches `virsh`.
  execNotGranted,

  /// `virsh` is not installed.
  notInstalled,

  /// libvirt refused this account, and sudo did not help (or there is none).
  permissionDenied,

  /// libvirt refused this account; sudo needs a password:
  /// `VirtHostNotifier.provideSudoPassword`.
  sudoPasswordRequired,

  /// The sudo password given was rejected.
  sudoPasswordRejected,

  /// The host answered with something this app cannot read.
  invalidResponse,

  /// A power action was refused or its task ended in an error; [message] is
  /// the host's own text.
  actionFailed,

  /// Not offered for this guest or host.
  unsupported,

  /// A new guest's name (or PVE VMID, or disk volume) is taken on the host.
  exists,
  unknown,
}

/// A Virtualization tab failure, for either backend.
///
/// What the UI branches on is [type]; the ones that need the user's input
/// ([VirtErrType.needTfa], [VirtErrType.certUnconfirmed],
/// [VirtErrType.certChanged], [VirtErrType.sudoPasswordRequired],
/// [VirtErrType.sudoPasswordRejected]) are [needsInput], and automatic
/// refreshes stop on them rather than repeating the same refusal.
class VirtErr extends Err<VirtErrType> {
  const VirtErr({
    required super.type,
    super.message,
    this.cause,
    this.cert,
    this.previousFingerprint,
  });

  /// What the transport or the parser threw.
  final Object? cause;

  /// The certificate PVE presented, for [VirtErrType.certUnconfirmed] and
  /// [VirtErrType.certChanged].
  final CertInfo? cert;

  /// The fingerprint that was pinned, for [VirtErrType.certChanged].
  final String? previousFingerprint;

  bool get needsInput => switch (type) {
    VirtErrType.needTfa ||
    VirtErrType.certUnconfirmed ||
    VirtErrType.certChanged ||
    VirtErrType.sudoPasswordRequired ||
    VirtErrType.sudoPasswordRejected ||
    VirtErrType.authFailed ||
    VirtErrType.notConfigured => true,
    _ => false,
  };

  @override
  String? get solution => switch (type) {
    VirtErrType.relayNotGranted ||
    VirtErrType.execNotGranted => l10n.monitorNoRemoteAccess,
    VirtErrType.unreachable => cause is Err ? (cause as Err).solution : null,
    _ => null,
  };
}

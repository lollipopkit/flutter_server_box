import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';

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

enum PveErrType { unknown, net, loginFailed, needTfa, invalidResponse }

class PveErr extends Err<PveErrType> {
  const PveErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum MonitorHttpErrType { unknown, net, loginFailed, auth, invalidResponse }

class MonitorHttpErr extends Err<MonitorHttpErrType> {
  const MonitorHttpErr({required super.type, super.message});

  @override
  String? get solution => switch (type) {
    MonitorHttpErrType.auth => l10n.authFailTip,
    _ => null,
  };
}

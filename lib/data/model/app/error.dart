import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum SSHErrType { unknown, connect, auth, noPrivateKey, chdir, segements, writeScript, getStatus }

class SSHErr extends Err<SSHErrType> {
  const SSHErr({required super.type, super.message});

  @override
  String? get solution => switch (type) {
    SSHErrType.chdir => l10n.needHomeDir,
    SSHErrType.auth => l10n.authFailTip,
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
  cmdNoPrefix,
  segmentsNotMatch,
  parsePs,
  parseImages,
  parseStats,
  podmanDetected,
}

class ContainerErr extends Err<ContainerErrType> {
  const ContainerErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum ICloudErrType { generic, notFound, multipleFiles }

class ICloudErr extends Err<ICloudErrType> {
  const ICloudErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum WebdavErrType { generic, notFound }

class WebdavErr extends Err<WebdavErrType> {
  const WebdavErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum PveErrType { unknown, net, loginFailed }

class PveErr extends Err<PveErrType> {
  const PveErr({required super.type, super.message});

  @override
  String? get solution => null;
}

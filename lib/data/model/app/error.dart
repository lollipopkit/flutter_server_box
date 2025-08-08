import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum SSHErrType { unknown, connect, auth, noPrivateKey, chdir, segements, writeScript, getStatus }

class SSHErr extends Err<SSHErrType> {
  SSHErr({required super.type, super.message});

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
}

class ContainerErr extends Err<ContainerErrType> {
  ContainerErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum ICloudErrType { generic, notFound, multipleFiles }

class ICloudErr extends Err<ICloudErrType> {
  ICloudErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum WebdavErrType { generic, notFound }

class WebdavErr extends Err<WebdavErrType> {
  WebdavErr({required super.type, super.message});

  @override
  String? get solution => null;
}

enum PveErrType { unknown, net, loginFailed }

class PveErr extends Err<PveErrType> {
  PveErr({required super.type, super.message});

  @override
  String? get solution => null;
}

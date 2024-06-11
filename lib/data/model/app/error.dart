import 'package:server_box/core/extension/context/locale.dart';

enum ErrFrom {
  unknown,
  apt,
  docker,
  sftp,
  ssh,
  status,
  icloud,
  webdav,
  ;
}

abstract class Err<T> {
  final ErrFrom from;
  final T type;
  final String? message;

  String? get solution;

  Err({required this.from, required this.type, this.message});
}

enum SSHErrType {
  unknown,
  connect,
  auth,
  noPrivateKey,
  chdir,
  segements,
  writeScript,
  getStatus,
  ;
}

class SSHErr extends Err<SSHErrType> {
  SSHErr({required super.type, super.message}) : super(from: ErrFrom.ssh);

  @override
  String? get solution => switch (type) {
        SSHErrType.chdir => l10n.needHomeDir,
        SSHErrType.auth => l10n.authFailTip,
        SSHErrType.writeScript => l10n.writeScriptFailTip,
        SSHErrType.noPrivateKey => l10n.noPrivateKeyTip,
        _ => null,
      };

  @override
  String toString() {
    return 'SSHErr<$type>: $message';
  }
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
  ContainerErr({required super.type, super.message})
      : super(from: ErrFrom.docker);

  @override
  String? get solution => null;

  @override
  String toString() {
    return 'ContainerErr<$type>: $message';
  }
}

enum ICloudErrType {
  generic,
  notFound,
  multipleFiles,
}

class ICloudErr extends Err<ICloudErrType> {
  ICloudErr({required super.type, super.message}) : super(from: ErrFrom.icloud);

  @override
  String? get solution => null;

  @override
  String toString() {
    return 'ICloudErr<$type>: $message';
  }
}

enum WebdavErrType {
  generic,
  notFound,
  ;
}

class WebdavErr extends Err<WebdavErrType> {
  WebdavErr({required super.type, super.message}) : super(from: ErrFrom.webdav);

  @override
  String? get solution => null;

  @override
  String toString() {
    return 'WebdavErr<$type>: $message';
  }
}

enum PveErrType {
  unknown,
  net,
  loginFailed,
  ;
}

class PveErr extends Err<PveErrType> {
  PveErr({required super.type, super.message}) : super(from: ErrFrom.status);

  @override
  String? get solution => null;

  @override
  String toString() {
    return 'PveErr<$type>: $message';
  }
}

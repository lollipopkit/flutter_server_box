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

  Err({required this.from, required this.type, this.message});
}

enum SSHErrType {
  unknown,
  connect,
  noPrivateKey;
}

class SSHErr extends Err<SSHErrType> {
  SSHErr({required super.type, super.message}) : super(from: ErrFrom.ssh);

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
  parsePsItem,
  parseImages,
  parseStats,
}

class ContainerErr extends Err<ContainerErrType> {
  ContainerErr({required super.type, super.message}) : super(from: ErrFrom.docker);

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
  String toString() {
    return 'WebdavErr<$type>: $message';
  }
}

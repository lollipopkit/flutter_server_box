enum ErrFrom {
  unknown,
  apt,
  docker,
  sftp,
  ssh,
  status;
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
  SSHErr({required SSHErrType type, String? message})
      : super(from: ErrFrom.ssh, type: type, message: message);

  @override
  String toString() {
    return 'SSHErr<$type>: $message';
  }
}

enum DockerErrType {
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

class DockerErr extends Err<DockerErrType> {
  DockerErr({required DockerErrType type, String? message})
      : super(from: ErrFrom.docker, type: type, message: message);

  @override
  String toString() {
    return 'DockerErr<$type>: $message';
  }
}

enum ICloudErrType {
  generic,
  notFound,
  multipleFiles,
}

class ICloudErr extends Err<ICloudErrType> {
  ICloudErr({required ICloudErrType type, String? message})
      : super(from: ErrFrom.docker, type: type, message: message);

  @override
  String toString() {
    return 'ICloudErr<$type>: $message';
  }
}

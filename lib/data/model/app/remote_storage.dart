abstract class RemoteStorage {
  Future<Error> upload({
    required String relativePath,
    String? localPath
  });

  Future<Error> download({
    required String relativePath,
    String? localPath
  });

  Future<Error> delete(String relativePath);
}

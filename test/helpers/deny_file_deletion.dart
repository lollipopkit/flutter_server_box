import 'dart:io';

/// Fails deletion of one real file without relying on platform permissions.
final class DenyFileDeletion extends IOOverrides {
  DenyFileDeletion(this.file);

  final File file;
  bool attempted = false;

  @override
  File createFile(String path) => path == file.path
      ? _UndeletableFile(file, () => attempted = true)
      : super.createFile(path);
}

class _UndeletableFile implements File {
  _UndeletableFile(this.file, this.onDelete);

  final File file;
  final void Function() onDelete;

  @override
  bool existsSync() => file.existsSync();

  @override
  void deleteSync({bool recursive = false}) {
    onDelete();
    throw FileSystemException('Deletion refused by the filesystem', file.path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

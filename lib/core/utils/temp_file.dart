import 'dart:io';

/// [run] with a path named [name] in a directory of its own, removed after.
Future<T> withTempFile<T>(String name, Future<T> Function(String path) run) async {
  final dir = await Directory.systemTemp.createTemp('sb-sync-');
  try {
    return await run('${dir.path}/$name');
  } finally {
    await dir.delete(recursive: true);
  }
}

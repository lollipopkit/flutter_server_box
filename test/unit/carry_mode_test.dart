import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// A filesystem that is a map, so what a staged replace does to a mode can be
/// asserted without a server on the other end.
final class _FakeBackend implements FileBackend {
  _FakeBackend({
    this.permissions = true,
    this.statThrows = false,
    this.chmodThrows = false,
  });

  final bool permissions;
  final bool statThrows;
  final bool chmodThrows;

  final entries = <String, FileEntry>{};

  /// Every path this was asked to chmod, and to what.
  final chmods = <String, int>{};

  @override
  FileBackendTraits get traits => FileBackendTraits(permissions: permissions);

  @override
  Future<FileEntry?> stat(String path) async {
    if (statThrows) throw StateError('cannot stat $path');
    return entries[path];
  }

  @override
  Future<void> chmod(String path, int mode) async {
    if (chmodThrows) throw StateError('cannot chmod $path');
    chmods[path] = mode;
  }

  @override
  Future<List<String>> reachableRoots() async => const [];
  @override
  Future<List<FileEntry>> list(String path) async => const [];
  @override
  Future<void> mkdir(String path) async {}
  @override
  Future<void> remove(String path, {bool recursive = false}) async {}
  @override
  Future<void> rename(String from, String to) async {}
  @override
  Stream<List<int>> read(String path, {int offset = 0}) => const Stream.empty();
  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    Stream<List<int>> Function()? replayData,
  }) async {}
  @override
  Future<void> close() async {}
}

void main() {
  group('carrying a mode onto the staged copy', () {
    test('a replaced file keeps the permissions it had', () async {
      // The bug this exists for: the staged copy is created with the far
      // side's umask, and the rename carries that onto the destination — so
      // saving an edit to a script left it unrunnable.
      final backend = _FakeBackend();
      backend.entries['/srv/run.sh'] = const FileEntry(
        name: 'run.sh',
        kind: FileKind.file,
        mode: 0x1ED,
      );

      await carryModeToStaging(backend, '/srv/run.sh.sb-part-1', '/srv/run.sh');

      expect(backend.chmods, {'/srv/run.sh.sb-part-1': 0x1ED});
    });

    test('a file being created has no mode to keep', () async {
      final backend = _FakeBackend();

      await carryModeToStaging(backend, '/srv/new.txt.sb-part-1', '/srv/new.txt');

      // Not 0644 or anything else invented: a new file gets whatever the far
      // side's umask says, which is what every other tool does.
      expect(backend.chmods, isEmpty);
    });

    test('a destination that is a directory is left alone', () async {
      final backend = _FakeBackend();
      backend.entries['/srv/etc'] = const FileEntry(
        name: 'etc',
        kind: FileKind.dir,
        mode: 0x1ED,
      );

      await carryModeToStaging(backend, '/srv/etc.sb-part-1', '/srv/etc');

      expect(backend.chmods, isEmpty);
    });

    test('a backend with no permissions is not asked about them', () async {
      final backend = _FakeBackend(permissions: false, statThrows: true);

      // Not even a stat: `permissions: false` means there is nothing to read
      // and nothing to set, and a round trip to find that out is one this
      // device could have skipped.
      await carryModeToStaging(backend, '/x.sb-part-1', '/x');

      expect(backend.chmods, isEmpty);
    });

    test('a mode that cannot be read does not fail the write', () async {
      // The bytes are already across by the time this runs. A server that will
      // not report a mode must not be one where the file can never be saved.
      final backend = _FakeBackend(statThrows: true);

      await carryModeToStaging(backend, '/srv/x.sb-part-1', '/srv/x');

      expect(backend.chmods, isEmpty);
    });

    test('a mode that cannot be set does not fail the write either', () async {
      final backend = _FakeBackend(chmodThrows: true);
      backend.entries['/srv/x'] = const FileEntry(
        name: 'x',
        kind: FileKind.file,
        mode: 0x180,
      );

      await carryModeToStaging(backend, '/srv/x.sb-part-1', '/srv/x');
    });
  });
}

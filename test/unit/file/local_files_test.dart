import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_files.dart';

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('serverbox_local_files_');
    Paths.file = (await Directory('${root.path}/device').create()).path;
    LocalFiles.copyFileExclusiveForTesting =
        ({required source, required destination}) async {
          try {
            await File(destination).create(exclusive: true);
          } on PathExistsException {
            return false;
          }
          await File(source).copy(destination);
          return true;
        };
  });

  tearDownAll(() async {
    LocalFiles.resetCopyFileExclusiveForTesting();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('imports legacy files without moving or overwriting them', () async {
    final source = await Directory(
      '${root.path}/Documents/ServerBox',
    ).create(recursive: true);
    await File('${source.path}/note.txt').writeAsString('legacy');
    await Directory('${source.path}/server').create();
    await File('${source.path}/server/download.txt').writeAsString('nested');
    await File('${Paths.file}/current.txt').writeAsString('current');
    await File('${source.path}/current.txt').writeAsString('old');
    await File('${source.path}/collision.txt').writeAsString('imported');
    final unrelatedStaging = await File(
      '${Paths.file}/collision.txt.importing',
    ).writeAsString('user data');

    final imported = await LocalFiles.importFrom(source.path);

    expect(imported, 3);
    expect(await File('${Paths.file}/note.txt').readAsString(), 'legacy');
    expect(
      await File('${Paths.file}/server/download.txt').readAsString(),
      'nested',
    );
    expect(await File('${Paths.file}/current.txt').readAsString(), 'current');
    expect(await File('${source.path}/note.txt').readAsString(), 'legacy');
    expect(
      await File('${Paths.file}/collision.txt').readAsString(),
      'imported',
    );
    expect(await unrelatedStaging.readAsString(), 'user data');
    expect(
      await Directory(Paths.file)
          .list()
          .where((entry) => entry.path.contains('.serverbox-import-'))
          .isEmpty,
      isTrue,
    );
  });

  test('does not import symlinks outside the selected directory', () async {
    final source = await Directory('${root.path}/legacy').create();
    final outside = await File('${root.path}/outside.txt').writeAsString('x');
    await Link('${source.path}/outside.txt').create(outside.path);

    final imported = await LocalFiles.importFrom(source.path);

    expect(imported, 0);
    expect(
      await FileSystemEntity.type('${Paths.file}/outside.txt'),
      FileSystemEntityType.notFound,
    );
  });

  test('continues after one legacy entry cannot be copied', () async {
    if (Platform.isWindows) return;

    final source = await Directory('${root.path}/copy-failure').create();
    final socketPath = '${source.path}/broken.sock';
    final socket = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
    addTearDown(socket.close);
    await File('${source.path}/usable.txt').writeAsString('kept');

    final imported = await LocalFiles.importFrom(source.path);

    expect(imported, 1);
    expect(await File('${Paths.file}/usable.txt').readAsString(), 'kept');
  });
}

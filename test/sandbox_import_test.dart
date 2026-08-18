import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sandbox_import.dart';

/// The copy the unsandboxed macOS build does on its first launch.
///
/// Every dependency of [SandboxImport.importFrom] is passed in, so these run
/// against two temporary directories on any platform.
void main() {
  late Directory src;
  late Directory dest;
  var prefsImported = 0;

  setUp(() async {
    src = await Directory.systemTemp.createTemp('sandbox_src');
    dest = await Directory.systemTemp.createTemp('sandbox_dest');
    prefsImported = 0;
  });

  tearDown(() async {
    for (final dir in [src, dest]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  Future<SandboxImportResult> import({bool hasKey = true}) {
    return SandboxImport.importFrom(
      src: src,
      dest: dest,
      importPrefs: () async => prefsImported++,
      hasKey: () async => hasKey,
    );
  }

  Future<void> write(Directory dir, String name, [String data = 'x']) async {
    final file = File('${dir.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsString(data);
  }

  bool exists(String name) => File('${dest.path}/$name').existsSync();

  test('no container is not a failure', () async {
    await src.delete();
    expect(await import(), SandboxImportResult.notFound);
  });

  test('a container with no boxes has nothing to give', () async {
    await write(src, 'app.db');
    expect(await import(), SandboxImportResult.notFound);
    expect(exists(SandboxImport.doneMarker), false);
  });

  test('an install with data of its own is left alone', () async {
    await write(src, 'setting_enc.hive');
    await write(dest, 'setting_enc.hive', 'mine');
    expect(await import(), SandboxImportResult.skipped);
    expect(
      File('${dest.path}/setting_enc.hive').readAsStringSync(),
      'mine',
    );
  });

  test('the marker is remembered', () async {
    await write(src, 'setting_enc.hive');
    await write(dest, SandboxImport.doneMarker);
    expect(await import(), SandboxImportResult.skipped);
  });

  test('encrypted boxes are not copied without the key', () async {
    await write(src, 'setting_enc.hive');
    expect(await import(hasKey: false), SandboxImportResult.noKey);
    expect(exists('setting_enc.hive'), false);
    // The preferences are read first on purpose: an old enough install keeps
    // the box key there, and that read is what may supply it.
    expect(prefsImported, 1);
  });

  test('plain boxes are copied without asking for a key', () async {
    await write(src, 'conn_stats_index.hive');
    expect(await import(hasKey: false), SandboxImportResult.imported);
    expect(exists('conn_stats_index.hive'), true);
  });

  test('what is copied, and what is left behind', () async {
    await write(src, 'setting_enc.hive', 'boxes');
    await write(src, 'setting_enc.lock');
    await write(src, 'app.db');
    await write(src, '.DS_Store');
    await write(src, 'font/term.ttf', 'font');
    await write(src, 'cache/huge.bin');

    expect(await import(), SandboxImportResult.imported);

    expect(File('${dest.path}/setting_enc.hive').readAsStringSync(), 'boxes');
    expect(exists('app.db'), true);
    // Small, and `fontPath` points straight into it.
    expect(File('${dest.path}/font/term.ttf').readAsStringSync(), 'font');

    // A lock belongs to the process that held it.
    expect(exists('setting_enc.lock'), false);
    // Rebuilt on demand, and the biggest thing in there.
    expect(Directory('${dest.path}/cache').existsSync(), false);
    expect(exists('.DS_Store'), false);

    expect(exists(SandboxImport.doneMarker), true);
    expect(exists(SandboxImport.busyMarker), false);
  });

  test('an attempt that died halfway starts over', () async {
    await write(src, 'setting_enc.hive', 'whole');
    // What the last run left: a marker, and a box file that may be half a box.
    await write(dest, SandboxImport.busyMarker);
    await write(dest, 'setting_enc.hive', 'torn');
    await write(dest, 'history_enc.hive', 'torn');

    expect(await import(), SandboxImportResult.imported);

    expect(File('${dest.path}/setting_enc.hive').readAsStringSync(), 'whole');
    // Copied by the dead run, absent from the source: not data, leftovers.
    expect(exists('history_enc.hive'), false);
    expect(exists(SandboxImport.doneMarker), true);
    expect(exists(SandboxImport.busyMarker), false);
  });

  test('preference values are read the way each key is stored', () {
    expect(SandboxImport.parsePrefForTest('1', bool), true);
    expect(SandboxImport.parsePrefForTest('0', bool), false);
    expect(SandboxImport.parsePrefForTest('true\n', bool), true);
    expect(SandboxImport.parsePrefForTest('1480\n', int), 1480);
    expect(SandboxImport.parsePrefForTest('not a number', int), null);
    expect(SandboxImport.parsePrefForTest(' https://dav \n', String), 'https://dav');
    expect(SandboxImport.parsePrefForTest('  ', String), null);
  });

  test('sqlite\'s shared-memory file is not carried across', () async {
    // It describes a WAL index belonging to whatever process had the database
    // open. Copied, it either costs a rebuild or makes sqlite refuse; the WAL
    // itself is what the data is in, and that does come across.
    const db = SqliteDb.fileName;
    await write(src, db);
    await write(src, '$db-wal');
    await write(src, '$db-shm');
    // Not ours, and it only looks like a sidecar. Skipping by suffix took a
    // file of the user's with it.
    await write(src, 'notes-shm');

    expect(await import(), SandboxImportResult.imported);

    expect(exists(db), isTrue);
    expect(exists('$db-wal'), isTrue);
    expect(exists('$db-shm'), isFalse);
    expect(exists('notes-shm'), isTrue);
  });

  test('what the user downloaded stays where it is, and is named', () async {
    // Unbounded, and copying it is a first launch that looks like a hang. Not
    // deleted and not silent: the notice says where it stayed, which is the
    // difference between leaving files and losing them.
    await write(src, 'box.hive');
    await write(src, 'file/server-a/report.txt');
    await write(src, 'cache/thumb.png');
    await write(src, 'img/ssh_bg.png');

    expect(await import(), SandboxImportResult.imported);

    expect(exists('box.hive'), isTrue);
    // Settings point straight into this one, so a build without it names a
    // background image it does not have.
    expect(exists('img/ssh_bg.png'), isTrue);
    expect(exists('file/server-a/report.txt'), isFalse);
    expect(exists('cache/thumb.png'), isFalse);
    expect(SandboxImport.leftBehind, src.path);
  });

  test('an empty downloads directory is not worth mentioning', () async {
    await write(src, 'box.hive');
    await Directory('${src.path}/file').create(recursive: true);

    expect(await import(), SandboxImportResult.imported);

    expect(SandboxImport.leftBehind, isNull);
  });
}

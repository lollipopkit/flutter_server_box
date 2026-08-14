import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/spi_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileRef', () {
    test('names itself after its last component', () {
      expect(const LocalFileRef('/a/b/notes.txt').name, 'notes.txt');
      expect(const LocalFileRef('/a/b/').name, 'b');
      expect(const LocalFileRef('/').name, '/');
    });

    test('a child of a directory is a path inside it', () {
      expect(const LocalFileRef('/a/b').child('c.txt').path, '/a/b/c.txt');
    });

    test('two ends are the same place only when both halves match', () {
      expect(
        const LocalFileRef('/a/b') == const LocalFileRef('/a/b'),
        isTrue,
      );
      expect(
        const LocalFileRef('/a/b') == const LocalFileRef('/a/c'),
        isFalse,
      );
    });
  });

  group('where a transfer runs', () {
    late Directory tempDir;
    late Box<dynamic> settingBox;
    late Box<dynamic> serverBox;
    late Box<dynamic> keyBox;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('server-box-transfer-');
      Hive.init(tempDir.path);
      settingBox = await Hive.openBox<dynamic>('setting_test');
      serverBox = await Hive.openBox<dynamic>('server_test');
      keyBox = await Hive.openBox<dynamic>('key_test');
      getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
      // Building an `SftpFileRef` reads keys and jump servers out of these,
      // which is the work these tests are checking happens on this side.
      getIt.registerSingleton<ServerStore>(ServerStore.forBox(serverBox));
      getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forBox(keyBox));
    });

    tearDown(() async {
      await getIt.reset();
      await settingBox.close();
      await serverBox.close();
      await keyBox.close();
      await tempDir.delete(recursive: true);
    });

    test('a copy within this device needs no isolate', () {
      final job = FileTransfer(
        from: const LocalFileRef('/a/x'),
        to: const LocalFileRef('/b/x'),
      );

      // The isolate exists because SSH's symmetric crypto is pure Dart and
      // would peg the UI thread. A file copy has none of it.
      expect(job.needsIsolate, isFalse);
    });

    test('anything with a server at either end needs one', () {
      final spi = spiFixture(name: 'srv', id: 'srv', ip: '10.0.0.1');
      final remote = SftpFileRef.forServer(spi, '/tmp/x');

      expect(
        FileTransfer(from: const LocalFileRef('/a/x'), to: remote).needsIsolate,
        isTrue,
      );
      expect(
        FileTransfer(from: remote, to: const LocalFileRef('/a/x')).needsIsolate,
        isTrue,
      );
      expect(
        FileTransfer(
          from: remote,
          to: SftpFileRef.forServer(spiFixture(name: 'other', id: 'other', ip: '10.0.0.2'), '/tmp/y'),
        ).needsIsolate,
        isTrue,
      );
    });

    test('a local copy really copies, reporting the same events', () async {
      final source = File('${tempDir.path}/source.bin')
        ..writeAsBytesSync(List<int>.generate(4096, (i) => i % 256));
      final destPath = '${tempDir.path}/nested/dest.bin';
      await Directory('${tempDir.path}/nested').create();

      final done = Completer<void>();
      final status = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef(source.path),
          to: LocalFileRef(destPath),
        ),
        notifyListeners: () {},
        completer: done,
      );
      // The status object is what the list watches; the events are what it
      // watches for.
      await done.future.timeout(const Duration(seconds: 10));

      expect(status.status, FileTransferStage.finished);
      expect(status.error, isNull);
      expect(status.size, 4096);
      expect(status.transferredBytes, 4096);
      expect(File(destPath).readAsBytesSync(), source.readAsBytesSync());
      // No isolate was started for it.
      expect(status.worker, isNull);
    });

    test('a local copy that cannot read reports the failure', () async {
      final status = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef('${tempDir.path}/not-there'),
          to: LocalFileRef('${tempDir.path}/out'),
        ),
        notifyListeners: () {},
      );

      // Polled rather than awaited: a failure disposes without completing a
      // completer nobody passed.
      for (var i = 0; i < 100 && status.error == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(status.error, isNotNull);
      expect(File('${tempDir.path}/out').existsSync(), isFalse);
    });
  });

  group('the files capability', () {
    test('SSH carries files; a monitor agent does not, yet', () {
      expect(const SshCapabilities().files, isTrue);
      expect(
        const MonitorHttpCapabilities(MonitorRemoteAccess()).files,
        isFalse,
      );
      // Even a fully granting agent: there is no file endpoint to grant.
      expect(
        const MonitorHttpCapabilities(
          MonitorRemoteAccess(fullAccess: true),
        ).files,
        isFalse,
      );
    });
  });
}

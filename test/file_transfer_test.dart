import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_status.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

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

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('server-box-transfer-');
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore.forTest());
      // Building an `SftpFileRef` reads keys and jump servers out of these,
      // which is the work these tests are checking happens on this side.
      getIt.registerSingleton<ServerStore>(ServerStore.forTest());
      getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forTest());
    });

    tearDown(() async {
      await getIt.reset();
    await SqliteDb.close();
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

    test('only SSH needs an isolate', () {
      // The isolate exists because SSH's symmetric crypto is pure Dart. A
      // monitor agent is reached over HTTPS, whose crypto is native, so a
      // transfer through one has no reason to leave this isolate.
      final monitor = MonitorFileRef.forServer(
        Spi(
          name: 'agent',
          id: 'agent',
          monitorHttp: const MonitorHttpCredential(
            addr: 'https://10.0.0.3:3770',
          ),
        ),
        '/srv/data/x',
      );

      expect(
        FileTransfer(from: monitor, to: const LocalFileRef('/a/x')).needsIsolate,
        isFalse,
      );
      expect(
        FileTransfer(from: const LocalFileRef('/a/x'), to: monitor).needsIsolate,
        isFalse,
      );
    });

    test('anything with SSH at either end needs one', () {
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

    test('a folder copies as a whole tree, on this isolate', () async {
      await Directory('${tempDir.path}/src/deep').create(recursive: true);
      File('${tempDir.path}/src/one.txt').writeAsStringSync('hello');
      File('${tempDir.path}/src/deep/two.txt').writeAsStringSync('world');

      final done = Completer<void>();
      final status = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef('${tempDir.path}/src'),
          to: LocalFileRef('${tempDir.path}/dst'),
          isDir: true,
        ),
        notifyListeners: () {},
        completer: done,
      );
      await done.future.timeout(const Duration(seconds: 10));

      expect(status.error, isNull);
      expect(status.size, 10, reason: 'both files, counted before copying');
      expect(status.transferredBytes, 10);
      expect(
        File('${tempDir.path}/dst/deep/two.txt').readAsStringSync(),
        'world',
      );
    });

    test('a folder never takes the single-file fast path', () {
      final job = FileTransfer(
        from: SftpFileRef.forServer(
          spiFixture(name: 'srv', id: 'srv', ip: '10.0.0.1'),
          '/var/log',
        ),
        to: const LocalFileRef('/tmp/log'),
        isDir: true,
      );

      // The download path moves one file: segmented reads and one write handle
      // are what makes it fast, and neither generalises to a tree.
      expect(job.isSingleFile, isFalse);
    });

    test('cancelling a local copy actually stops it', () async {
      // The isolate is stopped by killing it; a copy running here has to be
      // asked. Without that, cancelling removed the row and left it running.
      await Directory('${tempDir.path}/src').create();
      for (var i = 0; i < 40; i++) {
        File('${tempDir.path}/src/f$i.bin')
            .writeAsBytesSync(List<int>.filled(64 * 1024, 7));
      }

      final status = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef('${tempDir.path}/src'),
          to: LocalFileRef('${tempDir.path}/dst'),
          isDir: true,
        ),
        notifyListeners: () {},
      );

      // Once it is moving, pull the plug.
      for (var i = 0; i < 200 && (status.transferredBytes ?? 0) == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      status.dispose();
      final atCancel = status.transferredBytes ?? 0;

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(status.status, isNot(FileTransferStage.finished));
      expect(
        status.transferredBytes,
        atCancel,
        reason: 'nothing moved after the cancel',
      );
      // And it is not reported as a failure: the user asked for this.
      expect(status.error, isNull);
      // Nothing half-written left under a final name.
      final left = Directory('${tempDir.path}/dst')
          .listSync()
          .where((e) => e.path.contains('sb-part'));
      expect(left, isEmpty);
    });

    test('two transfers queued together get different ids', () async {
      // `DateTime.now()` advances in millisecond steps on Windows, so two
      // transfers queued in one tap used to share an id — after which `get(id)`
      // threw out of `singleWhere`, was swallowed, and a failed transfer was
      // read as having succeeded.
      File('${tempDir.path}/a').writeAsStringSync('a');
      File('${tempDir.path}/b').writeAsStringSync('b');

      final firstDone = Completer<void>();
      final secondDone = Completer<void>();
      final first = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef('${tempDir.path}/a'),
          to: LocalFileRef('${tempDir.path}/a2'),
        ),
        notifyListeners: () {},
        completer: firstDone,
      );
      final second = FileTransferStatus(
        job: FileTransfer(
          from: LocalFileRef('${tempDir.path}/b'),
          to: LocalFileRef('${tempDir.path}/b2'),
        ),
        notifyListeners: () {},
        completer: secondDone,
      );

      expect(first.id, isNot(second.id));
      await Future.wait([
        firstDone.future,
        secondDone.future,
      ]).timeout(const Duration(seconds: 10));
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
    test('SSH carries files, and an agent carries them if it says so', () {
      expect(const SshCapabilities().files, isTrue);

      // The agent's own answer, not `full_access` read twice: its file API is
      // confined to the roots its operator named, so it can be on while the
      // shell is off — and off while the shell is on.
      expect(
        const MonitorHttpCapabilities(MonitorRemoteAccess()).files,
        isFalse,
      );
      expect(
        const MonitorHttpCapabilities(
          MonitorRemoteAccess(fullAccess: true),
        ).files,
        isFalse,
      );
      expect(
        const MonitorHttpCapabilities(MonitorRemoteAccess(files: true)).files,
        isTrue,
      );
    });

    test('an agent that serves files still carries no byte stream', () {
      // Which is the whole case the endpoint exists for: a host with no
      // reachable sshd. The file tab must open it, and port forwarding must
      // not be offered on it.
      const caps = MonitorHttpCapabilities(MonitorRemoteAccess(files: true));

      expect(caps.files, isTrue);
      expect(caps.byteStream, isFalse);
    });

    test('an older agent grants nothing it was never asked about', () {
      // `/capabilities` without a `files` field at all.
      final granted = MonitorRemoteAccess.fromJson(const {
        'terminal': true,
      });

      expect(granted.files, isFalse);
    });
  });
}

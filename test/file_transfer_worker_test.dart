import 'dart:async';

import 'package:easy_isolate/easy_isolate.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_worker.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test(
    'dispose during initialization prevents the transfer job from starting',
    () async {
      final driver = _GateWorker();
      final worker = FileTransferWorker(
        onNotify: (_) {},
        job: FileTransfer(
          from: const LocalFileRef('/source'),
          to: const LocalFileRef('/destination'),
        ),
        worker: driver,
      );

      final initializing = worker.init();
      await driver.started.future;
      worker.dispose();

      expect(
        driver.disposed,
        isFalse,
        reason: 'the dependency has not initialized its late fields yet',
      );
      driver.release.complete();
      await initializing;

      expect(driver.sent, isFalse);
      expect(driver.disposed, isTrue);
    },
  );
}

final class _GateWorker extends Worker {
  final started = Completer<void>();
  final release = Completer<void>();
  bool initialized = false;
  bool disposed = false;
  bool sent = false;

  @override
  bool get isInitialized => initialized;

  @override
  Future<void> init(
    MainMessageHandler mainHandler,
    IsolateMessageHandler isolateHandler, {
    Object? initialMessage,
    bool queueMode = false,
    MessageHandler? errorHandler,
    MessageHandler? exitHandler,
  }) async {
    started.complete();
    await release.future;
    initialized = true;
  }

  @override
  void dispose({bool immediate = false}) {
    disposed = true;
  }

  @override
  void sendMessage(Object? message) {
    sent = true;
  }
}

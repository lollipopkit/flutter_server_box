import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/proxy_command_socket.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../test/helpers/test_db.dart';

/// ProxyCommand on Android, end to end: `nc` in the guest under proot, a
/// server in this app. Every byte value is sent and echoed back, so a stream
/// that is not a clean pipe shows up as a mismatch.
///
/// Adds an Alpine only where there is no Linux system at all, and removes
/// nothing, so it is safe on a device someone uses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Paths.init(BuildData.name, bakName: Miscs.bakFileName);
    // The selected system and the mirror are settings; an in-memory store
    // answers them without touching the app's own database.
    await openTestDb();
    final settings = SettingStore('setting_test');
    await settings.init();
    getIt.registerSingleton<SettingStore>(settings);
    // Which releases there are, from the manifest the app ships with.
    await LinuxDistros.loadBundled();
    await AndroidRootfs.prepare();
  });

  testWidgets('a ProxyCommand carries every byte both ways', (_) async {
    if (!AndroidRootfs.isAvailable) {
      markTestSkipped('this build carries no proot');
      return;
    }
    if (!await AndroidRootfs.isInstalled) {
      await AndroidRootfs.install(distro: LinuxDistro.alpine);
    }

    // A server that speaks first, as sshd does, then echoes.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    const banner = 'SSH-2.0-sbm-test\r\n';
    server.listen((client) {
      client.add(utf8.encode(banner));
      client.listen(client.add, onDone: client.close);
    });

    final socket = await ProxyCommandSocket.connect(
      command: 'nc %h %p',
      host: '127.0.0.1',
      port: server.port,
      user: 'root',
      originalHost: 'test',
      jump: '',
      timeout: const Duration(seconds: 30),
    );

    final received = <int>[];
    final gotAll = Completer<void>();
    final payload = Uint8List.fromList([
      for (var round = 0; round < 64; round++)
        for (var b = 0; b < 256; b++) b,
    ]);
    final expected = [...utf8.encode(banner), ...payload];
    socket.stream.listen((chunk) {
      received.addAll(chunk);
      if (received.length >= expected.length && !gotAll.isCompleted) {
        gotAll.complete();
      }
    });

    socket.sink.add(payload);
    await gotAll.future.timeout(const Duration(seconds: 60));
    expect(received.sublist(0, expected.length), expected);
    expect(received.length, expected.length);

    await socket.close();
    await server.close();
  }, skip: !Platform.isAndroid, timeout: const Timeout(Duration(minutes: 5)));
}

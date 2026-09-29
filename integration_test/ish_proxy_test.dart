import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/ish_proxy_socket.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../test/helpers/test_db.dart';

/// ProxyCommand on iOS, end to end: `nc` in the guest, a server in this app.
///
/// What a unit test cannot show: that the session's terminal really is a pipe
/// once it is raw. The server echoes every byte back, and every byte value is
/// sent — `\r`, `\n`, `^C`, `^D`, `^Z`, `^S`, DEL among them — so an echo, a
/// translation or a signal anywhere on the way shows up as a mismatch.
///
/// Adds an Alpine only where there is no Linux system at all, and removes
/// nothing, so it is safe on a device someone uses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // The selected system and the mirror are settings; an in-memory store
    // answers them without touching the app's own database.
    await openTestDb();
    final settings = SettingStore('setting_test');
    await settings.init();
    getIt.registerSingleton<SettingStore>(settings);
    // Which releases there are, from the manifest the app ships with.
    await LinuxDistros.loadBundled();
    await IosRootfs.prepare();
  });

  testWidgets('a ProxyCommand carries every byte both ways', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    if (IosRootfs.selected == null) {
      await IosRootfs.install(distro: LinuxDistro.alpine);
    }

    // A server that speaks first, as sshd does, then echoes.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    const banner = 'SSH-2.0-sbm-test\r\n';
    server.listen((client) {
      client.add(utf8.encode(banner));
      client.listen(client.add, onDone: client.close);
    });

    final socket = await IshProxySocket.connect(
      command: 'nc 127.0.0.1 ${server.port}',
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
    expect(received.length, expected.length, reason: 'nothing extra: no echo');

    await socket.close();
    await socket.done.timeout(const Duration(seconds: 5));
    await server.close();
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a ProxyCommand that fails says why', (_) async {
    if (!IosRootfs.isAvailable || IosRootfs.selected == null) {
      markTestSkipped('no Linux system to run it in');
      return;
    }
    // The terminal is made raw before the command runs, so connecting
    // succeeds; the command's failure arrives on the stream, with its stderr.
    final socket = await IshProxySocket.connect(
      command: 'sbm-no-such-command',
      timeout: const Duration(seconds: 30),
    );
    final error = Completer<Object>();
    socket.stream.listen(
      (_) {},
      onError: (Object e) {
        if (!error.isCompleted) error.complete(e);
      },
    );
    expect(
      '${await error.future.timeout(const Duration(seconds: 30))}',
      contains('not found'),
    );
    await socket.done.timeout(const Duration(seconds: 5));
  }, skip: !Platform.isIOS);
}

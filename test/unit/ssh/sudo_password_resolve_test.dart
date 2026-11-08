import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which password the terminal's sudo key types: the one typed this session,
/// the one saved with the server, the SSH login's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spi = Spi(
    name: 'lkd',
    id: 's',
    ssh: SshCredential(ip: '10.0.0.4', port: 22, user: 'root', pwd: 'login'),
  );

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('sbm-sudo-');
    Paths.doc = dir.path;
    addTearDown(() => dir.delete(recursive: true));
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SqliteDb.openInMemory();
    await Stores.init();
    SudoPassword.forget('s');
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('typed, then saved, then the login', () async {
    expect(await SudoPassword.resolveForTerminal(spi), 'login');
    SudoPassword.save('s', 'saved');
    expect(await SudoPassword.resolveForTerminal(spi), 'saved');
    SudoPassword.remember('s', 'typed');
    expect(await SudoPassword.resolveForTerminal(spi), 'typed');
    SudoPassword.forget('s');
    SudoPassword.save('s', '');
    expect(SudoPassword.saved('s'), isNull);
  });

  test('one the keychain held is moved into the store', () async {
    Stores.server.put(spi);
    FlutterSecureStorage.setMockInitialValues({'sudo_pwd_s': 'old'});

    await SudoPassword.adoptKeychain();

    expect(SudoPassword.saved('s'), 'old');
    expect(await SecureStore.storage.readAll(), isEmpty);
    // Once.
    FlutterSecureStorage.setMockInitialValues({'sudo_pwd_s': 'again'});
    await SudoPassword.adoptKeychain();
    expect(SudoPassword.saved('s'), 'old');
  });
}

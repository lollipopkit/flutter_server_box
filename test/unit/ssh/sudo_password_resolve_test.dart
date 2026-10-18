import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// Which password the terminal's sudo key types: the one typed this session,
/// the one saved with the server, the SSH login's — and none at all when the
/// saved one cannot be read. Its own file: the last test spends the secure
/// store's read budget, which is process-wide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spi = Spi(
    name: 'lkd',
    id: 's',
    ssh: SshCredential(ip: '10.0.0.4', port: 22, user: 'root', pwd: 'login'),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SudoPassword.forget('s');
  });

  test('typed, then saved, then the login', () async {
    expect(await SudoPassword.resolveForTerminal(spi), 'login');
    await SudoPassword.writeOverride('s', 'saved');
    expect(await SudoPassword.resolveForTerminal(spi), 'saved');
    SudoPassword.remember('s', 'typed');
    expect(await SudoPassword.resolveForTerminal(spi), 'typed');
  });

  test('a saved one that cannot be read is not replaced by the login', () async {
    await SudoPassword.writeOverride('s', 'saved');
    // Spend the read budget, as a burst of reads on a slow keychain does.
    try {
      while (true) {
        await SudoPassword.readOverride('s');
      }
    } on RateLimitExceededException {
      // Spent.
    }
    expect(SudoPassword.resolveForTerminal(spi), throwsA(isA<RateLimitExceededException>()));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/private_key/edit.dart';

void main() {
  test('private key size is measured in UTF-8 bytes', () {
    expect(privateKeyUtf8Length('a'), 1);
    expect(privateKeyUtf8Length('\u4e2d'), 3);
  });

  test('normalization can increase the stored byte length', () {
    final body = List.filled(65, 'A').join();
    final raw = '-----BEGIN PRIVATE KEY-----\n$body\n-----END PRIVATE KEY-----';
    final normalized = normalizePrivateKeyText(raw);

    expect(normalized, endsWith('\n'));
    expect(
      privateKeyUtf8Length(normalized),
      greaterThan(privateKeyUtf8Length(raw)),
    );
  });
}

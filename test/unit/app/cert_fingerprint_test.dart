import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/cert_fingerprint.dart';

/// One formatter for a stored pin, shared by the server editor and the
/// Virtualization tab's certificate dialog, which each had their own.
void main() {
  test('bare hex becomes colon-separated upper case', () {
    expect(prettyCertFingerprint('ab12cd'), 'AB:12:CD');
  });

  test('already colon-separated is only upper-cased', () {
    expect(prettyCertFingerprint('ab:12:cd'), 'AB:12:CD');
  });

  test('matches what CertInfo prints for one just presented', () {
    const hex = '9c1185a5c5e9fc54612808977ee8f548';
    expect(
      prettyCertFingerprint(hex),
      '9C:11:85:A5:C5:E9:FC:54:61:28:08:97:7E:E8:F5:48',
    );
  });
}

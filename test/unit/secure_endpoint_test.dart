import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/secure_endpoint.dart';

void main() {
  test('remote Monitor HTTP needs an explicit opt-in', () {
    final remote = Uri.parse('http://100.64.0.10:3770');
    expect(isSecureRemoteEndpoint(remote), isFalse);
    expect(
      isSecureRemoteEndpoint(remote, allowInsecure: true),
      isTrue,
    );
  });

  test('HTTPS and loopback HTTP remain available by default', () {
    expect(isSecureRemoteEndpoint(Uri.parse('https://agent:3770')), isTrue);
    expect(isSecureRemoteEndpoint(Uri.parse('http://127.0.0.1:3770')), isTrue);
  });
}

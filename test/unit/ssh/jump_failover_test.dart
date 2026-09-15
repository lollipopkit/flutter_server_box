import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';

void main() {
  group('Jump failover errors', () {
    test('network errors can fail over', () {
      expect(isJumpFailoverError('Connection refused'), isTrue);
      expect(isJumpFailoverError('SocketException: timed out'), isTrue);
      expect(isJumpFailoverError('forwardLocal failed'), isTrue);
    });

    test('auth and host key errors do not fail over', () {
      expect(isJumpFailoverError('Authentication failed'), isFalse);
      expect(isJumpFailoverError('User rejected new SSH host key'), isFalse);
      expect(isJumpFailoverError('Permission denied'), isFalse);
    });
  });
}

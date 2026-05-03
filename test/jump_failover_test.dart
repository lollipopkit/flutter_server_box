import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';

void main() {
  group('Jump failover errors', () {
    test('network errors can fail over', () {
      expect(isJumpFailoverErrorForTest('Connection refused'), isTrue);
      expect(isJumpFailoverErrorForTest('SocketException: timed out'), isTrue);
      expect(isJumpFailoverErrorForTest('forwardLocal failed'), isTrue);
    });

    test('auth and host key errors do not fail over', () {
      expect(isJumpFailoverErrorForTest('Authentication failed'), isFalse);
      expect(
        isJumpFailoverErrorForTest('User rejected new SSH host key'),
        isFalse,
      );
      expect(isJumpFailoverErrorForTest('Permission denied'), isFalse);
    });
  });
}

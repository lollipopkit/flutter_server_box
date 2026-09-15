import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';

void main() {
  group('Err equality', () {
    test('the same failure twice is the same error', () {
      // A page holding this in state rebuilds whenever it changes, so a retry
      // that fails identically must not look like news.
      const a = ContainerErr(
        type: ContainerErrType.notInstalled,
        message: 'sh: docker: not found',
      );
      const b = ContainerErr(
        type: ContainerErrType.notInstalled,
        message: 'sh: docker: not found',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different message is a different error', () {
      expect(
        const ContainerErr(type: ContainerErrType.unknown, message: 'a'),
        isNot(const ContainerErr(type: ContainerErrType.unknown, message: 'b')),
      );
    });

    test('two families do not collide on the same enum index', () {
      expect(
        const ContainerErr(type: ContainerErrType.unknown),
        isNot(const SSHErr(type: SSHErrType.unknown)),
      );
    });
  });
}

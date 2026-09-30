import 'package:server_box/data/ssh/ssh_terminal_environment.dart';
import 'package:test/test.dart';

void main() {
  group('buildSshTerminalEnvironment', () {
    test('does not inject locale when no env is configured', () {
      expect(buildSshTerminalEnvironment(null), isNull);
      expect(buildSshTerminalEnvironment({}), isNull);
    });

    test('preserves explicit env values', () {
      final env = buildSshTerminalEnvironment({
        'LANG': 'zh_CN.UTF-8',
        'LC_CTYPE': 'C.UTF-8',
        'LC_ALL': 'C',
        'CUSTOM': 'value',
      });

      expect(env, {
        'LANG': 'zh_CN.UTF-8',
        'LC_CTYPE': 'C.UTF-8',
        'LC_ALL': 'C',
        'CUSTOM': 'value',
      });
    });
  });
}

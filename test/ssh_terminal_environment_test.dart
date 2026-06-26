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

  group('resolveTmuxLang', () {
    test('uses LC_ALL before LC_CTYPE and LANG', () {
      expect(
        resolveTmuxLang({
          'LANG': 'zh_CN.UTF-8',
          'LC_CTYPE': 'C.UTF-8',
          'LC_ALL': 'C',
        }),
        'C',
      );
    });

    test('uses LC_CTYPE before LANG', () {
      expect(
        resolveTmuxLang({'LANG': 'zh_CN.UTF-8', 'LC_CTYPE': 'C.UTF-8'}),
        'C.UTF-8',
      );
    });

    test('falls back to LANG and otherwise stays unset', () {
      expect(resolveTmuxLang({'LANG': 'zh_CN.UTF-8'}), 'zh_CN.UTF-8');
      expect(resolveTmuxLang(null), isNull);
      expect(resolveTmuxLang({'LANG': '  '}), isNull);
    });
  });
}

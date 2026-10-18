import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/editor_format.dart';

void main() {
  test('JSON is pretty-printed with two spaces', () {
    expect(
      formatEditorText('{"a":1,"b":[2,3]}', lang: ProgLang.json),
      '{\n  "a": 1,\n  "b": [\n    2,\n    3\n  ]\n}',
    );
  });

  test('JSON keeps a trailing newline when the original had one', () {
    expect(
      formatEditorText('{"a":1}\n', lang: ProgLang.json),
      '{\n  "a": 1\n}\n',
    );
  });

  test('invalid JSON throws', () {
    expect(
      () => formatEditorText('{', lang: ProgLang.json),
      throwsFormatException,
    );
  });

  test('JSON Lines stay one value per line', () {
    expect(
      formatEditorText(
        '{ "a" : 1 }\n{ "b" : 2 }\n',
        path: 'events.jsonl',
      ),
      '{"a":1}\n{"b":2}\n',
    );
  });

  test('XML is indented by tag depth', () {
    expect(
      formatEditorText('<root><a>1</a></root>', lang: ProgLang.xml),
      '<root>\n  <a>\n    1\n  </a>\n</root>',
    );
  });

  test('INI and systemd units get Key=value', () {
    expect(
      formatEditorText(
        '[Service]\nExecStart = /bin/true\n',
        lang: ProgLang.ini,
      ),
      '[Service]\nExecStart=/bin/true\n',
    );
  });

  test('brace languages are re-indented', () {
    expect(
      formatEditorText('void f() {\nreturn;\n}', lang: ProgLang.c),
      'void f() {\n  return;\n}',
    );
    expect(
      formatEditorText(
        'if (x) {\ny();\n} else {\nz();\n}',
        lang: ProgLang.javascript,
      ),
      'if (x) {\n  y();\n} else {\n  z();\n}',
    );
  });

  test('braces inside strings do not change indent', () {
    expect(
      formatEditorText('x = "{";\ny();', lang: ProgLang.javascript),
      'x = "{";\ny();',
    );
  });

  test('Python and YAML only lose trailing whitespace', () {
    expect(
      formatEditorText('def f():   \n    return 1', lang: ProgLang.python),
      'def f():\n    return 1',
    );
    expect(
      formatEditorText('a:\n  b: 1  ', lang: ProgLang.yaml),
      'a:\n  b: 1',
    );
  });

  test('Apache directives collapse spaces and indent sections', () {
    expect(
      formatEditorText(
        '<Directory /var/www>\nRequire   all   granted\n</Directory>',
        lang: ProgLang.apache,
      ),
      '<Directory /var/www>\n  Require all granted\n</Directory>',
    );
  });

  test('a file with no language still formats', () {
    expect(formatEditorText('[1,2]'), '[\n  1,\n  2\n]');
    expect(formatEditorText('hello   '), 'hello');
    expect(
      formatEditorText('fn() {\nreturn;\n}'),
      'fn() {\n  return;\n}',
    );
  });

  test('every language formats a plain line', () {
    for (final lang in ProgLang.values) {
      if (lang == ProgLang.json) continue;
      expect(
        formatEditorText('hello', lang: lang),
        'hello',
        reason: lang.name,
      );
    }
  });
}

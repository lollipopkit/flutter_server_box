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

  test('a language with no formatter returns null', () {
    expect(formatEditorText('[Service]\nExecStart=/bin/true', lang: ProgLang.ini), isNull);
    expect(formatEditorText('echo hi', lang: ProgLang.shell), isNull);
  });

  test('content that looks like JSON is formatted without a lang', () {
    expect(
      formatEditorText('[1,2]'),
      '[\n  1,\n  2\n]',
    );
  });
}

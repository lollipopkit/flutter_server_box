import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/editor_lang.dart';

void main() {
  test('a .json file is JSON, including .JSON', () {
    expect(editorLangFor('package.json'), ProgLang.json);
    expect(editorLangFor('/etc/foo.JSON'), ProgLang.json);
    expect(editorLangFor(r'C:\tmp\Bar.Json'), ProgLang.json);
  });

  test('JSON-shaped names that are not .json still highlight as JSON', () {
    expect(editorLangFor('tsconfig.jsonc'), ProgLang.json);
    expect(editorLangFor('data.json5'), ProgLang.json);
    expect(editorLangFor('events.jsonl'), ProgLang.json);
    expect(editorLangFor('events.ndjson'), ProgLang.json);
    expect(editorLangFor('map.geojson'), ProgLang.json);
    expect(editorLangFor('app.webmanifest'), ProgLang.json);
    expect(editorLangFor('trace.har'), ProgLang.json);
  });

  test('a known suffix is still that language when the case differs', () {
    expect(editorLangFor('main.RS'), ProgLang.rust);
    expect(editorLangFor('script.PY'), ProgLang.python);
    expect(editorLangFor('notes.YML'), ProgLang.yaml);
  });

  test('a name with no known suffix is left unknown', () {
    expect(editorLangFor('README'), isNull);
    expect(editorLangFor('file.unknownext'), isNull);
    expect(editorLangFor(null), isNull);
    expect(editorLangFor(''), isNull);
  });
}

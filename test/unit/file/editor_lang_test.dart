import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/editor_lang.dart';

void main() {
  test('markdown names are markdown, including extra suffixes', () {
    expect(editorLangFor('README.md'), ProgLang.markdown);
    expect(editorLangFor('notes.MD'), ProgLang.markdown);
    expect(editorLangFor('CHANGELOG.markdown'), ProgLang.markdown);
    expect(editorLangFor('doc.mdown'), ProgLang.markdown);
    expect(editorLangFor('doc.mkd'), ProgLang.markdown);
    expect(editorLangFor('doc.mdwn'), ProgLang.markdown);
  });

  test('a known suffix is still that language when the case differs', () {
    expect(editorLangFor('main.RS'), ProgLang.rust);
    expect(editorLangFor('script.PY'), ProgLang.python);
    expect(editorLangFor('notes.YML'), ProgLang.yaml);
  });

  test('the editor offers a Markdown view for markdown files only', () {
    expect(editorIsMarkdown(path: 'README.md'), isTrue);
    expect(editorIsMarkdown(lang: ProgLang.markdown), isTrue);
    expect(editorIsMarkdown(path: 'package.json'), isFalse);
    expect(editorIsMarkdown(lang: ProgLang.json, path: 'README.md'), isFalse);
    expect(editorIsMarkdown(), isFalse);
  });

  test('a name with no known suffix is left unknown', () {
    expect(editorLangFor('README'), isNull);
    expect(editorLangFor('file.unknownext'), isNull);
    expect(editorLangFor(null), isNull);
    expect(editorLangFor(''), isNull);
  });
}

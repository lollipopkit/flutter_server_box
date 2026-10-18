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

  test('a systemd unit is INI, including .service', () {
    expect(editorLangFor('sshd.service'), ProgLang.ini);
    expect(editorLangFor('/etc/systemd/system/Foo.SERVICE'), ProgLang.ini);
    expect(editorLangFor('docker.socket'), ProgLang.ini);
    expect(editorLangFor('apt-daily.timer'), ProgLang.ini);
    expect(editorLangFor('multi-user.target'), ProgLang.ini);
  });

  test('INI-shaped config that is not .ini still highlights as INI', () {
    expect(editorLangFor('my.cnf'), ProgLang.ini);
    expect(editorLangFor('app.cfg'), ProgLang.ini);
    expect(editorLangFor('Cargo.toml'), ProgLang.ini);
    expect(editorLangFor('foo.desktop'), ProgLang.ini);
    expect(editorLangFor('10-eth.network'), ProgLang.ini);
    expect(editorLangFor('quadlet.container'), ProgLang.ini);
  });

  test('XML-shaped markup highlights as XML', () {
    expect(editorLangFor('index.html'), ProgLang.xml);
    expect(editorLangFor('Info.plist'), ProgLang.xml);
    expect(editorLangFor('logo.SVG'), ProgLang.xml);
  });

  test('shell rc files and extra suffixes are shell', () {
    expect(editorLangFor('/home/u/.bashrc'), ProgLang.shell);
    expect(editorLangFor('.zshrc'), ProgLang.shell);
    expect(editorLangFor('.profile'), ProgLang.shell);
    expect(editorLangFor('script.ksh'), ProgLang.shell);
    expect(editorLangFor('script.fish'), ProgLang.shell);
  });

  test('dotfiles and config names without a suffix', () {
    expect(editorLangFor('.env'), ProgLang.properties);
    expect(editorLangFor('.gitconfig'), ProgLang.ini);
    expect(editorLangFor('.htaccess'), ProgLang.apache);
    expect(editorLangFor('sshd_config'), ProgLang.apache);
    expect(editorLangFor('Dockerfile'), ProgLang.dockerfile);
    expect(editorLangFor('makefile'), ProgLang.makefile);
  });

  test('a name with no known suffix is left unknown', () {
    expect(editorLangFor('README'), isNull);
    expect(editorLangFor('file.unknownext'), isNull);
    expect(editorLangFor(null), isNull);
    expect(editorLangFor(''), isNull);
  });

  test('markdown names are markdown, including extra suffixes', () {
    expect(editorLangFor('README.md'), ProgLang.markdown);
    expect(editorLangFor('notes.MD'), ProgLang.markdown);
    expect(editorLangFor('CHANGELOG.markdown'), ProgLang.markdown);
    expect(editorLangFor('doc.mdown'), ProgLang.markdown);
    expect(editorLangFor('doc.mkd'), ProgLang.markdown);
    expect(editorLangFor('doc.mdwn'), ProgLang.markdown);
  });

  test('the editor offers a Markdown view for markdown files only', () {
    expect(editorIsMarkdown(path: 'README.md'), isTrue);
    expect(editorIsMarkdown(lang: ProgLang.markdown), isTrue);
    expect(editorIsMarkdown(path: 'package.json'), isFalse);
    expect(editorIsMarkdown(lang: ProgLang.json, path: 'README.md'), isFalse);
    expect(editorIsMarkdown(), isFalse);
  });
}

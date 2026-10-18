import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/theme_style.dart';

void main() {
  test('maps a name to file.<ext>', () {
    expect(ThemeFileIcon.forName('app.py'), 'file.py');
    expect(ThemeFileIcon.forName('Lib.rs'), 'file.rs');
    expect(ThemeFileIcon.forName('.gitignore'), 'file.gitignore');
    expect(ThemeFileIcon.forName('.env'), 'file.env');
    expect(ThemeFileIcon.forName('archive.tar.gz'), 'file.gz');
    expect(ThemeFileIcon.forName('Dockerfile'), 'file.dockerfile');
    expect(ThemeFileIcon.forName('Makefile'), 'file.makefile');
    expect(ThemeFileIcon.forName('Gemfile'), 'file.rb');
    expect(ThemeFileIcon.forName('style.scss'), 'file.scss');
    expect(ThemeFileIcon.forName('README'), isNull);
    expect(ThemeFileIcon.forName('archive.7z'), isNull);
    expect(ThemeFileIcon.keyPattern.hasMatch('file.py'), isTrue);
    expect(ThemeFileIcon.keyPattern.hasMatch('file.7z'), isFalse);
    expect(
      ThemeFileIcon.schemaKeys,
      containsAll(['file.dir', 'file.py', 'file.scss', 'file.makefile']),
    );
  });

  test('aliases related extensions onto a glyph the package may share', () {
    expect(ThemeFileIcon.aliasOf('file.scss'), 'file.css');
    expect(ThemeFileIcon.aliasOf('file.bash'), 'file.sh');
    expect(ThemeFileIcon.aliasOf('file.py'), isNull);
  });

  test('built-in glyphs differ by extension', () {
    expect(ThemeFileIcon.builtIn('file.py').$1,
        isNot(ThemeFileIcon.builtIn('file.rs').$1));
    expect(ThemeFileIcon.builtIn('file.scss').$1,
        ThemeFileIcon.builtIn('file.css').$1);
    expect(ThemeFileIcon.builtIn('file.jpg').$1,
        isNot(ThemeFileIcon.builtIn('file.pdf').$1));
  });

  test('dirs and links ignore the name', () {
    expect(
      ThemeFileIcon.keyOf(name: 'src', isDir: true, isLink: false),
      ThemeFileIcon.dir,
    );
    expect(
      ThemeFileIcon.keyOf(name: 'app.py', isDir: false, isLink: true),
      ThemeFileIcon.link,
    );
    expect(
      ThemeFileIcon.keyOf(name: 'app.py', isDir: false, isLink: false),
      'file.py',
    );
    expect(
      ThemeFileIcon.keyOf(name: 'README', isDir: false, isLink: false),
      ThemeFileIcon.fallback,
    );
  });
}

/// `store/`, the official theme repository, read the way the store reads it.
///
/// What the app downloads is a tarball of this folder that the website build
/// writes (`scripts/store-tarball.sh`), and nothing reads the folder itself
/// before a device does. A theme file the reader drops costs that theme without
/// a word on screen, so this is where it is found instead.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toml/toml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = Directory('store');
  final files = <String, Uint8List>{
    for (final f in store.listSync(recursive: true).whereType<File>())
      f.path.substring(store.path.length + 1): f.readAsBytesSync(),
  };
  final listed = files.keys.where((p) => ThemeRepoLayout.idOf(p) != null);

  /// The listings with a version to offer. One with none is a theme not yet
  /// published — `scripts/publish-themes.py` appends its first — and the store
  /// rightly offers nothing for it; its folder is still checked below.
  final published = [
    for (final path in listed)
      if (TomlDocument.parse(utf8.decode(files[path]!))
              .toMap()['version']
          case final List<Object?> versions when versions.isNotEmpty)
        path,
  ];

  late Directory root;
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('theme-store-tree-test-');
  });
  tearDownAll(() async => root.delete(recursive: true));

  test('is a repository, and every theme file in it is read', () {
    final index = ThemeRepoIndex.fromFiles(files);
    expect(index.name, 'ServerBox official');
    expect(
      [for (final t in index.themes) ThemeRepoLayout.pathOf(t.id)],
      unorderedEquals(published),
      reason: 'a file the reader dropped is missing here',
    );
    for (final theme in index.themes) {
      expect(theme.releases, isNotEmpty, reason: theme.id);
      for (final release in theme.releases) {
        expect(release.verifiable, isTrue, reason: '${theme.id} ${release.version}');
      }
    }
  });

  for (final path in listed) {
    final id = ThemeRepoLayout.idOf(path)!;
    test('$id: its folder is the theme it lists', () async {
      final theme = await ThemePackages.installFolder(
        '${store.path}/themes/$id',
        rootDirectory: '${root.path}/$id',
      );
      expect(theme.id, id);
    });
  }
}

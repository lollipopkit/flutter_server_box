import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

class RecordingBundle extends CachingAssetBundle {
  final paths = <String>[];
  bool failNext = false;

  @override
  Future<ByteData> load(String key) async {
    paths.add(key);
    if (failNext && key.startsWith('assets/themes/')) {
      failNext = false;
      throw const FormatException('Simulated asset failure');
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BuiltinThemeLoader loader;
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('builtin-theme-test-');
    loader = BuiltinThemeLoader(rootDirectory: '${root.path}/builtin');
  });
  tearDownAll(() async => root.delete(recursive: true));

  test('bundled themes are separate from user-installed themes', () {
    expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
  });

  test('Default requires no assets or cache directory', () async {
    final bundle = RecordingBundle();
    final cache = Directory('${root.path}/default-no-io');
    final lazy = BuiltinThemeLoader(bundle: bundle, rootDirectory: cache.path);
    expect(
      await lazy.load(BuiltinTheme.defaultTheme),
      same(ThemePackages.defaultTheme),
    );
    expect(bundle.paths, isEmpty);
    expect(cache.existsSync(), isFalse);
  });

  test(
    'only the selected folder loads and concurrent requests share it',
    () async {
      final bundle = RecordingBundle();
      final lazy = BuiltinThemeLoader(
        bundle: bundle,
        rootDirectory: '${root.path}/lazy',
      );
      expect(lazy.loaded(BuiltinTheme.oneDarkPro), isNull);
      final themes = await Future.wait([
        lazy.load(BuiltinTheme.oneDarkPro),
        lazy.load(BuiltinTheme.oneDarkPro),
      ]);
      expect(themes.first, same(themes.last));
      expect(bundle.paths.where((path) => path.startsWith('assets/themes/')), [
        'assets/themes/one-dark-pro/manifest.toml',
      ]);
      final count = bundle.paths.length;
      expect(await lazy.load(BuiltinTheme.oneDarkPro), same(themes.first));
      expect(bundle.paths.length, count);
      expect(lazy.loaded(BuiltinTheme.dracula), isNull);
    },
  );

  test(
    'AMOLED uses black dark surfaces and supports system appearance',
    () async {
      final theme = await loader.load(BuiltinTheme.amoled);
      expect(theme.lockedMode, isNull);
      for (final mode in ThemeMode.values) {
        expect(theme.resolveMode(mode.index), mode);
      }
      expect(theme.paletteLight, isEmpty);
      expect(theme.paletteDark['surface'], 0xff000000);
      expect(ThemePackages.defaultTheme.lockedMode, isNull);
    },
  );

  test('failed lazy loads can be retried', () async {
    final bundle = RecordingBundle()..failNext = true;
    final lazy = BuiltinThemeLoader(
      bundle: bundle,
      rootDirectory: '${root.path}/retry',
    );
    await expectLater(lazy.load(BuiltinTheme.dracula), throwsFormatException);
    expect(lazy.loaded(BuiltinTheme.dracula), isNull);
    expect((await lazy.load(BuiltinTheme.dracula)).id, 'dracula');
  });

  for (final folder in Directory(
    'assets/themes',
  ).listSync().whereType<Directory>()) {
    final id = folder.uri.pathSegments.where((part) => part.isNotEmpty).last;
    test(
      '$id is identical as a bundled folder, imported folder and fsbt',
      () async {
        final bundled = await loader.load(BuiltinTheme.fromId(id)!);
        final imported = await ThemePackages.installFolder(
          folder.path,
          rootDirectory: '${root.path}/imported',
        );
        final archive = Archive();
        for (final file in folder.listSync(recursive: true).whereType<File>()) {
          archive.add(
            ArchiveFile.bytes(
              file.path.substring(folder.path.length + 1),
              file.readAsBytesSync(),
            ),
          );
        }
        final packed = await ThemePackages.install(
          ZipEncoder().encodeBytes(archive),
          rootDirectory: '${root.path}/packed',
        );
        for (final theme in [imported, packed]) {
          expect(theme.id, bundled.id);
          expect(theme.name, bundled.name);
          expect(
            (theme.schemaMin, theme.schemaMax),
            (bundled.schemaMin, bundled.schemaMax),
          );
          expect(theme.seed, bundled.seed);
          expect(theme.mode, bundled.mode);
          expect(theme.modes, bundled.modes);
          expect(theme.paletteLight, bundled.paletteLight);
          expect(theme.paletteDark, bundled.paletteDark);
          expect(theme.iconStyle, bundled.iconStyle);
          expect(theme.backgroundStyle, bundled.backgroundStyle);
          expect(
            (theme.cardRadius, theme.tileRadius, theme.buttonRadius),
            (bundled.cardRadius, bundled.tileRadius, bundled.buttonRadius),
          );
        }
        expect(imported.installationId, bundled.installationId);
      },
    );

    test('$id keeps text readable on surfaces and controls', () async {
      final theme = await loader.load(BuiltinTheme.fromId(id)!);
      final scheme = ThemePackages.applyPalette(
        ColorScheme.fromSeed(
          seedColor: Color(theme.seed),
          brightness: Brightness.dark,
        ),
        theme.paletteDark,
      );
      for (final (foreground, background) in [
        (scheme.onSurface, scheme.surface),
        (scheme.onSurface, scheme.surfaceContainerLow),
        (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onError, scheme.error),
      ]) {
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
      }
    });
  }
}

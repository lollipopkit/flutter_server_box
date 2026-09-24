import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/app_font.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:toml/toml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> package({String background = 'gradient'}) => {
    'format': 1,
    'schema': {'min': 1, 'max': 1},
    'id': 'example.amethyst',
    'name': 'Amethyst',
    'modes': ['light', 'dark'],
    'colors': {'mode': 0, 'seed': 4287106639, 'systemColor': false},
    'icons': {'style': 'classic', 'images': <String, String>{}},
    'background': {'type': background, 'opacity': 0.18, 'blur': 8},
    'shapes': {'card': 13, 'tile': 9, 'button': 30},
  };

  List<int> bundle(
    Map<String, Object?> manifest, [
    Map<String, List<int>> files = const {},
  ]) {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'manifest.toml',
          TomlDocument.fromMap(manifest).toString(),
        ),
      );
    for (final entry in files.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  test('installs a valid theme and can read it after installation', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-test-');
    try {
      final bytes = bundle(package());
      final installed = await ThemePackages.install(
        bytes,
        rootDirectory: root.path,
      );
      expect(installed.name, 'Amethyst');
      expect(installed.blur, 8);
      expect(installed.paletteLight, isEmpty);
      expect(installed.backgroundPath, isNull);
      expect(
        ThemePackages.listInstalled(rootDirectory: root.path),
        hasLength(1),
      );
      expect(ThemePackages.installedPresetNames(rootDirectory: root.path), {
        'package:${installed.installationId}': 'Amethyst',
      });
      expect(
        (await ThemePackages.install(
          bytes,
          rootDirectory: root.path,
        )).installationId,
        installed.installationId,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'TOML themes need only identity, modes and schema; overrides preserve defaults',
    () async {
      final root = await Directory.systemTemp.createTemp('fsbt-defaults-');
      try {
        final minimal = <String, Object?>{
          'id': 'example.minimal',
          'name': 'Minimal',
          'modes': ['light', 'dark'],
          'schema': {'min': 1, 'max': 1},
        };
        final theme = await ThemePackages.install(
          bundle(minimal),
          rootDirectory: root.path,
        );
        expect(theme.mode, 0);
        expect(theme.seed, 0xff880e4f);
        expect(theme.systemColor, false);
        expect(theme.iconStyle, 'classic');
        expect(theme.iconKeys, isEmpty);
        expect(theme.backgroundStyle, 'none');
        expect((theme.opacity, theme.blur), (0.18, 0));
        expect(
          (theme.cardRadius, theme.tileRadius, theme.buttonRadius),
          (12, 8, 10),
        );
        expect(theme.paletteLight, isEmpty);
        expect(theme.paletteDark, isEmpty);

        minimal['shapes'] = {'card': 0};
        minimal['background'] = {'opacity': 0};
        final overridden = await ThemePackages.install(
          bundle(minimal),
          rootDirectory: root.path,
        );
        expect(
          (
            overridden.cardRadius,
            overridden.tileRadius,
            overridden.buttonRadius,
          ),
          (0, 8, 10),
        );
        expect(overridden.opacity, 0);
        for (final invalid in [
          'bad',
          {'card': '12'},
          {'tile': -1},
          {'button': 41},
        ]) {
          minimal['shapes'] = invalid;
          await expectLater(
            ThemePackages.install(bundle(minimal), rootDirectory: root.path),
            throwsFormatException,
          );
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('rejects malformed TOML and duplicate keys', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-toml-');
    try {
      for (final source in [
        'id = [',
        'id = "one"\nid = "two"',
        '{"id":"json"}',
      ]) {
        final archive = Archive()
          ..add(ArchiveFile.string('manifest.toml', source));
        await expectLater(
          ThemePackages.install(
            ZipEncoder().encodeBytes(archive),
            rootDirectory: root.path,
          ),
          throwsFormatException,
        );
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'declared modes survive installation and constrain every preference',
    () async {
      final root = await Directory.systemTemp.createTemp('fsbt-modes-');
      addTearDown(() => root.delete(recursive: true));
      for (final modes in [
        <String>['light'],
        <String>['dark'],
        <String>['light', 'dark'],
      ]) {
        final manifest = package()..['modes'] = modes;
        final theme = await ThemePackages.install(
          bundle(manifest),
          rootDirectory: root.path,
        );
        final restored = ThemePackages.installed(
          theme.installationId,
          rootDirectory: root.path,
        )!;
        expect(restored.modes.map((mode) => mode.name), unorderedEquals(modes));
        for (final preference in ThemeMode.values) {
          expect(
            restored.resolveMode(preference.index),
            modes.length == 1
                ? (modes.single == 'light' ? ThemeMode.light : ThemeMode.dark)
                : preference,
          );
        }
      }
    },
  );

  test(
    'rejects missing, empty, duplicate and unknown supported modes',
    () async {
      final root = await Directory.systemTemp.createTemp('fsbt-invalid-modes-');
      addTearDown(() => root.delete(recursive: true));
      for (final modes in [
        null,
        [],
        ['light', 'light'],
        ['system'],
        ['amoled'],
        ['dark', 2],
        'dark',
      ]) {
        final manifest = package();
        if (modes == null) {
          manifest.remove('modes');
        } else {
          manifest['modes'] = modes;
        }
        await expectLater(
          ThemePackages.install(bundle(manifest), rootDirectory: root.path),
          throwsFormatException,
        );
      }
      for (final mode in [3, 4]) {
        final manifest = package()..['colors'] = {'mode': mode};
        await expectLater(
          ThemePackages.install(bundle(manifest), rootDirectory: root.path),
          throwsFormatException,
        );
      }
    },
  );

  test('ships an editable example theme folder', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-example-test-');
    try {
      final installed = await ThemePackages.installFolder(
        'docs/examples/aurora',
        rootDirectory: root.path,
      );
      expect(installed.name, 'Aurora');
      expect(installed.paletteLight['primary'], isNotNull);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('requires a compatible declared schema range', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-schema-test-');
    try {
      final compatible = package()..['schema'] = {'min': 1, 'max': 2};
      final installed = await ThemePackages.install(
        bundle(compatible),
        rootDirectory: root.path,
      );
      expect((installed.schemaMin, installed.schemaMax), (1, 2));

      for (final schema in [
        null,
        {'min': 2, 'max': 3},
        {'min': 2, 'max': 1},
        {'min': 0, 'max': 1},
        {'min': 1},
      ]) {
        final invalid = package();
        if (schema == null) {
          invalid.remove('schema');
        } else {
          invalid['schema'] = schema;
        }
        await expectLater(
          ThemePackages.install(bundle(invalid), rootDirectory: root.path),
          throwsFormatException,
        );
      }

      final stored = File('${installed.directory}/manifest.toml');
      final profile = TomlDocument.parse(await stored.readAsString()).toMap();
      profile['schema'] = {'min': 2, 'max': 3};
      await stored.writeAsString(TomlDocument.fromMap(profile).toString());
      expect(
        ThemePackages.installed(
          installed.installationId,
          rootDirectory: root.path,
        ),
        isNull,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'imports a folder with image assets and rejects symlinked assets',
    () async {
      final source = await Directory.systemTemp.createTemp(
        'fsbt-folder-source-',
      );
      final root = await Directory.systemTemp.createTemp(
        'fsbt-folder-install-',
      );
      try {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 4, 4),
          Paint()..color = Colors.pink,
        );
        final image = await recorder.endRecording().toImage(4, 4);
        final png = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        final data = package(background: 'image');
        (data['background'] as Map<String, Object?>)['image'] =
            'background.png';
        ((data['icons'] as Map<String, Object?>)['images']
                as Map<String, String>)['tab.server'] =
            'icons/tab_server.png';
        await File(
          '${source.path}/manifest.toml',
        ).writeAsString(TomlDocument.fromMap(data).toString());
        await File('${source.path}/background.png').writeAsBytes(png);
        await Directory('${source.path}/icons').create();
        await File('${source.path}/icons/tab_server.png').writeAsBytes(png);
        final installed = await ThemePackages.installFolder(
          source.path,
          rootDirectory: root.path,
        );
        expect(await File(installed.backgroundPath!).length(), png.length);
        await File('${source.path}/background.png').delete();
        await Link('${source.path}/background.png').create('/etc/hosts');
        await expectLater(
          ThemePackages.installFolder(source.path, rootDirectory: root.path),
          throwsFormatException,
        );
      } finally {
        await source.delete(recursive: true);
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'installs checked image assets without path names from the package',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 4, 4),
        Paint()..color = Colors.pink,
      );
      final image = await recorder.endRecording().toImage(4, 4);
      final png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      final data = package(background: 'image');
      (data['background'] as Map<String, Object?>)['image'] = 'background.png';
      ((data['icons'] as Map<String, Object?>)['images']
              as Map<String, String>)['tab.server'] =
          'icons/tab_server.png';
      final root = await Directory.systemTemp.createTemp('fsbt-image-test-');
      try {
        final installed = await ThemePackages.install(
          bundle(data, {'background.png': png, 'icons/tab_server.png': png}),
          rootDirectory: root.path,
        );
        expect(await File(installed.backgroundPath!).length(), png.length);
        expect(
          await File(installed.iconPath('tab.server')!).length(),
          png.length,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('rejects launcher icons and unknown icon keys', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-reject-test-');
    try {
      final withLauncher = package()..['appIcon'] = 'data';
      await expectLater(
        ThemePackages.install(bundle(withLauncher), rootDirectory: root.path),
        throwsFormatException,
      );
      final withUnknownIcon = package();
      ((withUnknownIcon['icons'] as Map<String, Object?>)['images']
              as Map<String, String>)['../outside'] =
          'data';
      await expectLater(
        ThemePackages.install(
          bundle(withUnknownIcon),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('rejects plain JSON and unsafe ZIP entries', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-zip-reject-');
    try {
      await expectLater(
        ThemePackages.install(
          utf8.encode(jsonEncode(package())),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
      for (final path in ['../outside.png', 'icons/../outside.png']) {
        await expectLater(
          ThemePackages.install(
            bundle(package(), {
              path: [1],
            }),
            rootDirectory: root.path,
          ),
          throwsFormatException,
        );
      }
      final withSymlink = Archive()
        ..add(
          ArchiveFile.string(
            'manifest.toml',
            TomlDocument.fromMap(package()).toString(),
          ),
        )
        ..add(
          ArchiveFile.bytes('icons/tab_server.png', utf8.encode('../outside'))
            ..mode = 0xa1ff,
        );
      await expectLater(
        ThemePackages.install(
          ZipEncoder().encodeBytes(withSymlink),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('rejects a compressed asset larger than its extracted limit', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-zip-limit-');
    try {
      await expectLater(
        ThemePackages.install(
          bundle(package(), {
            'icons/tab_server.png': List.filled(256 * 1024 + 1, 0),
          }),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('validates palette roles and preserves their colors', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-palette-test-');
    try {
      final data = package();
      (data['colors'] as Map<String, Object?>)['palette'] = {
        'light': {'primary': 0xff123456},
        'dark': {'surface': 0xff101010},
      };
      final installed = await ThemePackages.install(
        bundle(data),
        rootDirectory: root.path,
      );
      expect(installed.paletteLight['primary'], 0xff123456);
      expect(installed.paletteDark['surface'], 0xff101010);
      ((data['colors'] as Map<String, Object?>)['palette']
          as Map<String, Object?>)['light'] = {
        'unknownRole': 0xff123456,
      };
      await expectLater(
        ThemePackages.install(bundle(data), rootDirectory: root.path),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('accepts only credential-free HTTPS theme links', () {
    expect(
      ThemePackages.httpsUri('https://example.org/theme.fsbt').scheme,
      'https',
    );
    expect(
      () => ThemePackages.httpsUri('http://example.org/theme.fsbt'),
      throwsFormatException,
    );
    expect(
      () => ThemePackages.httpsUri('https://user:pass@example.org/theme.fsbt'),
      throwsFormatException,
    );
  });

  test('font family names retain fallback order and remove duplicates', () {
    expect(
      AppFont.normalizeFamilies([' Inter ', 'Noto Sans', 'inter', '', 'Arial']),
      ['Inter', 'Noto Sans', 'Arial'],
    );
  });
}

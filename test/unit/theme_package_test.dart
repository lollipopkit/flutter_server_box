import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/app_font.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/theme_style.dart';
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

  /// The same package at the newest schema, which is what anything carrying an
  /// SVG icon, a per-icon color or a splash has to declare as its *minimum*.
  Map<String, Object?> package2() =>
      package()..['schema'] = {'min': 2, 'max': 2};

  const svgIcon =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<circle cx="12" cy="12" r="10" fill="currentColor"/></svg>';

  Future<List<int>> png() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = Colors.pink,
    );
    final image = await recorder.endRecording().toImage(4, 4);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    return bytes;
  }

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

  test('a theme is found by its installation id, not by the id it declares',
      () async {
    final root = await Directory.systemTemp.createTemp('fsbt-id-');
    try {
      final installed = await ThemePackages.install(
        bundle(package()),
        rootDirectory: root.path,
      );
      expect(installed.id, 'example.amethyst');

      // Two names for two things: the declared id identifies the theme across
      // versions and releases, the digest identifies these bytes. Handing the
      // first to a lookup that takes the second answers null without saying so,
      // which reads as "not installed" — a preset row showing invalid, or a
      // selection reset to the default.
      expect(installed.installationId, isNot(installed.id));
      expect(
        ThemePackages.installed(
          installed.id,
          rootDirectory: root.path,
        ),
        isNull,
        reason: 'the declared id is not a digest',
      );
      expect(
        ThemePackages.installed(
          installed.installationId,
          rootDirectory: root.path,
        )?.name,
        'Amethyst',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('a preset and an installation id are one conversion in one place', () {
    const installationId =
        'a3f1c07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469';

    expect(ThemePackages.presetOf(installationId), 'package:$installationId');
    expect(
      ThemePackages.installationIdOf(ThemePackages.presetOf(installationId)),
      installationId,
    );

    // Everything else a preset can be: a builtin, the custom one, or nothing.
    expect(ThemePackages.installationIdOf('default'), isNull);
    expect(ThemePackages.installationIdOf('custom'), isNull);
    expect(ThemePackages.installationIdOf(''), isNull);
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
        expect(theme.iconStyle, IconStyle.classic);
        expect(theme.iconFiles, isEmpty);
        expect(theme.backgroundStyle, BackgroundStyle.none);
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
        {'min': 3, 'max': 3},
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
      profile['schema'] = {'min': 3, 'max': 3};
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

  test('installs SVG and PNG icons together and reports each one', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-svg-test-');
    try {
      final data = package2();
      final images =
          (data['icons'] as Map<String, Object?>)['images']
              as Map<String, String>;
      images['tab.server'] = 'icons/tab_server.svg';
      images['nav.settings'] = 'icons/nav_settings.png';
      final installed = await ThemePackages.install(
        bundle(data, {
          'icons/tab_server.svg': utf8.encode(svgIcon),
          'icons/nav_settings.png': await png(),
        }),
        rootDirectory: root.path,
      );
      expect(installed.iconPath('tab.server'), endsWith('tab_server.svg'));
      expect(installed.iconPath('nav.settings'), endsWith('nav_settings.png'));
      expect(installed.iconPath('nav.folder'), isNull);
      expect(
        await File(installed.iconPath('tab.server')!).readAsString(),
        svgIcon,
      );

      // Which format each icon is in is a question for the directory, so the
      // reading side has to answer it without the manifest it was installed by.
      final restored = ThemePackages.installed(
        installed.installationId,
        rootDirectory: root.path,
      )!;
      expect(restored.iconPath('tab.server'), endsWith('.svg'));
      expect(restored.iconPath('nav.settings'), endsWith('.png'));
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('an SVG icon is refused as a PNG and a PNG as an SVG', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-icon-mix-');
    try {
      for (final (name, bytes) in [
        ('icons/tab_server.png', utf8.encode(svgIcon)),
        ('icons/tab_server.svg', await png()),
      ]) {
        final data = package2();
        ((data['icons'] as Map<String, Object?>)['images']
                as Map<String, String>)['tab.server'] =
            name;
        await expectLater(
          ThemePackages.install(
            bundle(data, {name: bytes}),
            rootDirectory: root.path,
          ),
          throwsFormatException,
        );
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses SVG documents that are not drawings', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-svg-reject-');
    try {
      Future<void> attempt(String source) async {
        final data = package2();
        ((data['icons'] as Map<String, Object?>)['images']
                as Map<String, String>)['tab.server'] =
            'icons/tab_server.svg';
        await expectLater(
          ThemePackages.install(
            bundle(data, {'icons/tab_server.svg': utf8.encode(source)}),
            rootDirectory: root.path,
          ),
          throwsFormatException,
        );
      }

      const body = '<circle cx="12" cy="12" r="10" fill="currentColor"/>';
      for (final source in [
        // A DTD is what entity expansion and external entities need to exist.
        '<!DOCTYPE svg SYSTEM "http://example.org/svg.dtd"><svg>$body</svg>',
        '<!DOCTYPE svg [<!ENTITY x "y">]><svg>$body</svg>',
        // Anything that reaches outside the file.
        '<svg xmlns:xlink="http://www.w3.org/1999/xlink">'
            '<image href="http://example.org/a.png"/></svg>',
        "<svg><image href='http://example.org/a.png'/></svg>",
        '<svg><style>@import url(http://example.org/a.css);</style></svg>',
        '<svg><script>alert(1)</script></svg>',
        '<svg><foreignObject><body/></foreignObject></svg>',
        // And what is not an SVG at all.
        '<svg',
        '<html><body>not a drawing</body></html>',
      ]) {
        await attempt(source);
      }
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('an oversized SVG is refused like an oversized PNG', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-svg-limit-');
    try {
      final data = package2();
      ((data['icons'] as Map<String, Object?>)['images']
              as Map<String, String>)['tab.server'] =
          'icons/tab_server.svg';
      await expectLater(
        ThemePackages.install(
          bundle(data, {
            'icons/tab_server.svg': [
              ...utf8.encode('<svg>'),
              ...List.filled(256 * 1024, 0),
            ],
          }),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('an SVG icon installs out of a folder as well', () async {
    final source = await Directory.systemTemp.createTemp('fsbt-svg-folder-');
    final root = await Directory.systemTemp.createTemp('fsbt-svg-folder-in-');
    try {
      final data = package2();
      ((data['icons'] as Map<String, Object?>)['images']
              as Map<String, String>)['tab.server'] =
          'icons/tab_server.svg';
      await File(
        '${source.path}/manifest.toml',
      ).writeAsString(TomlDocument.fromMap(data).toString());
      await Directory('${source.path}/icons').create();
      await File('${source.path}/icons/tab_server.svg').writeAsString(svgIcon);
      final installed = await ThemePackages.installFolder(
        source.path,
        rootDirectory: root.path,
      );
      expect(installed.iconPath('tab.server'), endsWith('.svg'));
    } finally {
      await source.delete(recursive: true);
      await root.delete(recursive: true);
    }
  });

  test('per-icon colors are read as a role name or an ARGB integer', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-icon-color-');
    try {
      final data = package2();
      final icons = data['icons'] as Map<String, Object?>;
      (icons['images'] as Map<String, String>)
        ..['tab.server'] = 'icons/tab_server.svg'
        ..['nav.settings'] = 'icons/nav_settings.png';
      icons['colors'] = {'tab.server': 'primary', 'nav.settings': 0xff123456};
      final installed = await ThemePackages.install(
        bundle(data, {
          'icons/tab_server.svg': utf8.encode(svgIcon),
          'icons/nav_settings.png': await png(),
        }),
        rootDirectory: root.path,
      );
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      expect(installed.iconColor('tab.server', scheme), scheme.primary);
      expect(
        installed.iconColor('nav.settings', scheme),
        const Color(0xff123456),
      );
      // Without one the icon follows the ambient color, which is what every
      // icon did before a package could say otherwise.
      expect(installed.iconColor('nav.folder', scheme), isNull);

      final restored = ThemePackages.installed(
        installed.installationId,
        rootDirectory: root.path,
      )!;
      expect(restored.iconColor('tab.server', scheme), scheme.primary);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses an icon color for an icon the package does not carry', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-icon-orphan-');
    try {
      final data = package2();
      (data['icons'] as Map<String, Object?>)['colors'] = {
        'tab.server': 'primary',
      };
      await expectLater(
        ThemePackages.install(bundle(data), rootDirectory: root.path),
        throwsFormatException,
      );
      ((data['icons'] as Map<String, Object?>)['colors'] as Map<String, Object?>)
          ['tab.server'] = 'nosuchrole';
      await expectLater(
        ThemePackages.install(
          bundle(data, {'icons/tab_server.svg': utf8.encode(svgIcon)}),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses a schema 2 feature declared as readable by schema 1', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-feature-schema-');
    try {
      /// A package that says it can be read by schema 1 and then reaches for
      /// something only schema 2 has: an older build would install it and draw
      /// the icon without the SVG, the color and the splash, with nothing said.
      ///
      /// Each attempt carries everything it names, so that the refusal is the
      /// schema gate rather than an asset the package did not ship.
      Future<void> attempt(
        void Function(Map<String, Object?> data) edit,
        Map<String, List<int>> files, {
        Map<String, Object?> schema = const {'min': 1, 'max': 1},
      }) async {
        final data = package()..['schema'] = schema;
        edit(data);
        await expectLater(
          ThemePackages.install(
            bundle(data, files),
            rootDirectory: root.path,
          ),
          throwsFormatException,
        );
      }

      final icon = {'icons/tab_server.svg': utf8.encode(svgIcon)};
      await attempt((data) {
        ((data['icons'] as Map<String, Object?>)['images']
                as Map<String, String>)['tab.server'] =
            'icons/tab_server.svg';
      }, icon);
      await attempt((data) {
        final icons = data['icons'] as Map<String, Object?>;
        (icons['images'] as Map<String, String>)['tab.server'] =
            'icons/tab_server.svg';
        icons['colors'] = {'tab.server': 'primary'};
      }, icon);
      await attempt(
        (data) => data['splash'] = {'logo': 'splash_logo.png'},
        {'splash_logo.png': await png()},
      );
      // What a package needs is not that its range contains 2 but that it
      // needs 2: a range of 1–2 still tells a schema 1 build it may read these
      // bytes, which is the install that drops the feature.
      await attempt((data) {
        ((data['icons'] as Map<String, Object?>)['images']
                as Map<String, String>)['tab.server'] =
            'icons/tab_server.svg';
      }, icon, schema: const {'min': 1, 'max': 2});
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('installs a splash with its logo and reads it back', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-splash-test-');
    try {
      final data = package2();
      data['splash'] = {
        'color': 'surface',
        'logo': 'splash_logo.png',
        'duration': 900,
      };
      final logo = await png();
      final installed = await ThemePackages.install(
        bundle(data, {'splash_logo.png': logo}),
        rootDirectory: root.path,
      );
      expect(installed.splash!.duration, 900);
      expect(installed.splashLogoPath, endsWith('splash_logo.png'));
      expect(await File(installed.splashLogoPath!).length(), logo.length);

      final restored = ThemePackages.installed(
        installed.installationId,
        rootDirectory: root.path,
      )!;
      expect(restored.splash!.color, 'surface');
      expect(restored.splash!.duration, 900);
      expect(restored.splashLogoPath, installed.splashLogoPath);
      // The one default, and the reason `splash` is not in the defaults table:
      // every package would otherwise carry one.
      expect(
        (await ThemePackages.install(
          bundle(package2()),
          rootDirectory: root.path,
        )).splash,
        isNull,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('a splash logo may be an SVG as well', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-splash-svg-');
    try {
      final data = package2();
      data['splash'] = {'logo': 'splash_logo.svg'};
      final installed = await ThemePackages.install(
        bundle(data, {'splash_logo.svg': utf8.encode(svgIcon)}),
        rootDirectory: root.path,
      );
      expect(installed.splash!.color, 'surface');
      expect(installed.splash!.duration, ThemeSplash.defaultDuration);
      expect(installed.splashLogoPath, endsWith('.svg'));

      data['splash'] = {'logo': 'splash_logo.svg', 'duration': 99};
      await expectLater(
        ThemePackages.install(
          bundle(data, {'splash_logo.svg': utf8.encode(svgIcon)}),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
      data['splash'] = {'logo': 'splash_logo.svg', 'duration': 3001};
      await expectLater(
        ThemePackages.install(
          bundle(data, {'splash_logo.svg': utf8.encode(svgIcon)}),
          rootDirectory: root.path,
        ),
        throwsFormatException,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses a splash the package cannot honour', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-splash-reject-');
    try {
      Future<void> attempt(
        Map<String, Object?> splash, [
        Map<String, List<int>> files = const {},
      ]) async {
        final data = package2()..['splash'] = splash;
        await expectLater(
          ThemePackages.install(bundle(data, files), rootDirectory: root.path),
          throwsFormatException,
        );
      }

      // A logo is a name, not a path, and only one name is read.
      await attempt({'logo': '../logo.png'}, {'splash_logo.png': await png()});
      await attempt({'logo': 'logo.png'}, {'splash_logo.png': await png()});
      // Declared but not carried.
      await attempt({'logo': 'splash_logo.png'});
      await attempt({'unknowable': true});
      await attempt({'color': 'nosuchrole'});
      await attempt({'duration': 'long'});
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('refuses an unknown section or icon field by name', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-section-test-');
    try {
      // A misspelled section used to be dropped by normalization with nothing
      // said, which is what a typo looks like when it is installed.
      final misspelled = package2()..['splas'] = {'color': 0xff102030};
      await expectLater(
        ThemePackages.install(bundle(misspelled), rootDirectory: root.path),
        throwsFormatException,
      );
      final unknownIcon = package2();
      (unknownIcon['icons'] as Map<String, Object?>)['image'] =
          <String, String>{};
      await expectLater(
        ThemePackages.install(bundle(unknownIcon), rootDirectory: root.path),
        throwsFormatException,
      );
      expect(ThemePackages.listInstalled(rootDirectory: root.path), isEmpty);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('font family names retain fallback order and remove duplicates', () {
    expect(
      AppFont.normalizeFamilies([' Inter ', 'Noto Sans', 'inter', '', 'Arial']),
      ['Inter', 'Noto Sans', 'Arial'],
    );
  });
}

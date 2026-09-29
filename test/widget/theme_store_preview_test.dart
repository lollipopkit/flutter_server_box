/// The theme store's preview: the theme the app would draw, built only for a
/// row that is opened, with its variants and brightnesses to look through.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/theme_store/preview.dart';
import 'package:toml/toml.dart';

import '../helpers/test_db.dart';

void main() {
  // The theme is built as the app builds it, which reads the user's fonts.
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });
  tearDown(() async {
    await getIt.unregister<SettingStore>();
    await closeTestDb();
  });

  testWidgets('draws the variant and brightness picked', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('theme-store-preview-'),
    ))!;
    addTearDown(() => root.deleteSync(recursive: true));
    final manifest = TomlDocument.fromMap({
      'id': 'test.pride',
      'name': 'Pride',
      'modes': ['light', 'dark'],
      'schema': {'min': 3, 'max': 3},
      'variants': {
        'trans': {
          'name': 'Trans',
          'colors': {
            'palette': {
              'light': {'primary': 0xFF1F74A8},
              'dark': {'primary': 0xFF5BCEFA},
            },
          },
        },
        'rainbow': {
          'name': 'Rainbow',
          'colors': {
            'palette': {
              'light': {'primary': 0xFF1F49D6},
            },
          },
        },
      },
    }).toString();
    final theme = (await tester.runAsync(
      () => ThemePackages.installAssets({
        'manifest.toml': Uint8List.fromList(utf8.encode(manifest)),
      }, rootDirectory: root.path),
    ))!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThemeStorePreview(theme: theme, rootDirectory: root.path),
          ),
        ),
      ),
    );

    Color button() {
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      return material.color!;
    }

    expect(button(), const Color(0xFF1F74A8), reason: 'the first variant');

    await tester.tap(find.text('Rainbow'));
    await tester.pump();
    expect(button(), const Color(0xFF1F49D6));

    await tester.tap(find.text('Trans'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump();
    expect(button(), const Color(0xFF5BCEFA), reason: 'the dark palette');
  });
}

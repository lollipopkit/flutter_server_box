import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/app.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

/// A 1x1 PNG, so that `Image.file` has something it can actually decode.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingStore setting;

  setUp(() async {
    SqliteDb.openInMemory();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  (ThemeData, ThemeData) themesOf(WidgetTester tester) {
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    return (app.theme!, app.darkTheme!);
  }

  testWidgets('the bar goes with a background image', (tester) async {
    final file = File(
      '${Directory.systemTemp.path}/sbm_appbar_background_test.png',
    )..writeAsBytesSync(_png);
    addTearDown(() => file.deleteSync());

    setting.appBackgroundStyle.put(BackgroundStyle.image);
    setting.appBackgroundPath.put(file.path);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final (light, dark) = themesOf(tester);
    for (final theme in [light, dark]) {
      // The page under the bar is transparent, so an opaque bar here is a strip
      // of a colour the wallpaper does not have, across the top of it.
      expect(
        theme.appBarTheme.backgroundColor,
        Colors.transparent,
        reason: 'the bar is not see-through over the wallpaper',
      );
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a background the bar keeps the scheme surface', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final (light, dark) = themesOf(tester);
    for (final theme in [light, dark]) {
      // Null rather than the surface itself: the bar resolving the scheme is
      // Material's default and stays reachable through the theme.
      expect(theme.appBarTheme.backgroundColor, isNull);
      expect(theme.scaffoldBackgroundColor, isNot(Colors.transparent));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

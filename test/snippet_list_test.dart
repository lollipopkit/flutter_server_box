import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/snippet/list.dart';

/// There has to be a way to make the first snippet, at every width.
///
/// The page has two of them and shows one: a floating button on a single
/// column, and a row above the rail when the editor has a column of its own —
/// the floating one is suppressed there, because it would cover the row under
/// it. Which means an early return that skips the rail also takes away the
/// only way to add anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> settingBox;
  late Box<dynamic> snippetBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-snippet-');
    Hive.init(tempDir.path);
    // In memory: this page persists the pane width on every drag, and a real
    // write started in a `testWidgets` body never lets go of the box's lock.
    settingBox = await Hive.openBox<dynamic>(
      'setting_test',
      bytes: Uint8List(0),
    );
    snippetBox = await Hive.openBox<dynamic>(
      'snippet_test',
      bytes: Uint8List(0),
    );
    getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
    getIt.registerSingleton<SnippetStore>(SnippetStore.forBox(snippetBox));
  });

  tearDown(() async {
    await getIt.reset();
    await settingBox.close();
    await snippetBox.close();
    await tempDir.delete(recursive: true);
  });

  /// [width] decides the layout: `AdaptivePanes.minWidthForDetail` is 800, so
  /// above it the editor gets a column and the page draws the rail.
  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: const SnippetListPage(),
        ),
      ),
    );
    // Counted out rather than settled: the tag bar animates, and
    // `pumpAndSettle` on a tree that always has a frame scheduled waits its
    // full ten minutes before giving up.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('an empty list on a wide window still offers add', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    // The regression: the emptiness was answered before the rail was built, so
    // a wide window with no snippets had no floating button *and* no row.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('an empty list on a narrow window offers the floating button', (
    tester,
  ) async {
    await pump(tester, width: 500);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('a wide window with snippets lists them under the same row', (
    tester,
  ) async {
    Stores.snippet.put(const Snippet(name: 'deploy', script: 'echo hi'));

    await pump(tester, width: 1200);

    expect(find.text('deploy'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}

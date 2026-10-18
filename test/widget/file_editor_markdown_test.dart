import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:re_editor/re_editor.dart';
import 'package:server_box/view/page/rescue_app.dart';
import 'package:server_box/view/page/storage/code_editor.dart';

/// Markdown files open as rendered Markdown; source is one tap away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(
    WidgetTester tester, {
    required ProgLang lang,
    required String title,
    required String text,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RescueApp(
        page: FileEditorPage(
          args: EditorPageArgs(
            title: title,
            lang: lang,
            text: text,
            onSave: (_) {},
          ),
        ),
      ),
    );
    // Counted out rather than settled: the editor's field keeps a frame
    // scheduled, and `pumpAndSettle` waits its full ten minutes.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a markdown file opens as rendered Markdown', (tester) async {
    await pumpEditor(
      tester,
      lang: ProgLang.markdown,
      title: 'README.md',
      text: '# Hello\n\nA paragraph.',
    );

    expect(find.byType(SimpleMarkdown), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('A paragraph.'), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);
    expect(find.byTooltip(libL10n.edit), findsOneWidget);
    expect(find.byTooltip(libL10n.search), findsNothing);
    expect(find.byTooltip(libL10n.format), findsNothing);
  });

  testWidgets('edit and preview swap the source and the rendered view', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      lang: ProgLang.markdown,
      title: 'README.md',
      text: '# Hello\n\nA paragraph.',
    );

    await tester.tap(find.byTooltip(libL10n.edit));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byType(SimpleMarkdown), findsNothing);
    expect(find.byTooltip(libL10n.preview), findsOneWidget);
    expect(find.byTooltip(libL10n.search), findsOneWidget);
    expect(find.byTooltip(libL10n.format), findsOneWidget);

    await tester.tap(find.byTooltip(libL10n.preview));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(SimpleMarkdown), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('a JSON file stays a source editor', (tester) async {
    await pumpEditor(
      tester,
      lang: ProgLang.json,
      title: 'package.json',
      text: '{"name":"x"}',
    );

    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byType(SimpleMarkdown), findsNothing);
    expect(find.byTooltip(libL10n.preview), findsNothing);
    expect(find.byTooltip(libL10n.edit), findsNothing);
  });
}

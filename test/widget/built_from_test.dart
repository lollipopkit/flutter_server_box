import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/built_from.dart';

/// A subtree that is built again only when what it says has changed.
///
/// The risk in it is the one it exists to take: something it shows that is not
/// in its inputs goes stale, and nothing fails. So what these hold is the two
/// sides of that — that it does skip, and what it never skips through.
void main() {
  var built = 0;
  setUp(() => built = 0);

  Widget host({
    required List<Object?> inputs,
    required String says,
    ThemeData? theme,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: theme ?? ThemeData.light(),
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('de')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: BuiltFrom(
      inputs,
      builder: (_) {
        built++;
        return Text(says);
      },
    ),
  );

  testWidgets('is built once for as long as its inputs are what they were', (
    tester,
  ) async {
    await tester.pumpWidget(host(inputs: const ['a', 1, (k: 'x', v: 2)], says: 'one'));
    final was = tester.widget(find.text('one'));
    // New lists and a new record each time, equal to the old ones: what a
    // page hands it on every poll.
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(
        host(inputs: ['a', 1, (k: 'x', v: 2)], says: 'never drawn'),
      );
    }
    expect(built, 1);
    expect(tester.widget(find.text('one')), same(was));
  });

  testWidgets('and again when any of them is not', (tester) async {
    await tester.pumpWidget(host(inputs: const ['a', 1], says: 'one'));
    await tester.pumpWidget(host(inputs: const ['a', 2], says: 'two'));
    expect(built, 2);
    expect(find.text('two'), findsOneWidget);

    // One more or one fewer is a change as well.
    await tester.pumpWidget(host(inputs: const ['a', 2, null], says: 'three'));
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets('and when the theme or the locale is, which nobody lists', (
    tester,
  ) async {
    // Most of what it keeps was built by a page's own methods from the page's
    // context, so the builder reading neither is the ordinary case — and a
    // kept subtree with a colour worked out from the old theme in it is the
    // failure this is here to not have.
    await tester.pumpWidget(host(inputs: const ['a'], says: 'one'));
    await tester.pumpWidget(
      host(inputs: const ['a'], says: 'dark', theme: ThemeData.dark()),
    );
    // The app eases from one theme to the other, so it is a frame later that
    // there is another theme to be told of.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('dark'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(
      host(
        inputs: const ['a'],
        says: 'deutsch',
        theme: ThemeData.dark(),
        locale: const Locale('de'),
      ),
    );
    await tester.pump();
    expect(find.text('deutsch'), findsOneWidget);
  });
}

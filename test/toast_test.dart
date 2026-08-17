import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The toast animates and runs a dismiss timer, so a frame in which nothing is
/// scheduled never arrives: `pumpAndSettle` would wait out its ten minute
/// default. Every wait here is counted out instead.
const _enter = Duration(milliseconds: 300);
const _exit = Duration(milliseconds: 400);

Widget _app() => MaterialApp(
      builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
      home: const Scaffold(body: SizedBox.expand()),
    );

void main() {
  // Static state: a toast left behind by one test would show up in the next.
  // Every item is disposed with the tree, so nothing is left to animate out and
  // the entries go immediately.
  tearDown(Toast.dismissAll);

  testWidgets('shows the title only until it is opened', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Saved', body: 'to /etc/hosts');
    await tester.pump();
    await tester.pump(_enter);

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('to /etc/hosts'), findsNothing);

    await tester.tap(find.text('Saved'));
    await tester.pump();

    expect(find.text('to /etc/hosts'), findsOneWidget);
  });

  testWidgets('an overflowing title opens too, with no body', (tester) async {
    await tester.pumpWidget(_app());

    const long = 'SSHError: connection to 192.168.1.100 was refused after '
        'three attempts, the host may be down or the port closed';
    Toast.show(long);
    await tester.pump();
    await tester.pump(_enter);

    expect(tester.widget<Text>(find.text(long)).maxLines, 1);

    await tester.tap(find.text(long));
    await tester.pump();

    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
  });

  testWidgets('a short title with no body cannot be opened', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Done');
    await tester.pump();
    await tester.pump(_enter);

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('long press copies the title and the body', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    Object? copied;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'];
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_app());

    Toast.error('Failed', body: 'No such file or directory');
    await tester.pump();
    await tester.pump(_enter);

    await tester.longPress(find.text('Failed'));
    await tester.pump();

    expect(copied, 'Failed\n\nNo such file or directory');
  });

  testWidgets('a horizontal drag dismisses it', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Swipe me', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    await tester.drag(find.text('Swipe me'), const Offset(500, 0));
    await tester.pump();
    await tester.pump(_exit);
    await tester.pump(_exit);

    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('it goes on its own when the duration is up', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Bye', duration: const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(_enter);

    expect(find.text('Bye'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(_exit);

    expect(find.text('Bye'), findsNothing);
  });

  testWidgets('opening it stops the countdown', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Read me', body: 'detail', duration: const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(_enter);

    await tester.tap(find.text('Read me'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Read me'), findsOneWidget);
  });

  testWidgets('a level draws its icon', (tester) async {
    await tester.pumpWidget(_app());

    Toast.success('Done');
    await tester.pump();
    await tester.pump(_enter);

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('a tagged toast replaces the one before it', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Press again to exit', tag: 'exit', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    Toast.show('Press again to exit', tag: 'exit', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_exit);

    expect(find.text('Press again to exit'), findsOneWidget);
  });

  testWidgets('it sits in the top end corner, clear of the window caption', (tester) async {
    // The view, not the surface: MediaQuery reports the view, and the layer
    // positions itself from the padding and the size it reads there.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    Toast.show('Corner');
    await tester.pump();
    await tester.pump(_enter);

    final card = tester.getRect(find.ancestor(of: find.text('Corner'), matching: find.byType(Material)).first);
    expect(card.right, closeTo(1280 - ToastConfig.margin.right, 0.5));
    expect(card.width, ToastConfig.maxWidth);
    final caption = WindowFrameConfig.showCaption ? CustomAppBar.sysStatusBarHeight : 0.0;
    expect(card.top, closeTo(caption + ToastConfig.margin.top, 0.5));
  });

  testWidgets('a narrow window shrinks it instead of clipping it', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    Toast.show('Narrow');
    await tester.pump();
    await tester.pump(_enter);

    final card = tester.getRect(find.ancestor(of: find.text('Narrow'), matching: find.byType(Material)).first);
    expect(card.width, 320 - ToastConfig.margin.horizontal);
    expect(card.left, greaterThanOrEqualTo(0));
  });

  testWidgets('the stack keeps at most maxVisible', (tester) async {
    await tester.pumpWidget(_app());

    for (var i = 0; i < ToastConfig.maxVisible + 2; i++) {
      Toast.show('toast $i', duration: Duration.zero);
    }
    await tester.pump();
    await tester.pump(_enter);
    await tester.pump(_exit);

    expect(find.text('toast 0'), findsNothing);
    expect(find.text('toast 1'), findsNothing);
    expect(find.text('toast ${ToastConfig.maxVisible + 1}'), findsOneWidget);
  });
}

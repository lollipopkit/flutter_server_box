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

/// [ToastConfig.align] is global and is read when an item mounts, so it has to
/// be set before the tree is pumped and put back afterwards.
void _useAlign(ToastAlign align) {
  final previous = ToastConfig.align;
  ToastConfig.align = align;
  addTearDown(() => ToastConfig.align = previous);
}

Finder get _countdownBar => find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(ColoredBox),
    );

Rect _cardOf(WidgetTester tester, String title) => tester.getRect(
      find.ancestor(of: find.text(title), matching: find.byType(Material)).first,
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

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
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

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();

    expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
  });

  testWidgets('tapping a lone toast does nothing at all', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Alone', body: 'detail', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(_enter);

    final running = tester.getSize(_countdownBar).width;

    await tester.tap(find.text('Alone'));
    await tester.pump(const Duration(milliseconds: 100));

    // Not opened, and the countdown neither held (which would leave the bar
    // where it was) nor started over (which would put it back to full): a lone
    // toast sits there and expires on time however much it is tapped. Its body
    // is on the chevron.
    expect(find.text('detail'), findsNothing);
    expect(tester.getSize(_countdownBar).width, lessThan(running));

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(_exit);
    expect(find.text('Alone'), findsNothing);
  });

  testWidgets('opening a body grows the card over several frames', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Grow', body: 'a detail line', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    final collapsed = _cardOf(tester, 'Grow').height;

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final midway = _cardOf(tester, 'Grow').height;

    await tester.pump(const Duration(milliseconds: 400));
    final opened = _cardOf(tester, 'Grow').height;

    expect(midway, greaterThan(collapsed));
    expect(opened, greaterThan(midway));
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

  testWidgets('a drag towards the edge it sits on dismisses it', (tester) async {
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

  testWidgets('a drag the other way does not', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Stay', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    // Inwards, across the content the toast covers. There is no edge that way.
    await tester.drag(find.text('Stay'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(_exit);
    await tester.pump(_exit);

    expect(find.text('Stay'), findsOneWidget);
  });

  testWidgets('pulled inwards it gives way less and less, then springs back', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Rubber', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    final home = _cardOf(tester, 'Rubber').left;
    double pulledBy() => home - _cardOf(tester, 'Rubber').left;
    final gesture = await tester.startGesture(tester.getCenter(find.text('Rubber')));

    // The first move only gets the drag recognised — it goes on touch slop, as
    // it does for any drag — so the pull is measured from the one after it.
    await gesture.moveBy(const Offset(-25, 0));
    await tester.pump();
    expect(pulledBy(), 0);

    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    final near = pulledBy();

    await gesture.moveBy(const Offset(-400, 0));
    await tester.pump();
    final far = pulledBy();

    expect(near, greaterThan(0));
    expect(far, greaterThan(near));
    // Thirteen times the pull moved it barely twice as far, and _rubberLimit
    // (36) is the bound it approaches without reaching.
    expect(far, lessThan(36));
    expect(far, lessThan(near * 3));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(_cardOf(tester, 'Rubber').left, closeTo(home, 0.5));
  });

  testWidgets('the arrival clip lets the sides through, and then goes', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Clip', duration: Duration.zero);
    await tester.pump();

    final arriving = find.ancestor(of: find.text('Clip'), matching: find.byType(ClipRect));
    final clipper = tester.widget<ClipRect>(arriving).clipper;

    // Top and bottom only. Growing into place is the vertical half of it; the
    // slide it arrives on and the shadow it casts are on the sides.
    final rect = clipper!.getClip(const Size(380, 40));
    expect(rect.top, 0);
    expect(rect.bottom, 40);
    expect(rect.left, lessThan(-1000));
    expect(rect.right, greaterThan(1380));

    await tester.pump(_enter);
    // And once it is in place nothing clips it at all — not its shadow, not a
    // drag past its own bounds.
    expect(arriving, findsNothing);
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

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
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

    final card = _cardOf(tester, 'Corner');
    expect(card.right, closeTo(1280 - ToastConfig.margin.right, 0.5));
    expect(card.width, ToastConfig.maxWidth);
    final caption = WindowFrameConfig.showCaption ? CustomAppBar.sysStatusBarHeight : 0.0;
    expect(card.top, closeTo(caption + ToastConfig.margin.top, 0.5));
  });

  testWidgets('a countdown bar shrinks along the bottom edge', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Timed', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(_enter);

    final started = tester.getSize(_countdownBar).width;
    expect(started, greaterThan(0));
    expect(tester.getSize(_countdownBar).height, 1);

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(_countdownBar).width, lessThan(started));
  });

  testWidgets('no bar when the toast does not expire', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Kept', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    expect(_countdownBar, findsNothing);
  });

  testWidgets('the bar goes back to full while the countdown is paused', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Paused', body: 'detail', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(_enter);

    final running = tester.getSize(_countdownBar).width;
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();

    expect(tester.getSize(_countdownBar).width, greaterThan(running));
  });

  testWidgets('centred at the top, it only goes up', (tester) async {
    _useAlign(ToastAlign.topCenter);
    await tester.pumpWidget(_app());

    Toast.show('Up only', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    await tester.drag(find.text('Up only'), const Offset(500, 0));
    await tester.pump();
    await tester.pump(_exit);
    expect(find.text('Up only'), findsOneWidget);

    await tester.drag(find.text('Up only'), const Offset(0, -300));
    await tester.pump();
    await tester.pump(_exit);
    await tester.pump(_exit);
    expect(find.text('Up only'), findsNothing);
  });

  testWidgets('each align puts it against the edges it names', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _useAlign(ToastAlign.bottomCenter);

    await tester.pumpWidget(_app());
    Toast.show('Placed', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);

    final card = _cardOf(tester, 'Placed');
    expect(card.center.dx, closeTo(1280 / 2, 0.5));
    expect(card.bottom, closeTo(800 - ToastConfig.margin.bottom, 0.5));
  });

  testWidgets('a narrow window shrinks it instead of clipping it', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    Toast.show('Narrow');
    await tester.pump();
    await tester.pump(_enter);

    final card = _cardOf(tester, 'Narrow');
    expect(card.width, 320 - ToastConfig.margin.horizontal);
    expect(card.left, greaterThanOrEqualTo(0));
  });

  // _kPeek and _kPileGap in host.dart. Named here so the numbers below read.
  const peek = 7.0;
  const pileGap = 8.0;

  Future<void> pumpPair(WidgetTester tester) async {
    await tester.pumpWidget(_app());
    Toast.show('older', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);
    Toast.show('newer', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);
    await tester.pump(_enter);
  }

  testWidgets('a second toast piles in front of the first', (tester) async {
    await pumpPair(tester);

    final newer = _cardOf(tester, 'newer');
    final older = _cardOf(tester, 'older');

    // Newest against the edge, the one before it showing an edge from behind.
    expect(newer.top, lessThan(older.top));
    expect(older.top - newer.top, closeTo(peek, 0.5));
  });

  testWidgets('tapping the front opens the whole pile, and closes it', (tester) async {
    await pumpPair(tester);
    final piled = _cardOf(tester, 'older').top - _cardOf(tester, 'newer').top;

    await tester.tap(find.text('newer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final opened = _cardOf(tester, 'older').top - _cardOf(tester, 'newer').top;
    expect(opened, greaterThan(piled));
    expect(opened, closeTo(_cardOf(tester, 'newer').height + pileGap, 1));

    await tester.tap(find.text('newer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(_cardOf(tester, 'older').top - _cardOf(tester, 'newer').top, closeTo(piled, 0.5));
  });

  testWidgets('a body is out of reach while piled, and back once opened', (tester) async {
    await tester.pumpWidget(_app());
    Toast.show('first', body: 'hidden detail', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);
    Toast.show('second', duration: Duration.zero);
    await tester.pump();
    await tester.pump(_enter);
    await tester.pump(_enter);

    // The tap went to the pile, so nothing opened its body — and with no body
    // reachable there is no chevron offering one either.
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

    await tester.tap(find.text('second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('hidden detail'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(find.text('hidden detail'), findsOneWidget);
  });

  testWidgets('dragging the front out moves the rest up over time', (tester) async {
    await pumpPair(tester);
    await tester.tap(find.text('newer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final before = _cardOf(tester, 'older').top;

    final gesture = await tester.startGesture(tester.getCenter(find.text('newer')));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();
    await gesture.up();

    // Off the screen first, and only then giving up the height it holds.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_cardOf(tester, 'older').top, closeTo(before, 0.5));

    await tester.pump(const Duration(milliseconds: 40));
    final midway = _cardOf(tester, 'older').top;
    expect(midway, lessThan(before));

    await tester.pump(const Duration(milliseconds: 700));
    expect(_cardOf(tester, 'older').top, lessThan(midway));
    expect(find.text('newer'), findsNothing);
  });

  testWidgets('a frame of the pile opening rebuilds no toast content', (tester) async {
    await pumpPair(tester);

    await tester.tap(find.text('newer'));
    await tester.pump();
    // The tap itself does rebuild them: what a tap means changes once the pile
    // is open. It is the 400ms after it that must not.
    final during = tester.widget(find.text('newer'));

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget(find.text('newer')), same(during));

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget(find.text('newer')), same(during));
  });

  testWidgets('the countdown ticking rebuilds no toast content', (tester) async {
    await tester.pumpWidget(_app());

    Toast.show('Ticking', duration: const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(_enter);
    final built = tester.widget(find.text('Ticking'));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget(find.text('Ticking')), same(built));
  });

  testWidgets('nothing in an open pile expires while it is being read', (tester) async {
    await tester.pumpWidget(_app());
    Toast.show('one', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(_enter);
    Toast.show('two', duration: const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(_enter);

    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('past the peek limit a piled toast is not drawn', (tester) async {
    await tester.pumpWidget(_app());
    for (var i = 0; i < 4; i++) {
      Toast.show('n$i', duration: Duration.zero);
      await tester.pump();
    }
    await tester.pump(_enter);

    // n3 is the front, so n0 is the fourth deep — one past the two edges that
    // show behind it.
    final hidden = find.ancestor(of: find.text('n0'), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(hidden.last).opacity, 0);
    expect(find.ancestor(of: find.text('n2'), matching: find.byType(Opacity)), findsNothing);
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

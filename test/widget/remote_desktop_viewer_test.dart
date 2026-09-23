/// The remote desktop viewer as a widget: what it sends the server, and the
/// walkthrough it shows once.
///
/// A soft keyboard must not resize an RDP session. Opening it shrinks the
/// canvas by the keyboard's height, and that used to be sent to the server as
/// the new screen size — every remote window squashed into the strip above
/// the keyboard, and stretched back when it closed.
library;

import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/viewer.dart';

import '../helpers/test_db.dart';

const _profile = RemoteDesktopProfile(
  id: 'rdp-1',
  serverId: 'srv-1',
  name: 'Windows',
  protocol: RemoteDesktopProtocol.rdp,
  host: '127.0.0.1',
  port: 3389,
  username: 'administrator',
);

class _RecordingSessions extends RemoteDesktopSessions {
  _RecordingSessions({this.connected = false, this.framed = false});

  /// Connected with a desktop on screen, which is what the walkthrough waits
  /// for. Off by default so the resize test never reaches the settings store.
  final bool connected;

  /// With a frame to draw, on a desktop small enough to decode quickly. The
  /// pointer is drawn only over a picture.
  final bool framed;

  static const framedSize = Size(320, 180);

  final resizes = <(int, int)>[];

  /// The button mask of every pointer event sent, in order.
  final buttons = <int>[];

  /// Where each of them was sent, in desktop pixels.
  final points = <Offset>[];

  @override
  void sendPointer(String id, int x, int y, int buttons) {
    this.buttons.add(buttons);
    points.add(Offset(x.toDouble(), y.toDouble()));
  }

  @override
  RemoteDesktopSessionsState build() => const RemoteDesktopSessionsState()
      .put(
        RemoteDesktopSessionView(
          profile: _profile,
          connectionState: connected
              ? ffi.RemoteDesktopConnectionState.connected
              : ffi.RemoteDesktopConnectionState.connecting,
          width: framed ? framedSize.width.toInt() : (connected ? 1280 : 0),
          height: framed ? framedSize.height.toInt() : (connected ? 720 : 0),
          frameBgra: framed
              ? Uint8List(
                  framedSize.width.toInt() * framedSize.height.toInt() * 4,
                )
              : null,
          frameSequence: framed ? BigInt.one : null,
        ),
      )
      .select(_profile.id);

  @override
  void resize(
    String id,
    int width,
    int height, {
    int scaleFactor = 100,
    int? physicalWidthMm,
    int? physicalHeightMm,
  }) => resizes.add((width, height));
}

Future<void> _pumpViewer(WidgetTester tester, _RecordingSessions sessions) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [remoteDesktopSessionsProvider.overrideWith(() => sessions)],
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RemoteDesktopViewer(sessionId: _profile.id)),
        ),
      ),
    );

void main() {
  testWidgets('a soft keyboard does not resize the session', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final sessions = _RecordingSessions();
    await _pumpViewer(tester, sessions);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sessions.resizes, hasLength(1));
    final initial = sessions.resizes.single;

    // Open, and a few frames of it animating in.
    for (final inset in [120.0, 300.0, 500.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(sessions.resizes, [initial]);

    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sessions.resizes, [initial]);

    // A real change of size still goes through.
    tester.view.physicalSize = const Size(1200, 800);
    // Laid out on the first pump, sent once the debounce has run out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(sessions.resizes, hasLength(2));
    expect(sessions.resizes.last.$1, greaterThan(initial.$1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('walkthrough', () {
    _useSettings();

    testWidgets('shows once a desktop is up, and is remembered', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpViewer(tester, _RecordingSessions(connected: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RemoteDesktopViewer)),
      )!;
      // The host is not a phone, so no touch steps: view only, then the menu.
      expect(find.text(l10n.remoteDesktopGuideViewOnlyTip), findsOneWidget);
      expect(Stores.setting.remoteDesktopGuided.fetch(), isFalse);

      await tester.tap(find.text(libL10n.next));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(l10n.remoteDesktopGuideMoreTip), findsOneWidget);
      await tester.tap(find.text(libL10n.done));
      // The fade out runs frame by frame, and the entry goes when it ends.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(l10n.remoteDesktopGuideMoreTip), findsNothing);
      expect(Stores.setting.remoteDesktopGuided.fetch(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('does not show again', (tester) async {
      Stores.setting.remoteDesktopGuided.put(true);
      await _pumpViewer(tester, _RecordingSessions(connected: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(libL10n.next), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('touchpad', () {
    _useSettings();

    setUp(() {
      // Out of the way: the guide's scrim would take the touches.
      Stores.setting.remoteDesktopGuided.put(true);
      RemoteDesktopViewer.debugTouchScreenOverride = true;
    });
    tearDown(() => RemoteDesktopViewer.debugTouchScreenOverride = null);

    Future<_RecordingSessions> pumpConnected(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessions = _RecordingSessions(connected: true);
      await _pumpViewer(tester, sessions);
      await tester.pump();
      return sessions;
    }

    // A finger reports the primary button while it is down, and forwarding
    // that on a move made every drag a selection on the remote desktop.
    testWidgets('one finger moves the pointer without pressing', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final finger = await tester.startGesture(
        canvas,
        kind: PointerDeviceKind.touch,
      );
      for (var i = 0; i < 5; i++) {
        await finger.moveBy(const Offset(20, 10));
      }
      await finger.up();
      await tester.pump();

      expect(sessions.buttons, isNotEmpty);
      expect(sessions.buttons, everyElement(0));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tap, then touch again and drag, holds the button', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final finger = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger.down(canvas);
      await finger.up(timeStamp: const Duration(milliseconds: 80));
      await finger.down(canvas, timeStamp: const Duration(milliseconds: 250));
      for (var i = 1; i <= 3; i++) {
        await finger.moveBy(
          const Offset(20, 10),
          timeStamp: Duration(milliseconds: 250 + i * 16),
        );
      }
      await finger.up(timeStamp: const Duration(milliseconds: 400));
      await tester.pump();

      // One press through the drag and one release: no click before it. A
      // click there made the press the second half of a double click, which
      // the desktop acted on instead of dragging.
      expect(sessions.buttons, [1, 1, 1, 1, 0]);
      // Pressed where the pointer was — the middle of the desktop — before
      // it moved.
      expect(sessions.points.first, const Offset(640, 360));
      // And nothing arrives later from the tap it started with.
      await tester.pump(kDoubleTapTimeout * 2);
      expect(sessions.buttons, hasLength(5));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tapping twice without moving is a double click', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final finger = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger.down(canvas);
      await finger.up(timeStamp: const Duration(milliseconds: 80));
      await finger.down(canvas, timeStamp: const Duration(milliseconds: 200));
      await finger.up(timeStamp: const Duration(milliseconds: 280));
      await tester.pump();

      expect(sessions.buttons, [1, 0, 1, 0]);
      // And nothing more once the wait for a second touch is over.
      await tester.pump(kDoubleTapTimeout * 2);
      expect(sessions.buttons, [1, 0, 1, 0]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a touch long after a tap only moves', (tester) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final finger = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger.down(canvas);
      await finger.up(timeStamp: const Duration(milliseconds: 80));
      await finger.down(canvas, timeStamp: const Duration(seconds: 2));
      await finger.moveBy(
        const Offset(40, 0),
        timeStamp: const Duration(milliseconds: 2016),
      );
      await finger.up(timeStamp: const Duration(milliseconds: 2100));
      await tester.pump();

      // Too late for a drag: the tap clicks, then the touch only moves.
      expect(sessions.buttons, [1, 0, 0]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a tap still clicks', (tester) async {
      final sessions = await pumpConnected(tester);
      await tester.tapAt(
        tester.getCenter(find.byType(RemoteDesktopViewer)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      // Held back while a second touch could still make it a tap and drag,
      // then sent whole.
      expect(sessions.buttons, isEmpty);
      await tester.pump(kDoubleTapTimeout);
      expect(sessions.buttons, [1, 0]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a second finger after a tap is a right click, not a drag', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final first = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 1,
      );
      await first.down(canvas);
      await first.up(timeStamp: const Duration(milliseconds: 80));
      await first.down(canvas, timeStamp: const Duration(milliseconds: 200));
      final second = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 2,
      );
      await second.down(
        canvas + const Offset(40, 0),
        timeStamp: const Duration(milliseconds: 210),
      );
      await second.up(timeStamp: const Duration(milliseconds: 280));
      await first.up(timeStamp: const Duration(milliseconds: 290));
      await tester.pump(kDoubleTapTimeout);

      // The tap's own click, then the two-finger tap's right click.
      expect(sessions.buttons, [1, 0, 4, 0]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a two-finger scroll does not end in a right click', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final first = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 1,
      );
      final second = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 2,
      );
      await first.down(canvas);
      await second.down(canvas + const Offset(60, 0));
      for (var i = 0; i < 4; i++) {
        await first.moveBy(const Offset(0, 20));
        await second.moveBy(const Offset(0, 20));
      }
      await first.up();
      await second.up();
      await tester.pump(kDoubleTapTimeout);

      expect(sessions.buttons, isNot(contains(4)));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // It measured every finger from the first one's position, so the finger
    // left down jumped the pointer by the distance between the two.
    testWidgets('the finger left down moves the pointer from where it is', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final first = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 1,
      );
      final second = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 2,
      );
      await first.down(canvas);
      await second.down(canvas + const Offset(300, 0));
      await first.up();
      await second.moveBy(const Offset(30, 0));
      await second.moveBy(const Offset(10, 0));
      await second.up();
      await tester.pump(kDoubleTapTimeout);

      // 40 points at the 1× this desktop is drawn at, from the middle.
      expect(sessions.points.last, const Offset(680, 360));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // A real finger wanders a few points between landing and lifting. That
    // counted as a move, so the tap neither clicked nor armed tap and drag.
    testWidgets('a tap that wanders a few points is still a tap', (
      tester,
    ) async {
      final sessions = await pumpConnected(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final finger = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger.down(canvas);
      await finger.moveBy(
        const Offset(3, 2),
        timeStamp: const Duration(milliseconds: 30),
      );
      await finger.moveBy(
        const Offset(2, -3),
        timeStamp: const Duration(milliseconds: 60),
      );
      await finger.up(timeStamp: const Duration(milliseconds: 90));
      // And the second touch of a tap and drag, wandering the same way first.
      await finger.down(canvas, timeStamp: const Duration(milliseconds: 250));
      await finger.moveBy(
        const Offset(2, 2),
        timeStamp: const Duration(milliseconds: 270),
      );
      await finger.moveBy(
        const Offset(60, 0),
        timeStamp: const Duration(milliseconds: 300),
      );
      await finger.up(timeStamp: const Duration(milliseconds: 400));
      await tester.pump();

      // The wanders move nothing, and the tap arms the drag: pressed once the
      // second touch moves, and let go once.
      expect(sessions.buttons, [1, 1, 0]);
      // Where the pointer was drawn, not a few points off it.
      expect(sessions.points.first, const Offset(640, 360));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('pointer', () {
    _useSettings();

    setUp(() {
      Stores.setting.remoteDesktopGuided.put(true);
    });
    tearDown(() => RemoteDesktopViewer.debugTouchScreenOverride = null);

    /// Viewer up with its first frame decoded. The desktop is 320×180 in a
    /// 1280-wide window, so the picture is drawn at 4×.
    Future<_RecordingSessions> pumpFramed(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessions = _RecordingSessions(connected: true, framed: true);
      await _pumpViewer(tester, sessions);
      // The frame decodes off the fake clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      return sessions;
    }

    testWidgets('a touchpad pointer is drawn, and follows the finger', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = true;
      final sessions = await pumpFramed(tester);
      expect(find.byKey(RemoteDesktopViewer.cursorKey), findsOneWidget);
      // The default arrow: the server has not sent a picture of its own.
      expect(
        tester.renderObject(find.byKey(RemoteDesktopViewer.cursorKey)),
        paints..path(color: Colors.white),
      );

      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(RemoteDesktopViewer.cursorKey)),
        kind: PointerDeviceKind.touch,
      );
      await finger.moveBy(const Offset(20, 0));
      await finger.moveBy(const Offset(20, 0));
      await finger.up();
      await tester.pump();

      // Starts in the middle of the desktop (160, 90), and 40 points across a
      // picture drawn at 4× is 10 desktop pixels.
      expect(sessions.points.first, const Offset(165, 90));
      expect(sessions.points.last, const Offset(170, 90));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a mouse moves the pointer without a button, undrawn', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = false;
      final sessions = await pumpFramed(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));
      await mouse.moveTo(canvas);
      await mouse.moveTo(canvas + const Offset(40, 0));
      await tester.pump();

      expect(sessions.buttons, isNotEmpty);
      expect(sessions.buttons, everyElement(0));
      expect(sessions.points.last.dx - sessions.points.first.dx, 10);
      // The system's own pointer is on screen; a second one would trail it.
      expect(find.byKey(RemoteDesktopViewer.cursorKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a direct finger presses where it lands, and one at a time', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = false;
      final sessions = await pumpFramed(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final first = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 1,
      );
      await first.down(canvas);
      final second = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 2,
      );
      await second.down(canvas + const Offset(80, 0));
      await second.moveBy(const Offset(40, 0));
      await second.up();
      await first.moveBy(const Offset(40, 0));
      await first.up();
      await tester.pump(kDoubleTapTimeout);

      // Only the first finger: pressed, dragged, let go.
      expect(sessions.buttons, [1, 1, 0]);
      // The middle of a 320×180 desktop drawn at 4×, and 40 points to the
      // right: the second finger's landing and moves are nowhere in it.
      expect(sessions.points, const [
        Offset(160, 85),
        Offset(170, 85),
        Offset(170, 85),
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cancelling an ignored finger leaves the drag alone', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = false;
      final sessions = await pumpFramed(tester);
      final canvas = tester.getCenter(find.byType(RemoteDesktopViewer));

      final first = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 1,
      );
      await first.down(canvas);
      final second = await tester.createGesture(
        kind: PointerDeviceKind.touch,
        pointer: 2,
      );
      await second.down(canvas + const Offset(80, 0));
      await second.cancel();
      await first.moveBy(const Offset(40, 0));
      await first.up();
      await tester.pump(kDoubleTapTimeout);

      // Still pressed through the move, and let go once, by the first finger.
      expect(sessions.buttons, [1, 1, 0]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // Pressed outside the picture, the desktop never heard of the press, so
    // coming into the picture must not press its edge.
    testWidgets('a mouse pressed outside the picture presses nothing', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = false;
      final sessions = await pumpFramed(tester);
      final viewer = tester.getRect(find.byType(RemoteDesktopViewer));
      final picture = tester.getRect(find.byType(RawImage));
      // Beside the picture: the letterbox under it.
      final outside = Offset(viewer.center.dx, viewer.bottom - 2);
      expect(picture.contains(outside), isFalse);
      expect(picture.bottom, lessThan(outside.dy));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(outside);
      await mouse.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(sessions.buttons, isNot(contains(1)));
      await mouse.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // A mouse says what its buttons do; nothing waits and nothing is made up.
    testWidgets('a mouse click is sent as it happens, and a drag as a drag', (
      tester,
    ) async {
      RemoteDesktopViewer.debugTouchScreenOverride = true;
      final sessions = await pumpFramed(tester);
      final canvas = tester.getCenter(find.byKey(RemoteDesktopViewer.cursorKey));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(canvas);
      await mouse.up();
      await tester.pump();
      expect(sessions.buttons, [1, 0]);

      await mouse.down(canvas);
      await mouse.moveBy(const Offset(40, 0));
      // Out past the picture, and let go there.
      await mouse.moveBy(const Offset(4000, 0));
      await mouse.up();
      await tester.pump(kDoubleTapTimeout);
      expect(sessions.buttons, [1, 0, 1, 1, 1, 0]);
      // Held at the edge, not dropped.
      expect(sessions.points.last.dx, _RecordingSessions.framedSize.width - 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// The settings store in memory, for the parts of the viewer that read it.
void _useSettings() {
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });
}

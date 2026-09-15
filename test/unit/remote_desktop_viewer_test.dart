import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/view/page/remote_desktop/frame_decoder.dart';
import 'package:server_box/view/page/remote_desktop/geometry.dart';
import 'package:server_box/view/page/remote_desktop/input.dart';
import 'package:server_box/view/page/remote_desktop/viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fit transform maps and clips viewport coordinates', () {
    final transform = RemoteDesktopViewportTransform.calculate(
      viewport: const Size(1000, 700),
      desktop: const Size(800, 600),
      mode: RemoteDesktopScaleMode.fit,
    );
    expect(transform.destination.left, closeTo(33.333, 0.001));
    expect(transform.destination.width, closeTo(933.333, 0.001));
    expect(transform.destination.height, 700);
    final center = transform.toRemote(transform.destination.center)!;
    expect(center.dx, closeTo(400, 0.0001));
    expect(center.dy, closeTo(300, 0.0001));
    expect(transform.toRemote(Offset.zero), isNull);
    expect(transform.toRemote(Offset.zero, clamp: true), const Offset(0, 0));
  });

  test('RDP and VNC keys use protocol-specific codes', () {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.delete,
      logicalKey: LogicalKeyboardKey.delete,
      timeStamp: Duration.zero,
    );
    final rdp = remoteDesktopKeyFor(event, RemoteDesktopProtocol.rdp)!;
    final vnc = remoteDesktopKeyFor(event, RemoteDesktopProtocol.vnc)!;
    expect((rdp.code, rdp.extended), (0x53, true));
    expect((vnc.code, vnc.extended), (0xffff, false));
  });

  test('viewer toolbar switches to compact layout on narrow screens', () {
    expect(remoteDesktopUsesCompactToolbar(420), isTrue);
    expect(remoteDesktopUsesCompactToolbar(900), isFalse);
  });

  test('losing focus releases all remotely held keys', () {
    var releases = 0;
    final sent = <(int, bool)>[];
    final controller = RemoteDesktopInputController(
      protocol: RemoteDesktopProtocol.rdp,
      sendKey: (code, down, _) => sent.add((code, down)),
      sendText: (_) {},
      releaseRemoteKeys: () => releases++,
    );
    controller.handle(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.controlLeft,
        logicalKey: LogicalKeyboardKey.controlLeft,
        timeStamp: Duration.zero,
      ),
    );
    controller.releaseAll();
    expect(sent, [(0x1d, true)]);
    expect(releases, 1);
  });

  test('frame decoder keeps only the latest queued frame', () async {
    final first = Completer<ui.Image>();
    var calls = 0;
    Future<ui.Image> decode(
      Uint8List _,
      int width,
      int height,
      ui.PixelFormat format,
    ) {
      calls++;
      if (calls == 1) return first.future;
      return _emptyImage(width, height);
    }

    final decoder = RemoteDesktopFrameDecoder(decode: decode);
    decoder.submit(
      pixels: Uint8List(4),
      width: 1,
      height: 1,
      sequence: BigInt.one,
    );
    decoder.submit(
      pixels: Uint8List(4),
      width: 1,
      height: 1,
      sequence: BigInt.two,
    );
    decoder.submit(
      pixels: Uint8List(4),
      width: 1,
      height: 1,
      sequence: BigInt.from(3),
    );
    first.complete(await _emptyImage(1, 1));
    await pumpEventQueue(times: 10);
    expect(calls, 2);
    expect(decoder.sequence, BigInt.from(3));
    decoder.dispose();
  });
}

Future<ui.Image> _emptyImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
  return recorder.endRecording().toImage(width, height);
}

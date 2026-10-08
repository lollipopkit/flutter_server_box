// A soft keyboard shrank the canvas and the picture, fitted to the strip left
// above it, became tiny (#1639). The canvas keeps its size instead, and moves
// up only as far as it takes to keep the pointer above the keyboard.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/remote_desktop/geometry.dart';

void main() {
  // A 1000x600 canvas showing a 1000x600 desktop, fitted exactly.
  final atRest = RemoteDesktopViewportTransform.calculate(
    viewport: const Size(1000, 600),
    desktop: const Size(1000, 600),
    mode: RemoteDesktopScaleMode.fit,
  );

  double shift(Offset? pointer, {double visible = 300}) =>
      remoteDesktopKeyboardShift(
        atRest,
        visibleHeight: visible,
        pointer: pointer,
      );

  test('the scale does not change with the keyboard', () {
    expect(atRest.scale, 1);
  });

  test('a pointer already above the keyboard moves nothing', () {
    expect(shift(const Offset(500, 100)), 0);
  });

  test('a pointer under the keyboard is brought above it', () {
    // 300 visible, 48 margin: a pointer at 400 needs 148.
    expect(shift(const Offset(500, 400)), 148);
  });

  test('never further than the keyboard covers', () {
    expect(shift(const Offset(500, 599)), 300);
  });

  test('without a pointer, or without a keyboard, nothing moves', () {
    expect(shift(null), 0);
    expect(shift(const Offset(500, 599), visible: 600), 0);
  });
}

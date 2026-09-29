import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/detail/view.dart';

/// The logo on a server's page decodes no larger than its box, in
/// proportion: the URL is the user's, and a tall image bounded by its width
/// alone decoded as tall as it is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> png(int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.red,
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<(int, int)> decoded(ImageProvider provider) {
    final done = Completer<(int, int)>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        done.complete((info.image.width, info.image.height));
        stream.removeListener(listener);
      },
      onError: (e, s) => done.completeError(e, s),
    );
    stream.addListener(listener);
    return done.future;
  }

  testWidgets('a portrait logo is bounded in both dimensions', (tester) async {
    await tester.runAsync(() async {
      final bytes = await png(100, 400);
      final size = await decoded(
        serverLogoImage(
          MemoryImage(bytes),
          width: 50,
          height: 25,
          devicePixelRatio: 2,
        ),
      );
      // 100x50 device pixels at most: the height binds, the width follows.
      expect(size, (12, 50));
    });
  });

  testWidgets('a landscape logo keeps its shape too', (tester) async {
    await tester.runAsync(() async {
      final bytes = await png(400, 100);
      final size = await decoded(
        serverLogoImage(
          MemoryImage(bytes),
          width: 50,
          height: 25,
          devicePixelRatio: 2,
        ),
      );
      expect(size, (100, 25));
    });
  });
}

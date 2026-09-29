import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/view/widget/app_background.dart';

/// A theme's `background.tile` repeats its image at a fixed logical width
/// rather than stretching one copy over the window.
void main() {
  testWidgets('a tiled background repeats at the tile width', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('bg-tile-'),
    );
    addTearDown(() => dir!.deleteSync(recursive: true));
    final file = File('${dir!.path}/background.img');
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 20),
        Paint()..color = Colors.pink,
      );
      final image = await recorder.endRecording().toImage(40, 20);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });

    ThemePackages.preview.value = ThemePackage(
      installationId: '',
      id: 'test.tile',
      name: 'Tile',
      schemaMin: 3,
      schemaMax: 3,
      mode: 0,
      modes: const {ThemeMode.light},
      seed: 0xFFFF80AB,
      systemColor: false,
      paletteLight: const {},
      paletteDark: const {},
      iconStyle: IconStyle.classic,
      iconFiles: const {},
      backgroundStyle: BackgroundStyle.image,
      backgroundFile: file.path,
      backgroundTile: 64,
      opacity: 0.3,
      blur: 0,
      cardRadius: 12,
      tileRadius: 8,
      buttonRadius: 10,
      directory: dir.path,
    );
    addTearDown(() => ThemePackages.preview.value = null);

    await tester.pumpWidget(
      const MaterialApp(home: AppBackground(child: SizedBox.expand())),
    );
    // The file is read and decoded outside the fake clock.
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (tester.widget<RawImage>(find.byType(RawImage)).image != null) break;
    }

    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull);
    expect(raw.repeat, ImageRepeat.repeat);
    expect(raw.fit, BoxFit.none);
    expect(raw.alignment, Alignment.topLeft);
    expect(raw.scale, 2, reason: 'drawn at the device pixel ratio');
    // 64 logical pixels wide at 2x, the aspect ratio kept.
    expect(raw.image!.width, 128);
    expect(raw.image!.height, 64);
  });
}

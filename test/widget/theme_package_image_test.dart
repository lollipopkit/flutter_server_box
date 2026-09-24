/// What a theme package's own images look like on screen.
///
/// A package may carry either format for anything it draws and only the file
/// name says which, so the two branches are asserted separately: a stray PNG
/// drawn as a vector draws nothing at all, and a tint that misses its branch is
/// an icon in the wrong color with no error anywhere.
///
/// The splash is the other half: it covers the app for its declared duration
/// and then goes, and it is read once, so a theme chosen later does not play
/// it again.
///
/// Packages are installed in `setUp` rather than in a test body: installing
/// writes files, and a real write started inside a `testWidgets` body completes
/// on a callback that body's zone no longer pumps.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/view/widget/package_image.dart';
import 'package:server_box/view/widget/theme_splash.dart';
import 'package:toml/toml.dart';

/// What the splash itself put on screen, looked for inside the gate: a
/// `MaterialApp` has boxes and pointers of its own, so a bare `byType` answers
/// a question about the framework rather than about the splash.
Finder _inGate(Finder matching) =>
    find.descendant(of: find.byType(ThemeSplashGate), matching: matching);
final _splashBox = _inGate(find.byType(ColoredBox));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M2 2h20v20H2z" fill="currentColor"/></svg>';

  late Directory root;
  late String svgPath;
  late String pngPath;
  late ThemePackage splashTheme;
  late ThemePackage plainTheme;
  late ThemePackage firstTheme;
  late ThemePackage secondTheme;

  /// A package carrying a splash has to say it needs schema 2, or a build that
  /// reads only schema 1 installs it and plays nothing.
  Map<String, Object?> manifest(
    String id, {
    Map<String, Object?>? splash,
    int schema = 1,
  }) => {
    'format': 1,
    'schema': {'min': schema, 'max': schema},
    'id': id,
    'name': id,
    'modes': ['light', 'dark'],
    'splash': ?splash,
  };

  /// Installs [data] out of a folder, so that these exercise the path the app
  /// installs a package through rather than a hand-built object.
  Future<ThemePackage> install(
    Map<String, Object?> data, {
    Map<String, List<int>> files = const {},
  }) async {
    final source = Directory('${root.path}/src-${data['id']}')..createSync();
    await File(
      '${source.path}/manifest.toml',
    ).writeAsString(TomlDocument.fromMap(data).toString());
    for (final entry in files.entries) {
      final file = File('${source.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
    return ThemePackages.installFolder(
      source.path,
      rootDirectory: '${root.path}/installed',
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('theme-widget-');
    svgPath = '${root.path}/icon.svg';
    pngPath = '${root.path}/icon.png';
    await File(svgPath).writeAsString(svg, flush: true);
    final png = await pngBytes();
    await File(pngPath).writeAsBytes(png, flush: true);
    splashTheme = await install(
      manifest(
        'example.splash',
        schema: 2,
        splash: {
          'color': 0xff102030,
          'logo': 'splash_logo.png',
          'duration': 300,
        },
      ),
      files: {'splash_logo.png': png},
    );
    plainTheme = await install(manifest('example.plain'));
    firstTheme = await install(
      manifest('example.first', schema: 2, splash: {'color': 0xff102030}),
    );
    secondTheme = await install(
      manifest('example.second', schema: 2, splash: {'color': 0xffaabbcc}),
    );
  });

  tearDown(() async {
    ThemePackages.preview.value = null;
    await root.delete(recursive: true);
  });

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('an SVG is drawn as a vector and tinted with the given color', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(PackageImage(path: svgPath, size: 24, color: Colors.red)),
    );
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.width, 24);
    expect(picture.height, 24);
    expect(
      picture.colorFilter,
      const ColorFilter.mode(Colors.red, BlendMode.srcIn),
    );
    expect(
      (picture.bytesLoader as SvgFileLoader).theme?.currentColor,
      Colors.red,
    );
  });

  testWidgets('a PNG keeps the raster path and is tinted the same way', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(PackageImage(path: pngPath, size: 24, color: Colors.red)),
    );
    expect(find.byType(SvgPicture), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 24);
    expect(image.color, Colors.red);
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('an SVG with no color still follows the ambient foreground', (
    tester,
  ) async {
    await tester.pumpWidget(app(PackageImage(path: svgPath, size: 24)));
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(picture.colorFilter, isNull);
    expect(
      (picture.bytesLoader as SvgFileLoader).theme?.currentColor,
      isNotNull,
    );
  });

  testWidgets('a missing file draws the fallback instead of an empty box', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PackageImage(
          path: '${root.path}/gone.svg',
          fallback: const Icon(Icons.abc),
        ),
      ),
    );
    expect(find.byIcon(Icons.abc), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('a splash covers the app for its duration and then goes', (
    tester,
  ) async {
    ThemePackages.preview.value = splashTheme;
    await tester.pumpWidget(app(const ThemeSplashGate(child: Text('the app'))));
    expect(find.byType(PackageImage), findsOneWidget);
    // The splash is over the app, not instead of it.
    expect(find.text('the app'), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(_splashBox).color,
      const Color(0xff102030),
    );

    // The declared duration, a fade of its own, and the rebuild that follows.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(ThemeSplashGate.fadeDuration);
    await tester.pump(ThemeSplashGate.fadeDuration);
    await tester.pump();
    expect(find.byType(PackageImage), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a package without a splash adds nothing to the tree', (
    tester,
  ) async {
    ThemePackages.preview.value = plainTheme;
    await tester.pumpWidget(app(const ThemeSplashGate(child: Text('the app'))));
    expect(find.text('the app'), findsOneWidget);
    expect(_inGate(find.byType(AbsorbPointer)), findsNothing);
  });

  testWidgets('the splash is the one the launch had, not the one picked next', (
    tester,
  ) async {
    ThemePackages.preview.value = firstTheme;
    await tester.pumpWidget(app(const ThemeSplashGate(child: Text('the app'))));

    // Choosing another theme while the splash is up does not swap it: the
    // reading is the one the launch was under.
    ThemePackages.preview.value = secondTheme;
    await tester.pump();
    expect(
      tester.widget<ColoredBox>(_splashBox).color,
      const Color(0xff102030),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(ThemeSplashGate.fadeDuration);
    await tester.pump(ThemeSplashGate.fadeDuration);
    await tester.pump();
    expect(_inGate(find.byType(AbsorbPointer)), findsNothing);
  });
}

Future<Uint8List> pngBytes() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = Colors.pink,
  );
  final image = await recorder.endRecording().toImage(4, 4);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  return bytes;
}

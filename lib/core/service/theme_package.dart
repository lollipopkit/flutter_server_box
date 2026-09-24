import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Brightness, Color, ColorScheme, ThemeMode;
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;
import 'package:server_box/core/service/theme_components.dart';
import 'package:server_box/core/service/theme_palette.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/data/res/store.dart';
import 'package:toml/toml.dart';
import 'package:xml/xml.dart' as xml;

/// The splash a package asks for: a background color, an optional logo beside
/// the manifest, and how long the app stays behind it before fading out.
final class ThemeSplash {
  const ThemeSplash({
    required this.color,
    required this.duration,
    this.logo,
  });

  static const defaultDuration = 600;
  static const minDuration = 100;
  static const maxDuration = 3000;

  /// An ARGB integer or a [ThemePalette] role name, resolved per brightness.
  final Object color;

  /// The logo's file name in the package root, or null for a plain color.
  final String? logo;

  /// Milliseconds the splash stays up. It covers the app's first frames, so
  /// what it delays is the launch, which is why the ceiling is low.
  final int duration;

  Color resolve(ColorScheme scheme) =>
      ThemePalette.spec(color, scheme) ?? scheme.surface;
}

/// Where a package's icon files live: the directory once installed, and the
/// prefix of their path inside an archive. One spelling for both, since a path
/// in the archive is read back as a path on disk. The manifest table of the
/// same name is a schema key and stays spelled out with the rest of them.
const _iconsDir = 'icons';

/// A versioned .fsbt resource bundle. Fonts and launcher icons are separate.
final class ThemePackage {
  const ThemePackage({
    required this.installationId,
    required this.id,
    required this.name,
    required this.schemaMin,
    required this.schemaMax,
    required this.mode,
    required this.modes,
    required this.seed,
    required this.systemColor,
    required this.paletteLight,
    required this.paletteDark,
    required this.iconStyle,
    required this.iconFiles,
    required this.backgroundStyle,
    required this.opacity,
    required this.blur,
    required this.cardRadius,
    required this.tileRadius,
    required this.buttonRadius,
    required this.directory,
    this.iconColors = const {},
    this.splash,
    this.backgroundFile,
    this.components = const ThemeComponents.empty(),
  });

  final String installationId;
  final String id;
  final String name;
  final int schemaMin;
  final int schemaMax;
  final int mode;
  final Set<ThemeMode> modes;

  ThemeMode? get lockedMode => modes.length == 1 ? modes.single : null;

  ThemeMode resolveMode(int preference) =>
      lockedMode ??
      (preference >= 0 && preference < ThemeMode.values.length
          ? ThemeMode.values[preference]
          : ThemeMode.system);
  final int seed;
  final bool systemColor;
  final Map<String, int> paletteLight;
  final Map<String, int> paletteDark;
  final IconStyle iconStyle;

  /// Icon key to the file that carries it, inside `icons/`. The extension is
  /// part of the value because the file decides how it is drawn: a PNG is
  /// decoded by the engine, an SVG by `flutter_svg`.
  final Map<String, String> iconFiles;

  /// Icon key to an ARGB integer or a [ThemePalette] role name. A key without
  /// one follows the ambient icon color, which is what an icon did before a
  /// package could say otherwise.
  final Map<String, Object> iconColors;
  final BackgroundStyle backgroundStyle;
  final double opacity;
  final double blur;
  final double cardRadius;
  final double tileRadius;
  final double buttonRadius;
  final String directory;
  final ThemeSplash? splash;
  final String? backgroundFile;
  final ThemeComponents components;

  String? get backgroundPath =>
      backgroundStyle == BackgroundStyle.image
      ? backgroundFile ?? directory.joinPath('background.img')
      : null;

  /// The splash logo, which sits beside the manifest rather than under any
  /// directory of its own — there is only ever one.
  String? get splashLogoPath => switch (splash?.logo) {
    final String logo => directory.joinPath(logo),
    _ => null,
  };

  String? iconPath(String key) => switch (iconFiles[key]) {
    final String file => directory.joinPath(_iconsDir).joinPath(file),
    _ => null,
  };

  Color? iconColor(String key, ColorScheme scheme) =>
      ThemePalette.spec(iconColors[key], scheme);
}

/// Loads one bundled folder on demand and shares concurrent requests.
final class BuiltinThemeLoader {
  BuiltinThemeLoader({AssetBundle? bundle, this.rootDirectory})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String? rootDirectory;
  final _loaded = <BuiltinTheme, ThemePackage>{};
  final _pending = <BuiltinTheme, Future<ThemePackage>>{};

  ThemePackage? loaded(BuiltinTheme theme) => theme == BuiltinTheme.defaultTheme
      ? ThemePackages.defaultTheme
      : _loaded[theme];

  Future<ThemePackage> load(BuiltinTheme theme) async {
    final cached = loaded(theme);
    if (cached != null) return cached;
    final pending = _pending[theme];
    if (pending != null) return pending;
    final future = _loadFolder(theme);
    _pending[theme] = future;
    try {
      final package = await future;
      _loaded[theme] = package;
      return package;
    } finally {
      _pending.remove(theme);
    }
  }

  Future<ThemePackage> _loadFolder(BuiltinTheme builtin) async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final prefix = 'assets/themes/${builtin.id}/';
    final assets = <String, Uint8List>{};
    for (final asset in manifest.listAssets().where(
      (path) => path.startsWith(prefix),
    )) {
      final bytes = await _bundle.load(asset);
      assets[asset.substring(prefix.length)] = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    }
    final data = ThemePackages._decodeManifest(
      utf8.decode(assets['manifest.toml'] ?? Uint8List(0)),
    );
    if (data['id'] != builtin.id || data['name'] != builtin.label) {
      throw const FormatException('Built-in theme metadata mismatch');
    }
    return ThemePackages.installAssets(
      assets,
      rootDirectory: rootDirectory ?? ThemePackages.root.joinPath('builtin'),
    );
  }
}

abstract final class ThemePackages {
  /// Temporary appearance only; preview never writes settings.
  static final preview = ValueNotifier<ThemePackage?>(null);

  static const supportedSchemaMin = 1;
  static const supportedSchemaMax = 2;

  /// What schema 2 added: SVG icons, per-icon colors, and [ThemeSplash]. A
  /// package that uses one of them has to say it needs 2, because a build that
  /// reads only schema 1 installs the same bytes and then drops the feature
  /// without saying so.
  static const featureSchema = 2;
  static String get supportedSchemaRange =>
      'v$supportedSchemaMin–v$supportedSchemaMax';

  static const maxPackageBytes = 16 * 1024 * 1024;
  static const _maxBackgroundBytes = 8 * 1024 * 1024;
  static const _maxSplashLogoBytes = 512 * 1024;
  static const _maxIconBytes = 256 * 1024;
  static const _maxManifestBytes = 64 * 1024;
  static const _maxIcons = 48;
  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');

  /// Every top-level table a package may carry. One that is not here is refused
  /// rather than ignored, because an ignored one is a theme that silently does
  /// not do what its author wrote — a mistyped `[splas]` costs nothing to
  /// report and is invisible otherwise.
  @visibleForTesting
  static const sections = {
    'format',
    'schema',
    'id',
    'name',
    'modes',
    'colors',
    'icons',
    'background',
    'shapes',
    'components',
    'splash',
  };
  /// The fields `[icons]` and `[splash]` may carry, held against the schema's
  /// properties by the same test that holds the enums above.
  static const iconFields = {'style', 'images', 'colors'};
  static const splashFields = {'color', 'logo', 'duration'};

  /// What the format allows where a value is one of a few, which
  /// `docs/schemas/fsbt-manifest.schema.json` enumerates for editors as well:
  /// `test/unit/theme_schema_test.dart` holds the two lists equal, so a value
  /// added here and not there is an author writing what the schema offers and
  /// this build refusing it.
  ///
  /// Each is the enum's own `name`, which is the spelling a manifest carries,
  /// so the set cannot drift from the type the value is read into.
  static final modes = {
    for (final mode in _declaredModes) mode.name,
  };
  static final iconStyles = {
    for (final style in IconStyle.values) style.name,
  };
  static final backgroundStyles = {
    for (final style in BackgroundStyle.values) style.name,
  };

  /// The modes a package may declare. Absent `system` on purpose: a package
  /// either works in a brightness or refuses to carry it.
  static const _declaredModes = {ThemeMode.light, ThemeMode.dark};

  /// The one file name a background image may have, at the archive root.
  static const backgroundImages = {
    'background.png',
    'background.jpg',
    'background.jpeg',
  };

  /// The longest `name` a package may carry.
  static const maxNameLength = 80;

  /// The largest image opacity and blur radius. Stated in the schema too, and
  /// held equal by the same test. The splash's own range is on [ThemeSplash].
  static const maxBackgroundOpacity = 0.6;
  static const maxBackgroundBlur = 30.0;

  /// The one logo a splash may name, kept here so the test that holds this
  /// list and the schema's together can read it.
  @visibleForTesting
  static const splashLogos = {
    'splash_logo.png',
    'splash_logo.jpg',
    'splash_logo.jpeg',
    'splash_logo.svg',
  };

  /// What a theme's id may be, and therefore what a repository file for one may
  /// be called: a repository names the theme its file describes, so the two are
  /// one spelling and one pattern — see [ThemeRepoLayout.pathOf].
  static final idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
  static String? _activeId;
  static ThemePackage? _active;
  static const defaultTheme = ThemePackage(
    installationId: '',
    id: 'default',
    name: 'Default',
    schemaMin: 1,
    schemaMax: 1,
    mode: 0,
    modes: {ThemeMode.light, ThemeMode.dark},
    seed: 0xFF880E4F,
    systemColor: false,
    paletteLight: {},
    paletteDark: {},
    iconStyle: IconStyle.classic,
    iconFiles: {},
    backgroundStyle: BackgroundStyle.none,
    opacity: 0.18,
    blur: 0,
    cardRadius: 13,
    tileRadius: 9,
    buttonRadius: 30,
    directory: '',
  );
  static final _builtinLoader = BuiltinThemeLoader();

  static Future<ThemePackage> loadBuiltin(BuiltinTheme theme) =>
      _builtinLoader.load(theme);

  static Future<void> prepareSelectedTheme() async {
    // TODO: Remove the development preset rename after existing installs update.
    if (Stores.setting.appThemePreset.fetch() == 'classic') {
      Stores.setting.appThemePreset.put(BuiltinTheme.defaultTheme.id);
    }
    try {
      // TODO: Remove migration after legacy AMOLED mode settings age out.
      final legacyMode = Stores.setting.themeMode.fetch();
      if (legacyMode == 3 || legacyMode == 4) {
        select(
          await loadBuiltin(BuiltinTheme.amoled),
          preset: BuiltinTheme.amoled.id,
        );
        Stores.setting.themeMode.put(
          legacyMode == 3 ? ThemeMode.dark.index : ThemeMode.system.index,
        );
      }
      final preset = BuiltinTheme.fromId(Stores.setting.appThemePreset.fetch());
      if (preset == null) return;
      await loadBuiltin(preset);
    } catch (error, stack) {
      Loggers.app.warning(
        'Could not load selected built-in theme',
        error,
        stack,
      );
      _selectDefaultFallback();
    }
  }

  /// The icon keys a package may carry an image or a color for, and what the
  /// schema's `icons.images` and `icons.colors` offer as keys.
  ///
  /// Both halves come from their type: a tab's from [AppTab], a shared symbol's
  /// from [ThemeNavIcon]. Written out as names, a tab added to the bar or a
  /// symbol added to the themed icon set would be a key this refuses, which
  /// reads as a package documenting something the app does not draw.
  @visibleForTesting
  static final iconKeys = <String>{
    for (final tab in AppTab.values) ...[
      tabIconKey(tab, selected: false),
      tabIconKey(tab, selected: true),
    ],
    for (final icon in ThemeNavIcon.values) icon.iconKey,
  };

  static String get root => Paths.doc.joinPath('themes');

  static Uri httpsUri(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Use an HTTPS URL without credentials');
    }
    return uri;
  }

  static Future<Uint8List> download(
    String url, {
    int maxBytes = maxPackageBytes,
  }) async {
    var uri = httpsUri(url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var redirect = 0; redirect < 4; redirect++) {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw const FormatException('Missing redirect URL');
          }
          uri = httpsUri(uri.resolve(location).toString());
          await response.drain<void>();
          continue;
        }
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }
        if (response.contentLength > maxBytes) {
          throw const FormatException('Download exceeds size limit');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const FormatException('Download exceeds size limit');
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }
      throw const FormatException('Too many redirects');
    } finally {
      client.close(force: true);
    }
  }

  static Future<ThemePackage> installUrl(
    String url, {
    String? expectedSha256,
  }) async {
    final bytes = await download(url);
    if (expectedSha256 != null &&
        sha256.convert(bytes).toString() != expectedSha256) {
      throw const FormatException('Theme checksum mismatch');
    }
    return install(bytes);
  }

  static Future<ThemePackage> install(
    List<int> bytes, {
    String? rootDirectory,
  }) async {
    if (bytes.isEmpty || bytes.length > maxPackageBytes) {
      throw const FormatException('Invalid theme package size');
    }
    final assets = _readArchive(bytes);
    return _installAssets(
      assets,
      installationId: sha256.convert(bytes).toString(),
      rootDirectory: rootDirectory,
    );
  }

  /// Imports a development directory without requiring a ZIP build step.
  static Future<ThemePackage> installFolder(
    String folderPath, {
    String? rootDirectory,
  }) async {
    if (await FileSystemEntity.type(folderPath, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Invalid theme folder');
    }
    final assets = <String, Uint8List>{};
    var total = 0;
    Future<void> readFile(File file, String path, int maxBytes) async {
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const FormatException('Invalid theme asset');
      }
      final size = await file.length();
      if (size <= 0 || size > maxBytes || total + size > maxPackageBytes) {
        throw const FormatException('Theme asset exceeds size limit');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length != size) {
        throw const FormatException('Theme asset changed during import');
      }
      assets[path] = bytes;
      total += bytes.length;
    }

    final folder = Directory(folderPath);
    await readFile(
      File(folder.path.joinPath('manifest.toml')),
      'manifest.toml',
      _maxManifestBytes,
    );
    await for (final entry in folder.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (name == 'manifest.toml') continue;
      if (name == _iconsDir) {
        if (entry is! Directory) {
          throw const FormatException('Invalid icons directory');
        }
        await for (final icon in entry.list(followLinks: false)) {
          final iconName = icon.uri.pathSegments
              .where((part) => part.isNotEmpty)
              .last;
          if (!iconName.endsWith('.png') && !iconName.endsWith('.svg')) {
            continue;
          }
          if (icon is! File) {
            throw const FormatException('Invalid theme icon');
          }
          await readFile(icon, '$_iconsDir/$iconName', _maxIconBytes);
          if (assets.length > _maxIcons + 2) {
            throw const FormatException('Too many theme assets');
          }
        }
      } else if (backgroundImages.contains(name)) {
        if (entry is! File) {
          throw const FormatException('Invalid theme background');
        }
        await readFile(entry, name, _maxBackgroundBytes);
      } else if (splashLogos.contains(name)) {
        if (entry is! File) {
          throw const FormatException('Invalid splash logo');
        }
        await readFile(entry, name, _maxSplashLogoBytes);
      }
    }
    return installAssets(assets, rootDirectory: rootDirectory);
  }

  /// Installs uncompressed assets from a local folder or the Flutter bundle.
  static Future<ThemePackage> installAssets(
    Map<String, Uint8List> assets, {
    String? rootDirectory,
  }) async {
    final manifest = assets['manifest.toml'];
    if (manifest == null ||
        manifest.isEmpty ||
        manifest.length > _maxManifestBytes ||
        assets.length > _maxIcons + 3 ||
        assets.values.fold<int>(0, (sum, bytes) => sum + bytes.length) >
            maxPackageBytes) {
      throw const FormatException('Invalid theme assets');
    }
    final digestInput = BytesBuilder(copy: false);
    for (final path in assets.keys.toList()..sort()) {
      final name = utf8.encode(path);
      final content = assets[path]!;
      final nameLength = ByteData(4)..setUint32(0, name.length);
      final contentLength = ByteData(4)..setUint32(0, content.length);
      digestInput
        ..add(nameLength.buffer.asUint8List())
        ..add(name)
        ..add(contentLength.buffer.asUint8List())
        ..add(content);
    }
    return _installAssets(
      assets,
      installationId: sha256.convert(digestInput.takeBytes()).toString(),
      rootDirectory: rootDirectory,
    );
  }

  static Future<ThemePackage> _installAssets(
    Map<String, Uint8List> assets, {
    required String installationId,
    String? rootDirectory,
  }) async {
    final data = _decodeManifest(utf8.decode(assets['manifest.toml']!));
    if (data['format'] != 1 ||
        data.containsKey('appIcon') ||
        data.containsKey('font')) {
      throw const FormatException('Unsupported theme package');
    }
    if (!data.keys.every(sections.contains)) {
      throw const FormatException('Unknown theme section');
    }
    final (schemaMin, schemaMax) = _schemaRange(data['schema']);
    final id = data['id'];
    if (id is! String || !idPattern.hasMatch(id)) {
      throw const FormatException('Invalid theme id');
    }
    final name = _label(data['name'], 'name');
    final colors = _map(data['colors'], 'colors');
    final mode = _integer(colors['mode'], 0, 2);
    final modes = _themeModes(data['modes']);
    final seed = _integer(colors['seed'], 0, 0xffffffff);
    final systemColor = colors['systemColor'];
    if (systemColor is! bool) throw const FormatException('Invalid color mode');
    final palette = colors['palette'] == null
        ? <String, dynamic>{}
        : _map(colors['palette'], 'palette');
    if (palette.keys.any((key) => brightnessByName(key) == null)) {
      throw const FormatException('Invalid palette brightness');
    }
    final paletteLight = _palette(palette[Brightness.light.name]);
    final paletteDark = _palette(palette[Brightness.dark.name]);
    final components = ThemeComponents.parse(data['components']);
    final icons = _map(data['icons'], 'icons');
    if (!icons.keys.every(iconFields.contains)) {
      throw const FormatException('Unknown icon field');
    }
    final style = IconStyle.parse(icons['style']);
    if (style == null) throw const FormatException('Invalid icon style');
    final imageMap = icons['images'] == null
        ? <String, dynamic>{}
        : _map(icons['images'], 'icon images');
    if (imageMap.length > _maxIcons ||
        !imageMap.keys.every(iconKeys.contains)) {
      throw const FormatException('Invalid icon keys');
    }
    final iconColors = _iconColors(
      icons['colors'] == null
          ? <String, dynamic>{}
          : _map(icons['colors'], 'icon colors'),
      imageMap.keys,
    );
    final splash = _splash(data['splash']);
    final background = _map(data['background'], 'background');
    final backgroundStyle = BackgroundStyle.parse(background['type']);
    if (backgroundStyle == null) {
      throw const FormatException('Invalid background type');
    }
    final opacity = _fraction(background['opacity'], maxBackgroundOpacity);
    final blur = _fraction(background['blur'], maxBackgroundBlur);
    final shapes = _map(data['shapes'], 'shapes');
    final card = _fraction(shapes['card'], ThemeComponents.maxRadius);
    final tile = _fraction(shapes['tile'], ThemeComponents.maxRadius);
    final button = _fraction(shapes['button'], ThemeComponents.maxRadius);

    final usedAssets = <String>{'manifest.toml'};
    Uint8List? backgroundBytes;
    if (backgroundStyle == BackgroundStyle.image) {
      final path = background['image'];
      if (!backgroundImages.contains(path)) {
        throw const FormatException('Invalid background path');
      }
      usedAssets.add(path as String);
      backgroundBytes = _imageAsset(assets, path, _maxBackgroundBytes);
      await _verifyImage(
        backgroundBytes,
        maxDimension: 8192,
        maxPixels: 64 * 1024 * 1024,
      );
    } else if (background.containsKey('image')) {
      throw const FormatException('Unexpected background image');
    }
    final iconFiles = <String, String>{};
    final iconBytes = <String, Uint8List>{};
    for (final entry in imageMap.entries) {
      final path = _iconAssetPath(entry.key, entry.value);
      final name = path.substring('$_iconsDir/'.length);
      usedAssets.add(path);
      iconBytes[name] = path.endsWith('.svg')
          ? _svgAsset(assets, path, _maxIconBytes)
          : await _iconPng(assets, path, _maxIconBytes);
      iconFiles[entry.key] = name;
    }
    Uint8List? splashLogoBytes;
    if (splash?.logo case final logo?) {
      usedAssets.add(logo);
      if (logo.endsWith('.svg')) {
        splashLogoBytes = _svgAsset(assets, logo, _maxSplashLogoBytes);
      } else {
        splashLogoBytes = _imageAsset(assets, logo, _maxSplashLogoBytes);
        await _verifyImage(
          splashLogoBytes,
          maxDimension: 2048,
          maxPixels: 2048 * 2048,
        );
      }
    }
    if (assets.keys.any(
      (path) => path != '$_iconsDir/' && !usedAssets.contains(path),
    )) {
      throw const FormatException('Unexpected theme asset');
    }
    _requireFeatureSchema(
      min: schemaMin,
      iconFiles: iconFiles.values,
      iconColors: iconColors,
      splash: splash,
    );

    final rootPath = rootDirectory ?? root;
    final directory = rootPath.joinPath(installationId);
    final existing = installed(installationId, rootDirectory: rootPath);
    if (existing != null) return existing;
    await Directory(rootPath).create(recursive: true);
    final staging = Directory(
      rootPath.joinPath('.installing-${DateTime.now().microsecondsSinceEpoch}'),
    );
    await staging.create();
    try {
      if (backgroundBytes != null) {
        await File(
          staging.path.joinPath('background.img'),
        ).writeAsBytes(backgroundBytes, flush: true);
      }
      if (iconBytes.isNotEmpty) {
        final iconDir = Directory(staging.path.joinPath(_iconsDir));
        await iconDir.create();
        for (final entry in iconBytes.entries) {
          await File(
            iconDir.path.joinPath(entry.key),
          ).writeAsBytes(entry.value, flush: true);
        }
      }
      if (splashLogoBytes != null) {
        await File(
          staging.path.joinPath(splash!.logo!),
        ).writeAsBytes(splashLogoBytes, flush: true);
      }
      final profile = {
        'format': 1,
        'schema': {'min': schemaMin, 'max': schemaMax},
        'id': id,
        'name': name,
        'modes': modes.map((mode) => mode.name).toList(),
        'components': components.toMap(),
        'colors': {
          'mode': mode,
          'seed': seed,
          'systemColor': systemColor,
          'palette': {
            Brightness.light.name: paletteLight,
            Brightness.dark.name: paletteDark,
          },
        },
        'icons': {
          'style': style.name,
          'images': iconFiles.keys.toList(),
          if (iconColors.isNotEmpty) 'colors': iconColors,
        },
        'background': {
          'type': backgroundStyle.name,
          'opacity': opacity,
          'blur': blur,
        },
        'shapes': {'card': card, 'tile': tile, 'button': button},
        if (splash != null)
          'splash': {
            'color': splash.color,
            'duration': splash.duration,
            if (splash.logo != null) 'logo': splash.logo,
          },
      };
      final normalized = TomlDocument.fromMap(profile).toString();
      if (utf8.encode(normalized).length > _maxManifestBytes) {
        throw const FormatException('Normalized manifest exceeds size limit');
      }
      await File(
        staging.path.joinPath('manifest.toml'),
      ).writeAsString(normalized, flush: true);
      if (await Directory(directory).exists()) {
        await Directory(directory).delete(recursive: true);
      }
      await staging.rename(directory);
      _activeId = null;
      return installed(installationId, rootDirectory: rootPath)!;
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  /// The preset value that selects one installed theme.
  static String presetOf(String installationId) =>
      '$_packagePrefix$installationId';

  /// The installation id a preset names, or null when it names something else —
  /// a builtin theme, or the custom one.
  ///
  /// The one place the prefix is known. Written out at each call site instead,
  /// a length that stops matching the prefix turns into a preset that names no
  /// install, which reads as "not installed": the user's theme is reset rather
  /// than reported.
  static String? installationIdOf(String preset) =>
      preset.startsWith(_packagePrefix)
      ? preset.substring(_packagePrefix.length)
      : null;

  static const _packagePrefix = 'package:';

  /// The preset naming the theme this app's own appearance settings make up.
  ///
  /// It is not a package, so it has no installation id and no directory, and it
  /// is the value `appThemePreset` held before packages existed — which is why
  /// the spelling is this one. Every comparison against it goes through the
  /// constant: a literal that stops matching the written value reads as "not
  /// the custom theme", and the settings a user arranged would be replaced
  /// without anything reporting it.
  static const customPreset = 'custom';

  /// One installed theme by **installation id** — the digest of the package
  /// bytes, which is also its directory name.
  ///
  /// Not the `id` its manifest declares: that names the theme across versions
  /// and releases, and it is not the digest this looks up, so passing one here
  /// answers null without saying why. [ThemePackage.installationId] is the one
  /// to hand over; see [ThemePackage.id] for the other.
  static ThemePackage? installed(String installationId, {String? rootDirectory}) {
    if (!_digestPattern.hasMatch(installationId)) return null;
    final directory = (rootDirectory ?? root).joinPath(installationId);
    try {
      final file = File(directory.joinPath('manifest.toml'));
      if (!file.existsSync() || file.lengthSync() > _maxManifestBytes) {
        return null;
      }
      final data = _decodeManifest(file.readAsStringSync());
      if (data['format'] != 1) return null;
      final (schemaMin, schemaMax) = _schemaRange(data['schema']);
      final themeId = data['id'];
      if (themeId is! String || !idPattern.hasMatch(themeId)) return null;
      final colors = _map(data['colors'], 'colors');
      final palette = colors['palette'] == null
          ? <String, dynamic>{}
          : _map(colors['palette'], 'palette');
      final icons = _map(data['icons'], 'icons');
      final background = _map(data['background'], 'background');
      final shapes = _map(data['shapes'], 'shapes');
      final carried = (icons['images'] as List).cast<String>();
      if (!carried.every(iconKeys.contains)) return null;
      final style = IconStyle.parse(icons['style']);
      final bgStyle = BackgroundStyle.parse(background['type']);
      if (style == null || bgStyle == null) return null;
      // The manifest names keys and not files, so which format each icon is in
      // is a question for the directory. Both are asked for, in the order a
      // package would have been written either way.
      final iconDir = directory.joinPath(_iconsDir);
      final iconFiles = <String, String>{};
      for (final key in carried) {
        final stem = key.replaceAll('.', '_');
        final svg = '$stem.svg';
        final png = '$stem.png';
        if (File(iconDir.joinPath(svg)).existsSync()) {
          iconFiles[key] = svg;
        } else if (File(iconDir.joinPath(png)).existsSync()) {
          iconFiles[key] = png;
        } else {
          return null;
        }
      }
      final iconColors = _iconColors(
        icons['colors'] == null
            ? <String, dynamic>{}
            : _map(icons['colors'], 'icon colors'),
        iconFiles.keys,
      );
      final splash = _splash(data['splash']);
      _requireFeatureSchema(
        min: schemaMin,
        iconFiles: iconFiles.values,
        iconColors: iconColors,
        splash: splash,
      );
      final package = ThemePackage(
        installationId: installationId,
        id: themeId,
        name: _label(data['name'], 'name'),
        schemaMin: schemaMin,
        schemaMax: schemaMax,
        mode: _integer(colors['mode'], 0, 2),
        modes: _themeModes(data['modes']),
        seed: _integer(colors['seed'], 0, 0xffffffff),
        systemColor: colors['systemColor'] as bool,
        paletteLight: _palette(palette[Brightness.light.name]),
        paletteDark: _palette(palette[Brightness.dark.name]),
        components: ThemeComponents.parse(data['components']),
        iconStyle: style,
        iconFiles: iconFiles,
        iconColors: iconColors,
        backgroundStyle: bgStyle,
        opacity: _fraction(background['opacity'], maxBackgroundOpacity),
        blur: _fraction(background['blur'], maxBackgroundBlur),
        cardRadius: _fraction(shapes['card'], ThemeComponents.maxRadius),
        tileRadius: _fraction(shapes['tile'], ThemeComponents.maxRadius),
        buttonRadius: _fraction(shapes['button'], ThemeComponents.maxRadius),
        directory: directory,
        splash: splash,
      );
      if (package.backgroundPath case final path?
          when !File(path).existsSync()) {
        return null;
      }
      if (package.splashLogoPath case final logo? when !File(logo).existsSync()) {
        return null;
      }
      return package;
    } catch (_) {
      return null;
    }
  }

  static List<ThemePackage> listInstalled({String? rootDirectory}) {
    final directory = Directory(rootDirectory ?? root);
    if (!directory.existsSync()) return [];
    final themes = <ThemePackage>[];
    for (final entry in directory.listSync(followLinks: false)) {
      if (entry is! Directory) continue;
      final installationId = entry.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      final theme = installed(installationId, rootDirectory: directory.path);
      if (theme != null) themes.add(theme);
    }
    themes.sort((a, b) => a.name.compareTo(b.name));
    return themes;
  }

  static Map<String, String> installedPresetNames({String? rootDirectory}) => {
    for (final theme in listInstalled(rootDirectory: rootDirectory))
      presetOf(theme.installationId): theme.name,
  };

  /// Deletes one installed theme, answering whether it was there.
  ///
  /// **Safe to call on the theme in use**, which is the only thing that makes a
  /// remove button worth having: deleting it would otherwise leave the app on a
  /// preset whose assets are gone, and [activeTheme] answering null is not a
  /// state anything else in the app draws. The selection is reconciled here
  /// rather than at the next launch, so what a caller can observe afterwards is
  /// a theme that exists.
  ///
  /// Nothing is refused for being in use — a user who wants it gone wants it
  /// gone, and the answer is the default theme, not a dialog that will not
  /// close.
  static Future<bool> remove(
    String installationId, {
    String? rootDirectory,
  }) async {
    if (!_digestPattern.hasMatch(installationId)) return false;
    final directory = Directory(
      (rootDirectory ?? root).joinPath(installationId),
    );
    if (!await directory.exists()) return false;
    await directory.delete(recursive: true);

    if (_activeId == installationId) {
      _activeId = null;
      _active = null;
    }
    reconcileSelection();
    return true;
  }

  static String? activeIconPath(String key) {
    if (!iconKeys.contains(key)) return null;
    return activeTheme?.iconPath(key);
  }

  /// The color a package gives this icon, or `null` to follow the ambient one.
  static Color? activeIconColor(String key, ColorScheme scheme) =>
      iconKeys.contains(key) ? activeTheme?.iconColor(key, scheme) : null;

  static ThemePackage? get activeTheme {
    if (preview.value case final theme?) return theme;
    final preset = BuiltinTheme.fromId(Stores.setting.appThemePreset.fetch());
    if (preset != null) return _builtinLoader.loaded(preset);
    final installationId = Stores.setting.appThemePackage.fetch();
    if (_activeId != installationId) {
      _activeId = installationId;
      _active = installed(installationId);
    }
    return _active;
  }

  static ThemeMode get effectiveMode =>
      preview.value?.resolveMode(preview.value!.mode) ??
      activeTheme?.resolveMode(Stores.setting.themeMode.fetch()) ??
      defaultTheme.resolveMode(Stores.setting.themeMode.fetch());

  static Map<String, int> activePalette({required bool dark}) {
    final theme = activeTheme;
    return dark
        ? (theme?.paletteDark ?? const {})
        : (theme?.paletteLight ?? const {});
  }

  static ColorScheme applyPalette(ColorScheme base, Map<String, int> palette) =>
      ThemePalette.apply(base, palette);

  static void select(ThemePackage theme, {required String preset}) {
    final settings = Stores.setting;
    settings.themeMode.put(theme.resolveMode(theme.mode).index);
    settings.colorSeed.put(theme.seed);
    settings.useSystemPrimaryColor.put(theme.systemColor);
    settings.appIconStyle.put(theme.iconStyle);
    settings.appThemePackage.put(installationIdOf(preset) ?? '');
    settings.appThemePaletteEnabled.put(true);
    settings.appBackgroundStyle.put(theme.backgroundStyle);
    settings.appBackgroundPath.put(theme.backgroundPath ?? '');
    settings.appBackgroundOpacity.put(theme.opacity);
    settings.appBackgroundBlur.put(theme.blur);
    settings.appCardRadius.put(theme.cardRadius);
    settings.appTileRadius.put(theme.tileRadius);
    settings.appButtonRadius.put(theme.buttonRadius);
    settings.appThemePreset.put(preset);
  }

  /// Selects a package, keeping the custom theme it is about to replace.
  ///
  /// The one entry point for "the app switches to this theme", so that every
  /// way in — the preset sheet, the store, an import — leaves the same state
  /// behind. [select] alone overwrites every setting a custom theme is made of,
  /// so the snapshot has to come first.
  static void apply(ThemePackage theme, {String? preset}) {
    if (Stores.setting.appThemePreset.fetch() == customPreset) {
      saveCustomTheme();
    }
    select(theme, preset: preset ?? presetOf(theme.installationId));
  }

  /// Writes the settings a custom theme is made of.
  ///
  /// Read back by the settings page's own reader, which rebuilds the package
  /// from exactly these keys, so the two are one shape in two places and have
  /// to be changed together.
  static void saveCustomTheme() {
    final settings = Stores.setting;
    settings.appCustomBackgroundPath.put(settings.appBackgroundPath.fetch());
    settings.appCustomTheme.put(
      jsonEncode({
        'mode': settings.themeMode.fetch(),
        'seed': settings.colorSeed.fetch(),
        'systemColor': settings.useSystemPrimaryColor.fetch(),
        'icons': settings.appIconStyle.fetch().name,
        'opacity': settings.appBackgroundOpacity.fetch(),
        'blur': settings.appBackgroundBlur.fetch(),
        'card': settings.appCardRadius.fetch(),
        'tile': settings.appTileRadius.fetch(),
        'button': settings.appButtonRadius.fetch(),
      }),
    );
  }

  static void reconcileSelection() {
    final preset = Stores.setting.appThemePreset.fetch();
    if (installationIdOf(preset) case final installationId?
        when installed(installationId) == null) {
      // TODO(appearance): package assets can be restored with backups later.
      _selectDefaultFallback();
    }
    final background = Stores.setting.appBackgroundPath.fetch();
    if (preset == customPreset &&
        (Stores.setting.appBackgroundStyle.fetch() != BackgroundStyle.image ||
            background.isEmpty ||
            !File(background).existsSync())) {
      _selectDefaultFallback();
    } else if (preset == customPreset) {
      Stores.setting.appThemePackage.put('');
      Stores.setting.appThemePaletteEnabled.put(false);
    }
  }

  static void _selectDefaultFallback() =>
      select(defaultTheme, preset: BuiltinTheme.defaultTheme.id);

  /// What a manifest that omits a field is read as, spelled the way the
  /// manifest spells it.
  static final _defaults = {
    'colors': {'mode': 0, 'seed': 0xFF880E4F, 'systemColor': false},
    'icons': {'style': IconStyle.classic.name, 'images': <String, String>{}},
    'background': {
      'type': BackgroundStyle.none.name,
      'opacity': 0.18,
      'blur': 0,
    },
    'shapes': {'card': 12, 'tile': 8, 'button': 10},
  };

  static Map<String, dynamic> _decodeManifest(String source) {
    final Map<String, dynamic> data;
    try {
      data = TomlDocument.parse(source).toMap();
    } on TomlException {
      throw const FormatException('Invalid TOML manifest');
    }
    data.putIfAbsent('format', () => 1);
    for (final entry in _defaults.entries) {
      final values = data.containsKey(entry.key)
          ? _map(data[entry.key], entry.key)
          : <String, dynamic>{};
      data[entry.key] = {...entry.value, ...values};
    }
    return data;
  }

  static Map<String, dynamic> _map(Object? value, String field) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Invalid $field');
  }

  static String _label(Object? value, String field) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > maxNameLength ||
        value.contains(RegExp(r'[\x00-\x1f]'))) {
      throw FormatException('Invalid $field');
    }
    return value.trim();
  }

  static int _integer(Object? value, int min, int max) {
    if (value is! int || value < min || value > max) {
      throw const FormatException('Invalid number');
    }
    return value;
  }

  static Set<ThemeMode> _themeModes(Object? raw) {
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 2 ||
        raw.toSet().length != raw.length) {
      throw const FormatException('Declare supported theme modes: light, dark');
    }
    return Set.unmodifiable(raw.map(_declaredMode));
  }

  /// One declared mode, refused when the manifest named something else. The
  /// spellings are [ThemeMode]'s own `name`s — see [_declaredModes].
  static ThemeMode _declaredMode(Object? raw) {
    for (final mode in _declaredModes) {
      if (mode.name == raw) return mode;
    }
    throw const FormatException('Declare supported theme modes: light, dark');
  }

  static (int, int) _schemaRange(Object? raw) {
    final schema = _map(raw, 'schema');
    if (schema.length != 2 ||
        !schema.containsKey('min') ||
        !schema.containsKey('max')) {
      throw const FormatException('Invalid theme schema range');
    }
    final min = _integer(schema['min'], 1, 0x7fffffff);
    final max = _integer(schema['max'], 1, 0x7fffffff);
    if (min > max || max < supportedSchemaMin || min > supportedSchemaMax) {
      throw const FormatException('Unsupported theme schema range');
    }
    return (min, max);
  }

  static double _fraction(Object? value, double max) {
    if (value is! num || !value.isFinite || value < 0 || value > max) {
      throw const FormatException('Invalid number');
    }
    return value.toDouble();
  }

  static Map<String, int> _palette(Object? raw) {
    if (raw == null) return {};
    final values = _map(raw, 'palette');
    if (!values.keys.every(ThemePalette.roles.contains)) {
      throw const FormatException('Invalid palette role');
    }
    return {
      for (final entry in values.entries)
        entry.key: _integer(entry.value, 0, 0xffffffff),
    };
  }

  /// A color as both [ThemePalette] and the splash accept one: an ARGB integer
  /// or the name of a role, which is what lets one value read correctly in both
  /// brightnesses.
  static Object _colorSpec(Object? value) {
    if (value is int && value >= 0 && value <= 0xffffffff) return value;
    if (value is String && ThemePalette.roles.contains(value)) return value;
    throw const FormatException('Invalid color');
  }

  /// Per-icon colors, each of which has to belong to an icon the package
  /// carries — a color for a key that is not there is a typo that would
  /// otherwise show up as nothing at all.
  static Map<String, Object> _iconColors(
    Map<String, dynamic> raw,
    Iterable<String> icons,
  ) {
    final colors = <String, Object>{};
    for (final entry in raw.entries) {
      if (!icons.contains(entry.key)) {
        throw const FormatException('Icon color without an image');
      }
      colors[entry.key] = _colorSpec(entry.value);
    }
    return colors;
  }

  /// The splash table, or null when the package asks for none — which is why it
  /// is not in [_defaults]: every package would otherwise carry one.
  static ThemeSplash? _splash(Object? raw) {
    if (raw == null) return null;
    final table = _map(raw, 'splash');
    if (!table.keys.every(splashFields.contains)) {
      throw const FormatException('Unknown splash field');
    }
    final logo = table['logo'];
    if (logo != null && !splashLogos.contains(logo)) {
      throw const FormatException('Invalid splash logo path');
    }
    final duration = table.containsKey('duration')
        ? _integer(
            table['duration'],
            ThemeSplash.minDuration,
            ThemeSplash.maxDuration,
          )
        : ThemeSplash.defaultDuration;
    return ThemeSplash(
      color: table.containsKey('color') ? _colorSpec(table['color']) : 'surface',
      logo: logo as String?,
      duration: duration,
    );
  }

  /// Refuses a package that reaches for what schema [featureSchema] added while
  /// saying an older schema can read it, because that build installs the same
  /// bytes and then quietly drops the feature — an SVG icon becomes the built-in
  /// glyph, a per-icon color or a splash simply does not happen.
  ///
  /// So what is asked of such a package is not that its range *contains*
  /// [featureSchema] but that it *needs* it: `min` is the version a reader has
  /// to understand, and one that does not understand schema 2 must not be
  /// handed the files.
  static void _requireFeatureSchema({
    required int min,
    required Iterable<String> iconFiles,
    required Map<String, Object> iconColors,
    required ThemeSplash? splash,
  }) {
    final uses =
        iconFiles.any((name) => name.endsWith('.svg')) ||
        iconColors.isNotEmpty ||
        splash != null;
    if (uses && min < featureSchema) {
      throw const FormatException('This theme needs schema $featureSchema');
    }
  }

  /// The only two names a package may give an icon. Both are derived from the
  /// key, so the manifest cannot point at a file that is some other icon.
  static String _iconAssetPath(String key, Object? value) {
    final stem = key.replaceAll('.', '_');
    if (value != '$_iconsDir/$stem.png' && value != '$_iconsDir/$stem.svg') {
      throw const FormatException('Invalid icon path');
    }
    return value as String;
  }

  static Future<Uint8List> _iconPng(
    Map<String, Uint8List> assets,
    String path,
    int maxBytes,
  ) async {
    final bytes = _imageAsset(assets, path, maxBytes);
    if (!_isPng(bytes)) {
      throw const FormatException('Icons must be PNG or SVG');
    }
    await _verifyImage(bytes, maxDimension: 512, maxPixels: 512 * 512);
    return bytes;
  }

  /// An SVG icon is checked as a document rather than rendered: it has no
  /// raster size to measure, and what a bad one costs is a fallback to the
  /// built-in glyph rather than a broken install. Refused are the things that
  /// make an SVG a document instead of a drawing — a DTD, which is what entity
  /// expansion and external entities need to exist, and anything that reaches
  /// outside the file.
  static Uint8List _svgAsset(
    Map<String, Uint8List> assets,
    String path,
    int maxBytes,
  ) {
    final bytes = _assetBytes(assets, path, maxBytes);
    final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('SVG must be UTF-8');
    }
    final lower = source.toLowerCase();
    for (final refused in const [
      '<!doctype',
      '<!entity',
      '<script',
      '<foreignobject',
      'href="http',
      "href='http",
      'url(http',
    ]) {
      if (lower.contains(refused)) {
        throw const FormatException('Unsupported SVG content');
      }
    }
    final xml.XmlDocument document;
    try {
      document = xml.XmlDocument.parse(source);
    } on xml.XmlException {
      throw const FormatException('Invalid SVG document');
    }
    if (document.rootElement.name.local != 'svg') {
      throw const FormatException('An SVG must have svg as its root element');
    }
    return bytes;
  }

  static Map<String, Uint8List> _readArchive(List<int> bytes) {
    try {
      final zip = ZipDirectory()
        ..read(InputMemoryStream(Uint8List.fromList(bytes)));
      if (zip.filePosition < 0 ||
          zip.numberOfThisDisk != 0 ||
          zip.diskWithTheStartOfTheCentralDirectory != 0 ||
          zip.totalCentralDirectoryEntries != zip.fileHeaders.length ||
          zip.totalCentralDirectoryEntriesOnThisDisk !=
              zip.fileHeaders.length ||
          zip.fileHeaders.isEmpty ||
          zip.fileHeaders.length > _maxIcons + 4) {
        throw const FormatException('Invalid theme ZIP');
      }
      final assets = <String, Uint8List>{};
      var total = 0;
      for (final header in zip.fileHeaders) {
        final path = header.filename;
        final file = header.file;
        if (path == '$_iconsDir/' &&
            !assets.containsKey(path) &&
            header.uncompressedSize == 0 &&
            header.compressedSize == 0 &&
            header.crc32 == 0 &&
            header.compressionMethod == 0 &&
            (header.generalPurposeBitFlag & 1) == 0 &&
            ((header.externalFileAttributes >> 16) & 0xf000) != 0xa000 &&
            file?.filename == path &&
            file?.flags == header.generalPurposeBitFlag &&
            file?.compressionMethod == CompressionType.none) {
          assets[path] = Uint8List(0);
          continue;
        }
        final max = path == 'manifest.toml'
            ? _maxManifestBytes
            : path.startsWith('$_iconsDir/')
            ? _maxIconBytes
            : path.startsWith('splash_logo.')
            ? _maxSplashLogoBytes
            : _maxBackgroundBytes;
        if (path.isEmpty ||
            path.startsWith('/') ||
            path.contains('\\') ||
            path
                .split('/')
                .any((part) => part.isEmpty || part == '.' || part == '..') ||
            assets.containsKey(path) ||
            ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000 ||
            (header.generalPurposeBitFlag & 1) != 0 ||
            (header.compressionMethod != 0 && header.compressionMethod != 8) ||
            header.diskNumberStart != 0 ||
            header.compressedSize < 0 ||
            header.compressedSize > maxPackageBytes ||
            header.uncompressedSize <= 0 ||
            header.uncompressedSize > max ||
            total + header.uncompressedSize > maxPackageBytes) {
          throw const FormatException('Invalid theme ZIP entry');
        }
        if (file == null ||
            file.filename != path ||
            file.flags != header.generalPurposeBitFlag ||
            file.compressionMethod !=
                (header.compressionMethod == 8
                    ? CompressionType.deflate
                    : CompressionType.none)) {
          throw const FormatException('Invalid theme ZIP entry');
        }
        final output = _BoundedOutputStream(max);
        file.decompress(output);
        final decoded = output.getBytes();
        if (decoded.length != header.uncompressedSize ||
            getCrc32(decoded) != header.crc32) {
          throw const FormatException('Corrupt theme ZIP entry');
        }
        assets[path] = decoded;
        total += decoded.length;
      }
      if (!assets.containsKey('manifest.toml')) {
        throw const FormatException('Missing theme manifest');
      }
      return assets;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid theme ZIP');
    }
  }

  static Uint8List _assetBytes(
    Map<String, Uint8List> assets,
    String path,
    int maxBytes,
  ) {
    final bytes = assets[path];
    if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Theme asset exceeds size limit');
    }
    return bytes;
  }

  static Uint8List _imageAsset(
    Map<String, Uint8List> assets,
    String path,
    int maxBytes,
  ) {
    final bytes = _assetBytes(assets, path, maxBytes);
    if (!(_isPng(bytes) || _isJpeg(bytes))) {
      throw const FormatException('Use a PNG or JPEG image');
    }
    return bytes;
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((entry) => bytes[entry.key] == entry.value);

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;

  static Future<void> _verifyImage(
    Uint8List bytes, {
    required int maxDimension,
    required int maxPixels,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > maxDimension ||
            descriptor.height > maxDimension ||
            descriptor.width * descriptor.height > maxPixels) {
          throw const FormatException('Image resolution exceeds limit');
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}

final class _BoundedOutputStream extends OutputMemoryStream {
  _BoundedOutputStream(this.maxBytes) : super(size: 0);

  final int maxBytes;

  void _check(int count) {
    if (count < 0 || length + count > maxBytes) {
      throw const FormatException('Theme asset exceeds size limit');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _check(count);
    super.writeBackReference(distance, count);
  }
}

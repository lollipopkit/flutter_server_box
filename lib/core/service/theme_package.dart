import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ColorScheme, ThemeMode;
import 'package:flutter/services.dart'
    show AssetBundle, AssetManifest, rootBundle;
import 'package:server_box/core/service/theme_components.dart';
import 'package:server_box/core/service/theme_palette.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:toml/toml.dart';

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
    required this.iconKeys,
    required this.backgroundStyle,
    required this.opacity,
    required this.blur,
    required this.cardRadius,
    required this.tileRadius,
    required this.buttonRadius,
    required this.directory,
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
  final String iconStyle;
  final Set<String> iconKeys;
  final String backgroundStyle;
  final double opacity;
  final double blur;
  final double cardRadius;
  final double tileRadius;
  final double buttonRadius;
  final String directory;
  final String? backgroundFile;
  final ThemeComponents components;

  String? get backgroundPath => backgroundStyle == 'image'
      ? backgroundFile ?? directory.joinPath('background.img')
      : null;

  String? iconPath(String key) => iconKeys.contains(key)
      ? directory.joinPath('icons').joinPath('${key.replaceAll('.', '_')}.png')
      : null;
}

final class ThemeStoreEntry {
  const ThemeStoreEntry(this.name, this.url, this.sha256);
  final String name;
  final Uri url;
  final String sha256;
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
  static const supportedSchemaMax = 1;
  static String get supportedSchemaRange =>
      'v$supportedSchemaMin–v$supportedSchemaMax';

  static const maxPackageBytes = 16 * 1024 * 1024;
  static const _maxBackgroundBytes = 8 * 1024 * 1024;
  static const _maxIconBytes = 256 * 1024;
  static const _maxManifestBytes = 64 * 1024;
  static const _maxCatalogBytes = 1024 * 1024;
  static const _maxIcons = 48;
  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');
  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');
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
    iconStyle: 'classic',
    iconKeys: {},
    backgroundStyle: 'none',
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

  static final _iconKeys = <String>{
    for (final tab in [
      'server',
      'ssh',
      'file',
      'snippet',
      'agent',
      'benchmark',
      'remoteDesktop',
    ]) ...['tab.$tab', 'tab.$tab.selected'],
    for (final item in [
      'more',
      'settings',
      'tune',
      'privacy',
      'agent',
      'tabs',
      'server',
      'sort',
      'terminal',
      'folder',
      'cloud',
      'snippet',
      'inbox',
      'key',
      'info',
      'download',
      'desktop',
    ])
      'nav.$item',
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

  static Future<List<ThemeStoreEntry>> catalog(String url) async {
    final base = httpsUri(url);
    final bytes = await download(url, maxBytes: _maxCatalogBytes);
    return parseCatalog(bytes, base);
  }

  static List<ThemeStoreEntry> parseCatalog(List<int> bytes, Uri base) {
    httpsUri(base.toString());
    if (bytes.length > _maxCatalogBytes) {
      throw const FormatException('Catalog exceeds size limit');
    }
    final data = _map(jsonDecode(utf8.decode(bytes)), 'catalog');
    if (data['format'] != 1) throw const FormatException('Unsupported catalog');
    final rows = data['themes'];
    if (rows is! List || rows.length > 100) {
      throw const FormatException('Invalid catalog entries');
    }
    return rows.map((raw) {
      final row = _map(raw, 'catalog entry');
      final name = _label(row['name'], 'name');
      final url = row['url'];
      final digest = row['sha256'];
      if (url is! String ||
          digest is! String ||
          !_digestPattern.hasMatch(digest)) {
        throw const FormatException('Invalid catalog entry');
      }
      return ThemeStoreEntry(
        name,
        httpsUri(base.resolve(url).toString()),
        digest,
      );
    }).toList();
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
      if (name == 'icons') {
        if (entry is! Directory) {
          throw const FormatException('Invalid icons directory');
        }
        await for (final icon in entry.list(followLinks: false)) {
          final iconName = icon.uri.pathSegments
              .where((part) => part.isNotEmpty)
              .last;
          if (!iconName.endsWith('.png')) continue;
          if (icon is! File) {
            throw const FormatException('Invalid theme icon');
          }
          await readFile(icon, 'icons/$iconName', _maxIconBytes);
          if (assets.length > _maxIcons + 2) {
            throw const FormatException('Too many theme assets');
          }
        }
      } else if (name == 'background.png' ||
          name == 'background.jpg' ||
          name == 'background.jpeg') {
        if (entry is! File) {
          throw const FormatException('Invalid theme background');
        }
        await readFile(entry, name, _maxBackgroundBytes);
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
        assets.length > _maxIcons + 2 ||
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
    final (schemaMin, schemaMax) = _schemaRange(data['schema']);
    final id = data['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
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
    if (!palette.keys.every((key) => key == 'light' || key == 'dark')) {
      throw const FormatException('Invalid palette brightness');
    }
    final paletteLight = _palette(palette['light']);
    final paletteDark = _palette(palette['dark']);
    final components = ThemeComponents.parse(data['components']);
    final icons = _map(data['icons'], 'icons');
    final style = icons['style'];
    if (style != 'classic' && style != 'mingcute') {
      throw const FormatException('Invalid icon style');
    }
    final imageMap = icons['images'] == null
        ? <String, dynamic>{}
        : _map(icons['images'], 'icon images');
    if (imageMap.length > _maxIcons ||
        !imageMap.keys.every(_iconKeys.contains)) {
      throw const FormatException('Invalid icon keys');
    }
    final background = _map(data['background'], 'background');
    final backgroundStyle = background['type'];
    if (!['none', 'gradient', 'image'].contains(backgroundStyle)) {
      throw const FormatException('Invalid background type');
    }
    final opacity = _fraction(background['opacity'], 0.6);
    final blur = _fraction(background['blur'], 30);
    final shapes = _map(data['shapes'], 'shapes');
    final card = _fraction(shapes['card'], 40);
    final tile = _fraction(shapes['tile'], 40);
    final button = _fraction(shapes['button'], 40);

    final usedAssets = <String>{'manifest.toml'};
    Uint8List? backgroundBytes;
    if (backgroundStyle == 'image') {
      final path = background['image'];
      if (path != 'background.png' &&
          path != 'background.jpg' &&
          path != 'background.jpeg') {
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
    final iconBytes = <String, Uint8List>{};
    for (final entry in imageMap.entries) {
      final path = 'icons/${entry.key.replaceAll('.', '_')}.png';
      if (entry.value != path) {
        throw const FormatException('Invalid icon path');
      }
      usedAssets.add(path);
      final image = _imageAsset(assets, path, _maxIconBytes);
      if (!_isPng(image)) throw const FormatException('Icons must be PNG');
      await _verifyImage(image, maxDimension: 512, maxPixels: 512 * 512);
      iconBytes[entry.key] = image;
    }
    if (assets.keys.any(
      (path) => path != 'icons/' && !usedAssets.contains(path),
    )) {
      throw const FormatException('Unexpected theme asset');
    }

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
        final iconDir = Directory(staging.path.joinPath('icons'));
        await iconDir.create();
        for (final entry in iconBytes.entries) {
          await File(
            iconDir.path.joinPath('${entry.key.replaceAll('.', '_')}.png'),
          ).writeAsBytes(entry.value, flush: true);
        }
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
          'palette': {'light': paletteLight, 'dark': paletteDark},
        },
        'icons': {'style': style, 'images': iconBytes.keys.toList()},
        'background': {
          'type': backgroundStyle,
          'opacity': opacity,
          'blur': blur,
        },
        'shapes': {'card': card, 'tile': tile, 'button': button},
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

  static ThemePackage? installed(String id, {String? rootDirectory}) {
    if (!_digestPattern.hasMatch(id)) return null;
    final directory = (rootDirectory ?? root).joinPath(id);
    try {
      final file = File(directory.joinPath('manifest.toml'));
      if (!file.existsSync() || file.lengthSync() > _maxManifestBytes) {
        return null;
      }
      final data = _decodeManifest(file.readAsStringSync());
      if (data['format'] != 1) return null;
      final (schemaMin, schemaMax) = _schemaRange(data['schema']);
      final themeId = data['id'];
      if (themeId is! String || !_idPattern.hasMatch(themeId)) return null;
      final colors = _map(data['colors'], 'colors');
      final palette = colors['palette'] == null
          ? <String, dynamic>{}
          : _map(colors['palette'], 'palette');
      final icons = _map(data['icons'], 'icons');
      final background = _map(data['background'], 'background');
      final shapes = _map(data['shapes'], 'shapes');
      final iconKeys = (icons['images'] as List).cast<String>().toSet();
      if (!iconKeys.every(_iconKeys.contains)) return null;
      final style = icons['style'] as String;
      final bgStyle = background['type'] as String;
      if (!['classic', 'mingcute'].contains(style) ||
          !['none', 'gradient', 'image'].contains(bgStyle)) {
        return null;
      }
      final package = ThemePackage(
        installationId: id,
        id: themeId,
        name: _label(data['name'], 'name'),
        schemaMin: schemaMin,
        schemaMax: schemaMax,
        mode: _integer(colors['mode'], 0, 2),
        modes: _themeModes(data['modes']),
        seed: _integer(colors['seed'], 0, 0xffffffff),
        systemColor: colors['systemColor'] as bool,
        paletteLight: _palette(palette['light']),
        paletteDark: _palette(palette['dark']),
        components: ThemeComponents.parse(data['components']),
        iconStyle: style,
        iconKeys: iconKeys,
        backgroundStyle: bgStyle,
        opacity: _fraction(background['opacity'], 0.6),
        blur: _fraction(background['blur'], 30),
        cardRadius: _fraction(shapes['card'], 40),
        tileRadius: _fraction(shapes['tile'], 40),
        buttonRadius: _fraction(shapes['button'], 40),
        directory: directory,
      );
      if (package.backgroundPath case final path?
          when !File(path).existsSync()) {
        return null;
      }
      for (final key in iconKeys) {
        if (!File(package.iconPath(key)!).existsSync()) return null;
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
      final id = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      final theme = installed(id, rootDirectory: directory.path);
      if (theme != null) themes.add(theme);
    }
    themes.sort((a, b) => a.name.compareTo(b.name));
    return themes;
  }

  static Map<String, String> installedPresetNames({String? rootDirectory}) => {
    for (final theme in listInstalled(rootDirectory: rootDirectory))
      'package:${theme.installationId}': theme.name,
  };

  static String? activeIconPath(String key) {
    if (!_iconKeys.contains(key)) return null;
    return activeTheme?.iconPath(key);
  }

  static ThemePackage? get activeTheme {
    if (preview.value case final theme?) return theme;
    final preset = BuiltinTheme.fromId(Stores.setting.appThemePreset.fetch());
    if (preset != null) return _builtinLoader.loaded(preset);
    final id = Stores.setting.appThemePackage.fetch();
    if (_activeId != id) {
      _activeId = id;
      _active = installed(id);
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
    settings.appThemePackage.put(
      preset.startsWith('package:') ? theme.installationId : '',
    );
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

  static void reconcileSelection() {
    final preset = Stores.setting.appThemePreset.fetch();
    if (preset.startsWith('package:') &&
        installed(preset.substring(8)) == null) {
      // TODO(appearance): package assets can be restored with backups later.
      _selectDefaultFallback();
    }
    final background = Stores.setting.appBackgroundPath.fetch();
    if (preset == 'custom' &&
        (Stores.setting.appBackgroundStyle.fetch() != 'image' ||
            background.isEmpty ||
            !File(background).existsSync())) {
      _selectDefaultFallback();
    } else if (preset == 'custom') {
      Stores.setting.appThemePackage.put('');
      Stores.setting.appThemePaletteEnabled.put(false);
    }
  }

  static void _selectDefaultFallback() =>
      select(defaultTheme, preset: BuiltinTheme.defaultTheme.id);

  static const _defaults = {
    'colors': {'mode': 0, 'seed': 0xFF880E4F, 'systemColor': false},
    'icons': {'style': 'classic', 'images': <String, String>{}},
    'background': {'type': 'none', 'opacity': 0.18, 'blur': 0},
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
        value.length > 80 ||
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
        raw.toSet().length != raw.length ||
        raw.any((mode) => mode != 'light' && mode != 'dark')) {
      throw const FormatException('Declare supported theme modes: light, dark');
    }
    return Set.unmodifiable(
      raw.map((mode) => mode == 'light' ? ThemeMode.light : ThemeMode.dark),
    );
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
          zip.fileHeaders.length > _maxIcons + 3) {
        throw const FormatException('Invalid theme ZIP');
      }
      final assets = <String, Uint8List>{};
      var total = 0;
      for (final header in zip.fileHeaders) {
        final path = header.filename;
        final file = header.file;
        if (path == 'icons/' &&
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
            : path.startsWith('icons/')
            ? _maxIconBytes
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

  static Uint8List _imageAsset(
    Map<String, Uint8List> assets,
    String path,
    int maxBytes,
  ) {
    final bytes = assets[path];
    if (bytes == null ||
        bytes.isEmpty ||
        bytes.length > maxBytes ||
        !(_isPng(bytes) || _isJpeg(bytes))) {
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

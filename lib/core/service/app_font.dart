import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:server_box/data/res/store.dart';

/// Loads a user-provided UI font under its chosen family name.
abstract final class AppFont {
  static const maxBytes = 10 * 1024 * 1024;

  static List<String> get families =>
      normalizeFamilies(Stores.setting.appFontFamilies.fetch());

  static void saveFamilies(List<String> names) {
    Stores.setting.appFontFamilies.put(normalizeFamilies(names));
  }

  static List<String> normalizeFamilies(Iterable<String> names) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty ||
          name.length > 64 ||
          name.contains(RegExp(r'[\r\n\x00]'))) {
        continue;
      }
      if (seen.add(name.toLowerCase())) result.add(name);
      if (result.length == 12) break;
    }
    return result;
  }

  static Future<void> loadStored() async {
    final path = Stores.setting.appImportedFontPath.fetch();
    final name = Stores.setting.appImportedFontName.fetch();
    if (!_owned(path) || name.isEmpty || !File(path).existsSync()) return;
    try {
      await _load(path, name);
    } catch (error, stack) {
      Loggers.app.warning('Could not load the imported app font', error, stack);
    }
  }

  static Future<void> importFile(String sourcePath, String family) async {
    final name = normalizeFamilies([family]).firstOrNull;
    if (name == null) throw const FormatException('Invalid font family');
    final extension = sourcePath.toLowerCase().split('.').last;
    if (extension != 'ttf' && extension != 'otf') {
      throw const FormatException('Use a TTF or OTF font');
    }
    final source = File(sourcePath);
    if (await source.length() > maxBytes) {
      throw const FormatException('Font exceeds 10 MB');
    }
    final target = File(
      Paths.font.joinPath(
        'app_ui_${DateTime.now().microsecondsSinceEpoch}.$extension',
      ),
    );
    try {
      await source.copy(target.path);
      await _load(target.path, name);
      final oldPath = Stores.setting.appImportedFontPath.fetch();
      final oldName = Stores.setting.appImportedFontName.fetch();
      Stores.setting.appImportedFontPath.put(target.path);
      Stores.setting.appImportedFontName.put(name);
      saveFamilies(
        normalizeFamilies([
          name,
          ...families.where((value) => value != oldName),
        ]),
      );
      if (_owned(oldPath) && oldPath != target.path) {
        try {
          await File(oldPath).delete();
        } on FileSystemException {
          // A missing previous file does not invalidate the new font.
        }
      }
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  static Future<void> removeImported() async {
    final path = Stores.setting.appImportedFontPath.fetch();
    final name = Stores.setting.appImportedFontName.fetch();
    saveFamilies(families.where((value) => value != name).toList());
    Stores.setting.appImportedFontPath.put('');
    Stores.setting.appImportedFontName.put('');
    if (_owned(path)) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // The font may already have been removed outside the app.
      }
    }
  }

  static Future<void> _load(String path, String family) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException('Font exceeds 10 MB');
    }
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  static bool _owned(String path) =>
      path.isNotEmpty &&
      File(path).parent.path == Paths.font &&
      File(path).uri.pathSegments.last.startsWith('app_ui_');
}

/// Where a plugin's own files live, and what counts as one. PLUGINS.md 5.1.
///
/// A plugin may ship images in its package under `assets/`, and an `image`
/// node names one. Everything about that is a path question, and a path a
/// third party wrote is the classic way to read a file nobody meant to serve —
/// so the name is checked here, in one place, rather than at each use.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';

abstract final class PluginAssets {
  /// The directory inside a plugin's own, where its files go.
  static const dirName = 'assets';

  /// What a package may carry, by extension.
  ///
  /// A list rather than a check on the bytes: what the app draws is decided by
  /// the name (`.svg` goes to the vector renderer), so a `.png` holding
  /// something else is a broken image and a `.sh` is not carried at all. The
  /// same rule as the app's own bundled assets, which App Store validation
  /// walks looking for anything that reads as code.
  static const allowed = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg'};

  /// Whether [name] is a file a package may carry under [dirName].
  ///
  /// Refuses a path with any directory in it. One flat directory is enough for
  /// what this is for, and it means there is no `..` to reason about — the
  /// check is "no separators" rather than a normalisation somebody has to get
  /// right.
  static bool isAllowed(String name) {
    if (name.isEmpty || name.length > 128) return false;
    if (name.contains('/') || name.contains(r'\')) return false;
    if (name.startsWith('.')) return false;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return false;
    return allowed.contains(name.substring(dot).toLowerCase());
  }

  /// The file [name] names inside [dir], or null.
  ///
  /// Null for a name this build will not read and for a plugin with no
  /// directory — a development plugin whose author has not made one yet.
  /// Existence is *not* checked: this is called while building a frame, and a
  /// `stat` per image per frame would be a filesystem call on the raster path.
  /// A file that is not there draws the image widget's own error instead.
  static String? pathOf(String? dir, String name) {
    if (dir == null || dir.isEmpty || !isAllowed(name)) return null;
    return dir.joinPath(dirName).joinPath(name);
  }

  /// Every asset in [dir], for an install to copy or a package to carry.
  static List<File> listIn(Directory dir) {
    final assets = Directory(dir.path.joinPath(dirName));
    if (!assets.existsSync()) return const [];
    return [
      for (final entity in assets.listSync())
        if (entity is File && isAllowed(entity.path.split('/').last)) entity,
    ];
  }
}

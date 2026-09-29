import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/res/store.dart';

/// The absolute paths the settings keep to files under [Paths.doc], moved onto
/// where [Paths.doc] is now.
///
/// iOS gives an app a new data container when it is installed again or
/// updated, and carries the files across. A path written before that names the
/// old container, where nothing is: a theme's background, the user's own
/// background and the fonts would all be dropped without a word.
abstract final class StoredPaths {
  /// Once at launch, after the stores are open and before anything reads them.
  static void repair() {
    final settings = Stores.setting;
    for (final prop in [
      settings.appBackgroundPath,
      settings.appCustomBackgroundPath,
      settings.appImportedFontPath,
      settings.fontPath,
    ]) {
      final moved = rebase(prop.fetch(), doc: Paths.doc);
      if (moved == null) continue;
      // Not the user's edit: another device syncing this setting has paths of
      // its own either way.
      settings.set(prop.key, moved, updateLastUpdateTsOnSet: false);
    }
  }

  /// [path] under [doc], by what follows [doc]'s own name in it, when [path]
  /// is gone and the file is there. Null when there is nothing to move.
  static String? rebase(
    String path, {
    required String doc,
    bool Function(String path)? exists,
  }) {
    final isFile = exists ?? (p) => File(p).existsSync();
    final docName = doc.getFileName();
    if (path.isEmpty || docName == null || isFile(path)) return null;
    final name = '/$docName/';
    final at = path.indexOf(name);
    if (at < 0) return null;
    final moved = doc.joinPath(path.substring(at + name.length));
    if (moved == path || !isFile(moved)) return null;
    return moved;
  }
}

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';

/// The editor as a file page opens it, with the user's editor settings.
EditorPageArgs fileEditorArgs({
  required String path,
  required void Function(EditorPageRet) onSave,
}) {
  final font = Stores.setting.editorFontFamily.fetch();
  return EditorPageArgs(
    path: path,
    onSave: onSave,
    closeAfterSave: Stores.setting.closeAfterSave.fetch(),
    softWrap: Stores.setting.editorSoftWrap.fetch(),
    enableHighlight: Stores.setting.editorHighlight.fetch(),
    lightTheme: HighlightTheme.fromThemeMapKey(
      Stores.setting.editorTheme.fetch(),
    ),
    darkTheme: HighlightTheme.fromThemeMapKey(
      Stores.setting.editorDarkTheme.fetch(),
    ),
    fontFamily: font.isEmpty ? null : font,
  );
}

/// Whether a file [size] bytes long fits the editor; says so when it does not.
bool fitsEditor(String name, int size) {
  if (size <= Miscs.editorMaxSize) return true;
  Toast.show(
    l10n.fileTooLarge(name, size.bytes2Str, Miscs.editorMaxSize.bytes2Str),
  );
  return false;
}

/// Where a server's file at [remotePath] is kept on this device: under its
/// server's directory, by the path it has there.
String serverLocalPath(String serverId, String remotePath) {
  final parts = remotePath.split('/').where((part) => part.isNotEmpty);
  return parts.fold(
    Paths.file.joinPath(serverId),
    (path, part) => path.joinPath(_safeLocalPathPart(part)),
  );
}

/// A path component that is safe to write on this device.
///
/// A remote name may be anything the far side allows, and this app files
/// downloads under the path they came from — so a name Windows reserves, or
/// one with a separator in it, has to be flattened before it becomes a local
/// directory.
String _safeLocalPathPart(String part) {
  if (part == '.' || part == '..') return '_';
  var safe = part.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  safe = safe.replaceAll(RegExp(r'[ .]+$'), '');
  if (safe.isEmpty) return '_';

  final baseName = safe.split('.').first.toUpperCase();
  final isReservedDeviceName = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
  ).hasMatch(baseName);
  if (isReservedDeviceName) safe = '_$safe';
  // Every reserved character became the same `_`, so `a:b` and `a?b` — both
  // valid names on the server — mapped to one local file, and downloading the
  // second replaced the first with nothing said. The tag is what makes the
  // mapping reversible enough to be distinct; it is only added where something
  // was actually changed, so an ordinary name is still filed under itself.
  return safe == part ? safe : '$safe-${_partTag(part)}';
}

/// A short, stable tag for [part], to tell apart two names that flatten to one.
///
/// FNV-1a over the code units: it needs to be the same on every launch and on
/// every platform, which `hashCode` does not promise, and it is not protecting
/// anything — a collision here costs a download, not a secret.
String _partTag(String part) {
  var hash = 0x811c9dc5;
  for (final unit in part.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(36).padLeft(7, '0');
}


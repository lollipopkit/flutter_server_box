part of 'sftp.dart';

String _normalizeSftpPath(String path) => path.replaceAll(RegExp(r'/+'), '/');

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

/// The command that unpacks [filename] where it is, from
/// `sbm_parser::files`; null for a file it does not know how to unpack.
String? _getDecompressCmd(String filename) =>
    files.filesExtractCommand(path: filename);

bool _canDecompress(String filename) => _getDecompressCmd(filename) != null;

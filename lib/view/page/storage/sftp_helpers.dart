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

String? _getDecompressCmd(String filename) {
  final quotedFilename = shellSingleQuote(filename);
  for (final ext in _extCmdMap.keys) {
    if (filename.endsWith('.$ext')) {
      return _extCmdMap[ext]?.replaceAll('FILE', quotedFilename);
    }
  }
  return null;
}

bool _canDecompress(String filename) {
  for (final ext in _extCmdMap.keys) {
    if (filename.endsWith('.$ext')) {
      return true;
    }
  }
  return false;
}

/// Translate from
/// https://github.com/ohmyzsh/ohmyzsh/blob/03a0d5bbaedc732436b5c67b166cde954817cc2f/plugins/extract/extract.plugin.zsh
const _extCmdMap = {
  'tar.gz': 'tar zxvf FILE',
  'tgz': 'tar zxvf FILE',
  'tar.bz2': 'tar jxvf FILE',
  'tbz2': 'tar jxvf FILE',
  'tar.xz': 'tar --xz -xvf FILE',
  'txz': 'tar --xz -xvf FILE',
  'tar.lzma': 'tar --lzma -xvf FILE',
  'tlz': 'tar --lzma -xvf FILE',
  'tar.zst': 'tar --zstd -xvf FILE',
  'tzst': 'tar --zstd -xvf FILE',
  'tar': 'tar xvf FILE',
  'tar.lz': 'tar xvf FILE',
  'tar.lz4': 'lz4 -c -d FILE | tar xvf - ',
  'gz': 'gunzip FILE',
  'bz2': 'bunzip2 FILE',
  'xz': 'unxz FILE',
  'lzma': 'unlzma FILE',
  'z': 'uncompress FILE',
  'zip': 'unzip FILE',
  'war': 'unzip FILE',
  'jar': 'unzip FILE',
  'ear': 'unzip FILE',
  'sublime-package': 'unzip FILE',
  'ipa': 'unzip FILE',
  'ipsw': 'unzip FILE',
  'apk': 'unzip FILE',
  'xpi': 'unzip FILE',
  'aar': 'unzip FILE',
  'whl': 'unzip FILE',
  'rar': 'unrar x -ad FILE',
  'rpm': 'rpm2cpio FILE | cpio --quiet -id',
  '7z': '7za x FILE',
  'zst': 'unzstd FILE',
  'cab': 'cabextract FILE',
  'exe': 'cabextract FILE',
  'cpio': 'cpio -idmvF FILE',
  'obscpio': 'cpio -idmvF FILE',
  'zpaq': 'zpaq x FILE',
};

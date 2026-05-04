part of 'sftp.dart';

String _normalizeSftpPath(String path) => path.replaceAll(RegExp(r'/+'), '/');

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

/// Return fmt: 2021-01-01 00:00:00
String _getTime(int? unixMill) {
  return DateTime.fromMillisecondsSinceEpoch(
    (unixMill ?? 0) * 1000,
  ).toString().replaceFirst('.000', '');
}

enum _SortType {
  name,
  time,
  size;

  List<SftpName> sort(List<SftpName> files, {bool reversed = false}) {
    final sortedFiles = List<SftpName>.of(files);
    var comparator = ChainComparator<SftpName>.create();
    if (Stores.setting.sftpShowFoldersFirst.fetch()) {
      comparator = comparator.thenTrueFirst((x) => x.attr.isDirectory);
    }
    switch (this) {
      case _SortType.name:
        sortedFiles.sort(
          comparator
              .thenWithComparator(
                (a, b) => Comparators.compareStringCaseInsensitive()(
                  a.filename,
                  b.filename,
                ),
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.time:
        sortedFiles.sort(
          comparator
              .thenCompareBy<num>(
                (x) => x.attr.modifyTime ?? 0,
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.size:
        sortedFiles.sort(
          comparator
              .thenCompareBy<num>((x) => x.attr.size ?? 0, reversed: reversed)
              .compare,
        );
        break;
    }
    return sortedFiles;
  }
}

class _SortOption {
  final _SortType sortBy;
  final bool reversed;

  _SortOption({this.sortBy = _SortType.name, this.reversed = false});

  _SortOption copyWith({_SortType? sortBy, bool? reversed}) {
    return _SortOption(
      sortBy: sortBy ?? this.sortBy,
      reversed: reversed ?? this.reversed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _SortOption &&
        other.sortBy == sortBy &&
        other.reversed == reversed;
  }

  @override
  int get hashCode => Object.hash(sortBy, reversed);
}

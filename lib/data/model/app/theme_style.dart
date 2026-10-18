import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';

/// A symbol of this app that a theme package may carry an image or a color
/// for, other than a tab's.
///
/// The key is a field rather than the value's own name: the spelling is
/// namespaced and dotted, so it is not an identifier. The keys this app
/// declares to the shared theme code (`ThemeIcons` in `theme_host.dart`) are
/// the tabs' and these, so a symbol here is one a widget can look up without
/// repeating the spelling.
enum ThemeNavIcon {
  more('nav.more'),
  settings('nav.settings'),
  tune('nav.tune'),
  privacy('nav.privacy'),
  agent('nav.agent'),
  tabs('nav.tabs'),
  server('nav.server'),
  sort('nav.sort'),
  terminal('nav.terminal'),
  folder('nav.folder'),
  cloud('nav.cloud'),
  snippet('nav.snippet'),
  inbox('nav.inbox'),
  key('nav.key'),
  info('nav.info'),
  download('nav.download'),
  desktop('nav.desktop');

  const ThemeNavIcon(this.iconKey);

  /// What a manifest's `icons.images` and `icons.colors` are keyed by, and what
  /// a widget asks the active package for.
  ///
  /// Not `key`: a value is named `key` too, and a case's name is a static member
  /// of the enum.
  final String iconKey;
}

/// Keys the Files window looks up on the active theme: `file.dir`,
/// `file.link`, `file.default`, and `file.<ext>` for a name's extension.
///
/// Not an enum of every extension a package may carry — a theme lists the
/// ones it has, and a name whose key is missing falls back to
/// [fallback], then to the built-in glyph.
abstract final class ThemeFileIcon {
  static const dir = 'file.dir';
  static const link = 'file.link';
  static const fallback = 'file.default';

  /// Well-formed Files-window keys, including any `file.<ext>` a package
  /// chooses to ship. The editor schema lists [schemaKeys]; the installer
  /// still accepts any key that matches this.
  static final keyPattern = RegExp(r'^file\.[a-z][a-z0-9]*$');

  /// Keys the editor schema names with the same path rule as tab and nav.
  /// JSON Schema cannot bind an arbitrary property to its file name.
  static Set<String> get schemaKeys => {
    ..._builtIn.keys,
    for (final ext in _alias.keys) 'file.$ext',
    for (final mapped in _named.values) 'file.$mapped',
  };

  static const _named = {
    'dockerfile': 'dockerfile',
    'containerfile': 'dockerfile',
    'makefile': 'makefile',
    'gemfile': 'rb',
    'rakefile': 'rb',
  };

  /// Related extensions that share a glyph when the package has no key of
  /// their own. Looked up after the exact `file.<ext>`, so a theme that
  /// ships `file.scss` still wins over `file.css`.
  static const _alias = {
    'bash': 'sh',
    'zsh': 'sh',
    'pyi': 'py',
    'pyw': 'py',
    'mjs': 'js',
    'cjs': 'js',
    'jsx': 'js',
    'tsx': 'ts',
    'mts': 'ts',
    'cts': 'ts',
    'yaml': 'yml',
    'markdown': 'md',
    'mdx': 'md',
    'htm': 'html',
    'scss': 'css',
    'sass': 'css',
    'less': 'css',
    'cc': 'cpp',
    'cxx': 'cpp',
    'hpp': 'cpp',
    'hh': 'cpp',
    'h': 'c',
    'kts': 'kt',
    'exs': 'ex',
    'hrl': 'erl',
    'pm': 'pl',
    'gql': 'graphql',
    'gitattributes': 'gitignore',
    'gitmodules': 'gitignore',
    'crt': 'pem',
    'cer': 'pem',
    'key': 'pem',
  };

  static final _segment = RegExp(r'^[a-z][a-z0-9]*$');

  static String keyOf({
    required String name,
    required bool isDir,
    required bool isLink,
  }) {
    if (isDir) return dir;
    if (isLink) return link;
    return forName(name) ?? fallback;
  }

  /// `file.py` for `app.py`, `file.gitignore` for `.gitignore`, or null
  /// when the name has no well-formed extension a theme key can carry.
  static String? forName(String name) {
    final base = name.split('/').last.toLowerCase();
    if (base.isEmpty || base == '.' || base == '..') return null;
    if (_named[base] case final mapped?) return 'file.$mapped';
    final dot = base.lastIndexOf('.');
    final String ext;
    if (dot == 0) {
      ext = base.substring(1);
    } else if (dot > 0 && dot < base.length - 1) {
      ext = base.substring(dot + 1);
    } else {
      return null;
    }
    if (!_segment.hasMatch(ext)) return null;
    return 'file.$ext';
  }

  /// Another `file.*` key to try when [key] is missing from the package.
  static String? aliasOf(String key) {
    if (!key.startsWith('file.')) return null;
    final to = _alias[key.substring(5)];
    if (to == null) return null;
    return 'file.$to';
  }

  /// Glyph drawn when the theme has no image for [key]. Distinct by
  /// extension, so the Files window is not a wall of the same document icon.
  static (IconData, Color?) builtIn(String key) {
    var k = key;
    if (!_builtIn.containsKey(k)) k = aliasOf(k) ?? k;
    return _builtIn[k] ?? _builtIn[fallback]!;
  }

  static const _builtIn = <String, (IconData, Color?)>{
    dir: (Icons.folder_open, null),
    link: (Icons.link, null),
    fallback: (Icons.insert_drive_file, null),
    'file.py': (FontAwesome.python_brand, Color(0xFF3776AB)),
    'file.rs': (FontAwesome.rust_brand, Color(0xFFDEA584)),
    'file.js': (FontAwesome.js_brand, Color(0xFFF7DF1E)),
    'file.ts': (FontAwesome.js_brand, Color(0xFF3178C6)),
    'file.go': (FontAwesome.golang_brand, Color(0xFF00ADD8)),
    'file.html': (FontAwesome.html5_brand, Color(0xFFE34F26)),
    'file.css': (FontAwesome.css3_brand, Color(0xFF1572B6)),
    'file.md': (FontAwesome.markdown_brand, Color(0xFF519ABA)),
    'file.sh': (FontAwesome.terminal_solid, Color(0xFF89E051)),
    'file.dockerfile': (FontAwesome.docker_brand, Color(0xFF2496ED)),
    'file.php': (FontAwesome.php_brand, Color(0xFF777BB4)),
    'file.java': (FontAwesome.java_brand, Color(0xFFEA2D2E)),
    'file.swift': (FontAwesome.swift_brand, Color(0xFFF05138)),
    'file.vue': (FontAwesome.vuejs_brand, Color(0xFF42B883)),
    'file.gitignore': (FontAwesome.git_brand, Color(0xFFF05032)),
    'file.json': (Icons.data_object, Color(0xFFF5DE19)),
    'file.yml': (Icons.data_object, Color(0xFFCB171E)),
    'file.xml': (Icons.code, Color(0xFFE37933)),
    'file.sql': (FontAwesome.database_solid, Color(0xFF336791)),
    'file.conf': (Icons.settings, Color(0xFF009900)),
    'file.toml': (Icons.settings, Color(0xFF9C4221)),
    'file.ini': (Icons.settings, null),
    'file.cfg': (Icons.settings, null),
    'file.lock': (FontAwesome.lock_solid, Color(0xFFE5C07B)),
    'file.pem': (FontAwesome.key_solid, Color(0xFFE5C07B)),
    'file.log': (FontAwesome.file_lines_solid, null),
    'file.txt': (FontAwesome.file_lines_solid, null),
    'file.png': (FontAwesome.file_image_solid, Color(0xFFC679DD)),
    'file.jpg': (FontAwesome.file_image_solid, Color(0xFFC679DD)),
    'file.jpeg': (FontAwesome.file_image_solid, Color(0xFFC679DD)),
    'file.gif': (FontAwesome.file_image_solid, Color(0xFFC679DD)),
    'file.webp': (FontAwesome.file_image_solid, Color(0xFFC679DD)),
    'file.svg': (FontAwesome.file_image_solid, Color(0xFFFFB13B)),
    'file.mp4': (FontAwesome.file_video_solid, Color(0xFFE06C75)),
    'file.mkv': (FontAwesome.file_video_solid, Color(0xFFE06C75)),
    'file.webm': (FontAwesome.file_video_solid, Color(0xFFE06C75)),
    'file.mp3': (FontAwesome.file_audio_solid, Color(0xFF98C379)),
    'file.wav': (FontAwesome.file_audio_solid, Color(0xFF98C379)),
    'file.flac': (FontAwesome.file_audio_solid, Color(0xFF98C379)),
    'file.zip': (FontAwesome.file_zipper_solid, Color(0xFFE5C07B)),
    'file.gz': (FontAwesome.file_zipper_solid, Color(0xFFE5C07B)),
    'file.tar': (FontAwesome.file_zipper_solid, Color(0xFFE5C07B)),
    'file.pdf': (FontAwesome.file_pdf_solid, Color(0xFFE5252A)),
    'file.rb': (Icons.code, Color(0xFFCC342D)),
    'file.dart': (Icons.code, Color(0xFF0175C2)),
    'file.kt': (Icons.code, Color(0xFF7F52FF)),
    'file.c': (Icons.code, Color(0xFFA8B9CC)),
    'file.cpp': (Icons.code, Color(0xFF00599C)),
    'file.lua': (Icons.code, Color(0xFF000080)),
  };
}

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
  /// chooses to ship. The editor schema matches this rather than listing
  /// extensions.
  static final keyPattern = RegExp(r'^file\.[a-z][a-z0-9]*$');

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
}

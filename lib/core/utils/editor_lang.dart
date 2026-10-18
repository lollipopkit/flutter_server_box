import 'package:fl_lib/fl_lib.dart';

/// JSON-shaped files that are not named `.json`.
const _jsonLikeSuffixes = {
  'json',
  'jsonc',
  'json5',
  'jsonl',
  'ndjson',
  'geojson',
  'webmanifest',
  'har',
};

/// systemd unit types from `systemd.unit(5)`. The files are INI
/// (`[Unit]`, `[Service]`, `Key=value`).
const _systemdUnitSuffixes = {
  'service',
  'socket',
  'device',
  'mount',
  'automount',
  'swap',
  'target',
  'path',
  'timer',
  'slice',
  'scope',
};

/// INI-shaped config that `ProgLang` does not list.
const _iniLikeSuffixes = {
  'cfg',
  'cnf',
  'toml',
  'desktop',
  'network',
  'netdev',
  'link',
  'nspawn',
  'container',
  'volume',
  'pod',
  'kube',
  'image',
};

/// XML-shaped markup that `ProgLang` does not list.
const _xmlLikeSuffixes = {
  'html',
  'htm',
  'svg',
  'plist',
  'xsd',
  'xsl',
  'xslt',
  'xhtml',
};

const _shellLikeSuffixes = {
  'ksh',
  'csh',
  'fish',
  'bash',
};

const _powershellLikeSuffixes = {
  'psm1',
  'psd1',
};

/// Whole filenames, lowercased. `.bashrc` has its only dot at index 0, so
/// suffix matching never sees `bashrc`.
const _langByFileName = {
  '.bashrc': ProgLang.shell,
  'bashrc': ProgLang.shell,
  '.zshrc': ProgLang.shell,
  '.zshenv': ProgLang.shell,
  '.zprofile': ProgLang.shell,
  '.profile': ProgLang.shell,
  '.bash_profile': ProgLang.shell,
  '.bash_aliases': ProgLang.shell,
  '.kshrc': ProgLang.shell,
  '.cshrc': ProgLang.shell,
  '.env': ProgLang.properties,
  '.gitconfig': ProgLang.ini,
  '.gitmodules': ProgLang.ini,
  '.htaccess': ProgLang.apache,
  '.vimrc': ProgLang.vim,
  'vimrc': ProgLang.vim,
  'sshd_config': ProgLang.apache,
  'ssh_config': ProgLang.apache,
  'dockerfile': ProgLang.dockerfile,
  'makefile': ProgLang.makefile,
  'gnumakefile': ProgLang.makefile,
  'vagrantfile': ProgLang.ruby,
  'gemfile': ProgLang.ruby,
};

/// The highlighter for a path opened in the file editor.
///
/// [ProgLang.parseFileName] matches suffixes as they are spelled in the
/// enum, so `package.JSON` is not `json`. A second look lowercases the
/// name, maps JSON-shaped and systemd / INI / XML / shell names, then
/// retries the enum with a lowercased suffix.
ProgLang? editorLangFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final name = path.split(RegExp(r'[/\\]')).last;
  final byName = ProgLang.parseFileName(name);
  if (byName != null) return byName;
  final lower = name.toLowerCase();
  final byFile = _langByFileName[lower];
  if (byFile != null) return byFile;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_jsonLikeSuffixes.contains(ext)) return ProgLang.json;
  if (_systemdUnitSuffixes.contains(ext) || _iniLikeSuffixes.contains(ext)) {
    return ProgLang.ini;
  }
  if (_xmlLikeSuffixes.contains(ext)) return ProgLang.xml;
  if (_shellLikeSuffixes.contains(ext)) return ProgLang.shell;
  if (_powershellLikeSuffixes.contains(ext)) return ProgLang.powershell;
  if (ext == 'env') return ProgLang.properties;
  return ProgLang.parseFileName('file.$ext');
}

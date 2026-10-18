import 'package:fl_lib/fl_lib.dart';

/// Markdown names that [ProgLang.markdown] does not list (`md`, `markdown`).
const _markdownLikeSuffixes = {
  'mdown',
  'mkd',
  'mdwn',
};

/// The highlighter for a path opened in the file editor.
///
/// [ProgLang.parseFileName] matches suffixes as they are spelled in the
/// enum, so `README.MD` is not markdown. A second look lowercases the
/// suffix, maps extra Markdown names, then retries the enum.
ProgLang? editorLangFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final name = path.split(RegExp(r'[/\\]')).last;
  final byName = ProgLang.parseFileName(name);
  if (byName != null) return byName;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (_markdownLikeSuffixes.contains(ext)) return ProgLang.markdown;
  return ProgLang.parseFileName('file.$ext');
}

/// Whether the file editor should offer a rendered Markdown view.
bool editorIsMarkdown({ProgLang? lang, String? path}) {
  return (lang ?? editorLangFor(path)) == ProgLang.markdown;
}

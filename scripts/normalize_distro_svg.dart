// Strips from `assets/distro/*.svg` the two elements flutter_svg does not
// draw and warns about on every load:
//
//   flutter: unhandled element <metadata/>; Picture key: Svg loader
//   flutter: unhandled element <defs/>; Picture key: Svg loader
//
// The files are otherwise byte-identical to font-logos' `vectors/`, and that
// is worth keeping — `diff` against upstream is how a glyph's provenance is
// checked. So this is a separate, repeatable step rather than a hand edit:
// copy the file in, run this, commit both.
//
//   dart run scripts/normalize_distro_svg.dart            # rewrite in place
//   dart run scripts/normalize_distro_svg.dart --check    # fail if any is stale
//   dart run scripts/normalize_distro_svg.dart --dir=DIR  # somewhere else
//
// `--dir` is how provenance is checked now that a plain `diff` against
// upstream no longer matches: normalise a copy of font-logos' `vectors/` and
// compare that against what is shipped.
//
// `--check` is what `test/dist_icon_test.dart` asserts the equivalent of, so a
// file copied in raw is caught by `flutter test` rather than by noticing the
// log line months later.
//
// ## What is removed, and why it is safe
//
// **`<metadata>`** is Inkscape's RDF block. In this set it does not describe
// the file it is in: `elementary.svg` carries Gentoo's, `voidlinux.svg`
// carries AOSC's, and `artix.svg` claims CC BY-NC-SA — all inherited from
// whatever document the glyph was traced in. None of it is the licence this
// repository relies on, which is font-logos' Unlicense over the redrawn
// glyphs; see `assets/distro/README.md`. Shipping a file that misattributes
// itself is worse than shipping one with no metadata at all.
//
// **`<defs>`** holds gradients, patterns and `inkscape:perspective` nodes that
// nothing in these files references — they are single-colour glyphs, and the
// app tints them flat anyway. A `<defs>` that *is* referenced is left alone
// and reported, so this can never silently break a glyph.

import 'dart:io';

const _dir = 'assets/distro';

/// `<metadata>…</metadata>` and `<defs>…</defs>`, including the self-closing
/// forms. Not nestable in practice, and these files are machine-generated.
final _blocks = {
  'metadata': RegExp(r'[ \t]*<metadata\b[^>]*(?:/>|>.*?</metadata>)\n?', dotAll: true),
  'defs': RegExp(r'[ \t]*<defs\b[^>]*(?:/>|>.*?</defs>)\n?', dotAll: true),
};

/// Ids referenced from outside [within] — `fill="url(#a)"`, `href="#a"`.
///
/// Outside, because a `<defs>` whose only referents are inside itself is still
/// dead: `puppy.svg` was exactly that, a CSS block naming gradients that no
/// drawn element used.
Set<String> _referencedIds(String svg, String within) {
  final rest = svg.replaceFirst(within, '');
  return {
    for (final m in RegExp(r'url\(#([^)]+)\)').allMatches(rest)) m.group(1)!,
    for (final m in RegExp(r'href="#([^"]+)"').allMatches(rest)) m.group(1)!,
  };
}

Set<String> _declaredIds(String block) => {
  for (final m in RegExp(r'\bid="([^"]+)"').allMatches(block)) m.group(1)!,
};

/// CSS class names a `<style>` inside [block] defines rules for, and that
/// something outside it actually carries.
///
/// flutter_svg applies no CSS, so such a rule is already not being drawn — but
/// it is a rule someone wrote, and deleting it here would decide silently what
/// the glyph looks like. Reported instead, to be resolved into a presentation
/// attribute by hand. `puppy.svg` was the one file this applied to.
Set<String> _liveClasses(String svg, String block) {
  if (!block.contains('<style')) return const {};
  final rest = svg.replaceFirst(block, '');
  final used = {
    for (final m in RegExp(r'class="([^"]*)"').allMatches(rest))
      ...m.group(1)!.split(RegExp(r'\s+')),
  };
  return {
    for (final m in RegExp(r'\.([A-Za-z_][\w-]*)\s*\{').allMatches(block))
      if (used.contains(m.group(1))) m.group(1)!,
  };
}

/// The normalised form of [svg], or the input unchanged.
///
/// [skipped] collects anything that had to be kept, so the caller can say so
/// rather than leaving the file quietly half-done.
String normalize(String svg, {List<String>? skipped}) {
  for (final entry in _blocks.entries) {
    for (;;) {
      final match = entry.value.firstMatch(svg);
      if (match == null) break;
      final block = match.group(0)!;
      if (entry.key == 'defs') {
        final live = _declaredIds(block).intersection(_referencedIds(svg, block));
        if (live.isNotEmpty) {
          skipped?.add('kept <defs>, still referenced (${live.join(', ')})');
          break;
        }
        final classes = _liveClasses(svg, block);
        if (classes.isNotEmpty) {
          skipped?.add(
            'kept <defs>, its <style> has rules in use (.${classes.join(', .')}) — '
            'resolve them into attributes on the elements first',
          );
          break;
        }
      }
      svg = svg.replaceFirst(block, '');
    }
  }

  // A `class` with no stylesheet left to resolve it. Inert in every renderer,
  // and upstream ships a few (`mx.svg`); removed so that a `class` in this
  // directory always means a stylesheet is present and being ignored.
  if (!svg.contains('<style')) {
    svg = svg.replaceAll(RegExp(r'\s+class="[^"]*"'), '');
  }
  return svg;
}

void main(List<String> args) {
  final check = args.contains('--check');
  final target =
      args.firstWhere((a) => a.startsWith('--dir='), orElse: () => '--dir=$_dir').substring(6);
  final dir = Directory(target);
  if (!dir.existsSync()) {
    stderr.writeln(
      target == _dir ? 'run this from the repository root: $_dir not found' : '$target not found',
    );
    exit(2);
  }

  final stale = <String>[];
  var needsHand = false;
  var rewritten = 0;
  final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final before = file.readAsStringSync();
    final skipped = <String>[];
    final after = normalize(before, skipped: skipped);
    for (final note in skipped) {
      stdout.writeln('${file.path}: $note');
      needsHand = true;
    }
    if (after == before) continue;
    if (check) {
      stale.add(file.path);
    } else {
      file.writeAsStringSync(after);
      rewritten++;
    }
  }

  if (check && stale.isNotEmpty) {
    stderr.writeln('${stale.length} file(s) carry <metadata>/<defs>:');
    for (final path in stale) {
      stderr.writeln('  $path');
    }
    stderr.writeln('run: dart run scripts/normalize_distro_svg.dart');
    exit(1);
  }
  // A file this could not finish is not normalised either, and saying "all
  // normalised" after printing why one was skipped would be the report
  // contradicting itself.
  if (needsHand) exit(1);
  stdout.writeln(check ? 'all ${files.length} normalised' : 'rewrote $rewritten of ${files.length}');
}

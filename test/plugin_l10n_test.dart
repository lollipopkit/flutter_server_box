/// The bundled plugins' translations, as the app would read them.
///
/// Three things can each break this on their own and none of them fails
/// anything else: a key used in `plugin.js` and missing from `l10n/en.json`
/// draws `l10n.thatKey` on screen, a locale declared in the manifest with no
/// file behind it falls back silently, and a `.sbp` built without the
/// translations installs an English-only plugin from a directory that had
/// them — which is what the packer did until it was fixed, back when each
/// plugin carried its own copy of it (now `packages/plugin-tools`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/plugin/l10n.dart';

const _plugins = [
  'packages/plugins/disk-usage',
  'packages/plugins/listening-ports',
  'packages/plugins/scheduled',
];

/// Every key the plugin's own source asks for.
///
/// Read from `src/`, not from `dist/plugin.js`: the bundler renames imported
/// functions, so `l10n("measuring")` is `n("measuring")` by the time it is
/// built and no honest pattern finds it there.
Set<String> _keysUsedIn(String dir) {
  final out = <String>{};
  // Every quoted literal in *key position* inside an `l10n(...)` call.
  //
  // Not just the first argument: `l10n(off ? "a" : "b")` is how a key gets
  // chosen half the time, and a pattern anchored to the front sees neither of
  // them — which would let exactly the conditional keys go missing while this
  // stayed green.
  //
  // And not every literal either: the *condition* has its own, and
  // `l10n(sortBy === "size" ? "sortSize" : "sortName")` would report `size` as
  // a key nobody translated. So where there is a `?`, only what follows it
  // counts. The ports plugin passed this by luck for one build — it happens to
  // have a key called `port` — which is the kind of green that means nothing.
  final call = RegExp(r'\bl10n\(([^)]*)\)');
  final literal = RegExp(r'''["']([A-Za-z0-9_]+)["']''');
  for (final file in Directory('$dir/src').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.ts')) continue;
    for (final m in call.allMatches(file.readAsStringSync())) {
      final args = m.group(1)!;
      final at = args.indexOf('?');
      for (final k in literal.allMatches(at < 0 ? args : args.substring(at))) {
        out.add(k.group(1)!);
      }
    }
  }
  return out;
}

void main() {
  for (final dir in _plugins) {
    final name = dir.split('/').last;

    group(name, () {
      final manifest =
          jsonDecode(File('$dir/manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      final locales = (manifest['l10n'] as List).cast<String>();

      test('every locale it declares has a file', () {
        expect(locales, contains('en'), reason: 'en is the fallback');
        for (final locale in locales) {
          expect(
            File('$dir/l10n/$locale.json').existsSync(),
            isTrue,
            reason: '$locale is declared and has no file',
          );
        }
      });

      /// A key the bundle names and no file carries is drawn as the key
      /// itself — visible, ugly, and nothing else notices.
      test('every key the bundle uses is translated', () {
        final used = _keysUsedIn(dir);
        expect(used, isNotEmpty, reason: 'no translated strings at all?');

        for (final locale in locales) {
          final table = PluginL10n.parse(
            File('$dir/l10n/$locale.json').readAsStringSync(),
          );
          expect(
            used.difference(table.keys.toSet()),
            isEmpty,
            reason: '$locale is missing keys the bundle uses',
          );
        }
      });

      /// A key nothing asks for is a string somebody will translate for
      /// nothing, and one that was renamed leaves its old spelling behind.
      test('it carries no key nothing uses', () {
        final used = _keysUsedIn(dir);
        final have = PluginL10n.parse(
          File('$dir/l10n/en.json').readAsStringSync(),
        ).keys.toSet();

        expect(have.difference(used), isEmpty);
      });

      /// Every locale says the same things, or switching language turns some
      /// of the interface back into English without saying so.
      test('the locales carry the same keys', () {
        final en = PluginL10n.parse(
          File('$dir/l10n/en.json').readAsStringSync(),
        ).keys.toSet();
        for (final locale in locales.where((l) => l != 'en')) {
          final other = PluginL10n.parse(
            File('$dir/l10n/$locale.json').readAsStringSync(),
          ).keys.toSet();
          expect(other, en, reason: '$locale and en disagree');
        }
      });

      /// The packer left these out entirely until it was fixed, so a plugin
      /// installed from a `.sbp` was English-only while the same directory
      /// installed as a development plugin was not.
      test('the package carries them', () {
        final sbp = Directory('$dir/dist')
            .listSync()
            .whereType<File>()
            .firstWhere((f) => f.path.endsWith('.sbp'));

        final package = PluginPackage.read(sbp.readAsBytesSync());

        expect(package.l10n.keys, unorderedEquals(locales));
        for (final locale in locales) {
          expect(package.l10n[locale], isNotEmpty);
        }
      });
    });
  }
}

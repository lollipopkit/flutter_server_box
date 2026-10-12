import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/provider/app/keybindings.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

void main() {
  group('chord', () {
    test('reads modifiers and the key', () {
      final a = KbChord.activator(r'Ctrl+Alt+\')!;
      expect(a.trigger, LogicalKeyboardKey.backslash);
      expect(a.control && a.alt && !a.meta && !a.shift, isTrue);
      expect(KbChord.activator('Ctrl+Meta+←')!.trigger,
          LogicalKeyboardKey.arrowLeft);
      expect(KbChord.activator('Ctrl+Alt+Shift+T')!.shift, isTrue);
    });

    test('refuses what it cannot bind', () {
      expect(KbChord.activator(''), isNull);
      expect(KbChord.activator('Ctrl+1…9'), isNull);
      expect(KbChord.activator('Hyper+P'), isNull);
    });

    test('caps follow the keyboard', () {
      expect(KbChord.label(r'Ctrl+Meta+\', KbPlatform.mac), r'⌃⌘\');
      expect(KbChord.label('Ctrl+Alt+P', KbPlatform.pc), 'Ctrl+Alt+P');
      expect(KbChord.label('Escape', KbPlatform.pc), 'Esc');
    });

    test('every default parses, but the fixed range', () {
      for (final c in KbCommand.values) {
        for (final p in KbPlatform.values) {
          final parsed = KbChord.activator(c.defaultFor(p));
          expect(parsed == null, c.fixed, reason: '${c.id} on ${p.name}');
        }
      }
    });

    test('defaults do not collide within a scope', () {
      for (final p in KbPlatform.values) {
        final seen = <String>{};
        for (final c in KbCommand.values) {
          final scopes = c.scope == KbScope.global
              ? KbScope.values
              : [c.scope];
          for (final s in scopes) {
            expect(
              seen.add('${s.name} ${c.defaultFor(p)}'),
              isTrue,
              reason: '${c.id} on ${p.name}',
            );
          }
        }
      }
    });
  });

  group('overrides', () {
    late ProviderContainer container;

    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await getIt.reset();
      await closeTestDb();
    });

    KbState kb() => container.read(keybindingsProvider);
    Keybindings ops() => container.read(keybindingsProvider.notifier);

    test('binding takes the chord from a command in the same scope', () {
      final quick = kb().chordOf(KbCommand.wsQuickOpen);
      ops().bind(KbCommand.wsSplitRight, quick);
      expect(kb().chordOf(KbCommand.wsSplitRight), quick);
      expect(kb().chordOf(KbCommand.wsQuickOpen), isEmpty);
      expect(kb().activatorOf(KbCommand.wsQuickOpen), isNull);
    });

    test('a chord in another scope is no conflict', () {
      final list = kb().chordOf(KbCommand.serverList);
      expect(kb().conflictsOf(KbCommand.wsSync, list), isEmpty);
    });

    test('bound back to the default is no change', () {
      ops().bind(KbCommand.wsSync, 'Ctrl+Alt+Y');
      expect(kb().isModified(KbCommand.wsSync), isTrue);
      ops().bind(KbCommand.wsSync, KbCommand.wsSync.defaultFor(kb().platform));
      expect(kb().isModified(KbCommand.wsSync), isFalse);
    });

    test('survives a restart, and leaves the other platform alone', () {
      final other = KbPlatform.values.firstWhere((p) => p != kb().platform);
      Stores.setting.keybindings.put({'${other.name}:ws.sync': 'F9'});
      ops().bind(KbCommand.wsSync, 'F8');
      final again = ProviderContainer();
      addTearDown(again.dispose);
      expect(again.read(keybindingsProvider).chordOf(KbCommand.wsSync), 'F8');
      expect(
        Stores.setting.keybindings.fetch()['${other.name}:ws.sync'],
        'F9',
      );
      ops().resetAll();
      expect(kb().overrides, isEmpty);
      expect(
        Stores.setting.keybindings.fetch()['${other.name}:ws.sync'],
        'F9',
      );
    });
  });
}

/// The feature registry: one declaration per entry, one rule for what an
/// upgrade adds, and one id space for all three surfaces.
///
/// What it replaced was three lists in three shapes with three copies of that
/// rule, which is why most of these are about the properties that hold across
/// slots rather than about any one of them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

void main() {
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  group('what is declared', () {
    test('every slot has entries, and each knows which slot it is in', () {
      for (final slot in FeatureSlot.values) {
        final features = Features.of(slot);
        expect(features, isNotEmpty, reason: '$slot');
        expect(features.every((f) => f.slot == slot), isTrue, reason: '$slot');
      }
    });

    // Ids are stored, travel through a backup and a sync, and are what a
    // plugin's contribution will be keyed by. Two entries sharing one in a
    // slot would make an arrangement ambiguous.
    test('ids are unique within a slot and never empty', () {
      for (final slot in FeatureSlot.values) {
        final ids = Features.of(slot).map((f) => f.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: '$slot: $ids');
        expect(ids.every((id) => id.isNotEmpty), isTrue, reason: '$slot');
      }
    });

    test('the built-in entries are exactly the three enums', () {
      expect(
        Features.of(FeatureSlot.funcBtn).map((f) => f.id),
        ServerFuncBtn.values.map((e) => e.id),
      );
      expect(
        Features.of(FeatureSlot.detailCard).map((f) => f.id),
        ServerDetailCards.values.map((e) => e.name),
      );
      expect(
        Features.of(FeatureSlot.homeTab).map((f) => f.id),
        AppTab.values.map((e) => e.name),
      );
    });

    test('byId finds one and answers null for anything else', () {
      expect(
        Features.byId(FeatureSlot.funcBtn, ServerFuncBtn.power.id)?.slot,
        FeatureSlot.funcBtn,
      );
      // A card's id is not a button's, even where the name would be.
      expect(Features.byId(FeatureSlot.funcBtn, 'cpu'), isNull);
      expect(Features.byId(FeatureSlot.funcBtn, 'app.plugin:nothing'), isNull);
    });

    // A boundary reaches an upgrading install and the defaults reach a fresh
    // one. An entry with a boundary and no default place would arrive
    // everywhere except a new install, which is the one combination nobody is
    // asking for. The reverse is fine and is what `iperf` is: no boundary and
    // no default place means it waits until the user goes looking.
    test('an entry with a release boundary has a default place', () {
      for (final slot in FeatureSlot.values) {
        final defaults = slot.defaultIds.toSet();
        for (final f in Features.of(slot)) {
          if (f.since == null) continue;
          expect(
            defaults,
            contains(f.id),
            reason: '$slot: ${f.id} has a boundary but no default place',
          );
        }
      }
    });

    test('every default names an entry that exists', () {
      for (final slot in FeatureSlot.values) {
        final ids = Features.of(slot).map((f) => f.id).toSet();
        expect(ids, containsAll(slot.defaultIds), reason: '$slot');
      }
    });
  });

  group('what an upgrade adds', () {
    test('one pass reaches every slot', () {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.id]);
      setting.detailCardOrder.put([ServerDetailCards.about.name]);

      // A window wide enough to contain both slots' newest boundaries.
      Features.autoAdd(1000, 1600);

      expect(setting.serverFuncBtns.get(), contains(ServerFuncBtn.power.id));
      expect(
        setting.detailCardOrder.get(),
        contains(ServerDetailCards.bmc.name),
      );
    });

    test('a slot with nothing new is not rewritten', () {
      // Home tabs carry no boundaries, so nothing here may touch them.
      Features.autoAdd(1000, 1600);

      expect(
        setting.get<List>('homeTabs'),
        isNull,
        reason: 'nothing was written, so the defaults still apply',
      );
    });
  });

  group('what is stored', () {
    // PLUGINS.md section 7: an unclaimed id is ignored when the list is read
    // and carried when it is written. A plugin that is not installed right now
    // has no entry, and dropping its id would lose where the user put it.
    test('an id this build has nothing for survives a write', () {
      FeatureSlot.funcBtn.putEnabledIds([
        ServerFuncBtn.terminal.id,
        'app.serverbox.zfs:zfs',
      ]);

      expect(FeatureSlot.funcBtn.enabledIds(), [
        ServerFuncBtn.terminal.id,
        'app.serverbox.zfs:zfs',
      ]);
    });

    test('a repeat does not', () {
      FeatureSlot.detailCard.putEnabledIds(['cpu', 'mem', 'cpu']);

      expect(FeatureSlot.detailCard.enabledIds(), ['cpu', 'mem']);
    });

    test('each slot reads back what it wrote', () {
      FeatureSlot.funcBtn.putEnabledIds([ServerFuncBtn.files.id]);
      FeatureSlot.detailCard.putEnabledIds([ServerDetailCards.net.name]);
      FeatureSlot.homeTab.putEnabledIds([AppTab.ssh.name, AppTab.server.name]);

      expect(FeatureSlot.funcBtn.enabledIds(), [ServerFuncBtn.files.id]);
      expect(FeatureSlot.detailCard.enabledIds(), [
        ServerDetailCards.net.name,
      ]);
      expect(FeatureSlot.homeTab.enabledIds(), [
        AppTab.ssh.name,
        AppTab.server.name,
      ]);
    });
  });
}

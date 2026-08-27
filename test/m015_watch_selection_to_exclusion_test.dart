/// The step that inverts the watch's server selection.
///
/// It gets one pass over a user's records and is not repeatable, and what it
/// decides is not cosmetic: get it wrong in one direction and servers the user
/// never chose appear on their wrist, each with a credential minted for it; get
/// it wrong in the other and the watch goes blank for someone who had it
/// working. Neither shows up as a crash.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/store/migrations/m015_watch_selection_to_exclusion.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
    // Explicit rather than relying on the fresh database, so no test here
    // depends on running after another one. `SettingStore` is a singleton and
    // the empty case below is the one that would silently pass for the wrong
    // reason if a previous test's selection were still readable.
    SettingStore.instance.watchServerIds.put([]);
    SettingStore.instance.watchExcludedServerIds.put([]);
  });
  tearDown(closeTestDb);

  void seedMonitorServer(String id, String name) {
    ServerStore().put(
      spiFixture(
        name: name,
        id: id,
      ).copyWith(monitorHttp: MonitorHttpCredential(addr: 'https://$id:3770')),
    );
  }

  void seedSshServer(String id, String name) {
    ServerStore().put(spiFixture(name: name, id: id, ip: '10.0.0.1'));
  }

  List<String> excluded() =>
      SettingStore.instance.watchExcludedServerIds.fetch();

  test('an explicit selection becomes its inverse', () async {
    // The case this migration exists for. Two of three were chosen; after it
    // the watch must still show those two and no more — the third is held
    // back, rather than joining them because the default changed underneath.
    seedMonitorServer('a', 'A');
    seedMonitorServer('b', 'B');
    seedMonitorServer('c', 'C');
    SettingStore.instance.watchServerIds.put(['a', 'b']);

    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), ['c']);
  });

  test('an empty selection stays empty, so everything syncs', () async {
    // Indistinguishable from a deliberate "none", and the two are not equally
    // likely: empty is what an install that never opened the watch settings
    // looks like. Excluding everything would leave the new default switched
    // off for someone who was never asked, and there is no signal to tell them
    // it happened.
    seedMonitorServer('a', 'A');
    seedMonitorServer('b', 'B');

    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), isEmpty);
  });

  test('an SSH-only server is not excluded', () async {
    // It could never have been selected, so it is not something the user
    // declined. Writing it down would be a row that means nothing — until the
    // server gains an agent one day and is the only one mysteriously missing.
    seedMonitorServer('a', 'A');
    seedSshServer('ssh', 'SSH only');
    SettingStore.instance.watchServerIds.put(['a']);

    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), isEmpty);
  });

  test('a selected server that no longer exists costs nothing', () async {
    // A selection outlives the server it named — the id is simply absent from
    // the store. Nothing should be excluded on its account.
    seedMonitorServer('a', 'A');
    SettingStore.instance.watchServerIds.put(['a', 'deleted']);

    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), isEmpty);
  });

  test('selecting every server excludes none', () async {
    seedMonitorServer('a', 'A');
    seedMonitorServer('b', 'B');
    SettingStore.instance.watchServerIds.put(['a', 'b']);

    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), isEmpty);
  });

  test('runs again without widening what it decided', () async {
    // The version is recorded only once the step has run, so a process stopped
    // partway means the whole thing runs again. The second pass reads the same
    // `watchServerIds` — which this step deliberately does not clear — and has
    // to reach the same answer.
    seedMonitorServer('a', 'A');
    seedMonitorServer('b', 'B');
    SettingStore.instance.watchServerIds.put(['a']);

    await const WatchSelectionToExclusionMigration().apply();
    await const WatchSelectionToExclusionMigration().apply();

    expect(excluded(), ['b']);
  });
}

/// What the app records about a plugin, and what it deliberately does not.
///
/// The store behind the report. Its whole job is to answer, a week after the
/// fact, which of three things happened — the collection did not run, the
/// plugin threw, or what it drew never landed — without having kept anything
/// the user would not want published.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/store/plugin_health.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PluginHealthStore store;

  setUp(() async {
    await openTestDb();
    store = PluginHealthStore('plugin_health_test');
    await store.init();
  });
  tearDown(closeTestDb);

  PluginEvent event({
    PluginStage stage = PluginStage.open,
    String? failure,
    int ms = 12,
  }) => PluginEvent(
    stage: stage,
    at: DateTime.now(),
    elapsed: Duration(milliseconds: ms),
    failure: failure,
  );

  test('a plugin nothing has happened to has an empty record', () {
    final one = store.fetch('app.serverbox.zfs');

    expect(one.isEmpty, isTrue);
    expect(one.failuresSinceOk, 0);
  });

  test('what was recorded reads back', () {
    store.record('app.serverbox.zfs', event(ms: 41));

    final one = store.fetch('app.serverbox.zfs');
    expect(one.lastOk?.stage, PluginStage.open);
    expect(one.lastOk?.elapsed, const Duration(milliseconds: 41));
    expect(one.lastOk?.ok, isTrue);
  });

  /// **Both, not the most recent of the two.** A plugin whose page opens and
  /// whose collection fails is a different report from one that will not load,
  /// and keeping only the latest makes them read the same.
  test('a success does not erase the last failure', () {
    store.record('a', event(stage: PluginStage.exec, failure: 'timeout'));
    store.record('a', event(stage: PluginStage.open));

    final one = store.fetch('a');
    expect(one.lastOk?.stage, PluginStage.open);
    expect(one.lastFailure?.stage, PluginStage.exec);
    expect(one.lastFailure?.failure, 'timeout');
  });

  /// One failure is a server that was asleep; forty is a plugin that has not
  /// worked since it was updated, and the difference is the first thing worth
  /// knowing.
  test('failures in a row are counted, and a success clears the count', () {
    for (var i = 0; i < 3; i++) {
      store.record('a', event(failure: 'threw'));
    }
    expect(store.fetch('a').failuresSinceOk, 3);

    store.record('a', event());

    expect(store.fetch('a').failuresSinceOk, 0);
  });

  test('two plugins are two records', () {
    store.record('a', event(failure: 'threw'));
    store.record('b', event());

    expect(store.fetch('a').lastFailure, isNotNull);
    expect(store.fetch('b').lastFailure, isNull);
    expect(store.readAll().keys, containsAll(<String>['a', 'b']));
  });

  test('uninstalling a plugin takes its record', () {
    store.record('a', event());

    store.removePlugin('a');

    expect(store.fetch('a').isEmpty, isTrue);
  });

  /// **This is not a user edit and must not look like one.** `lastModTime` is
  /// what sync reads to decide which device holds the newer copy of
  /// everything, and a plugin failing on a phone in a pocket is not a reason
  /// for that phone to win.
  test('recording does not move the clock a sync reads', () async {
    final before = store.lastUpdateTs;

    store.record('a', event(failure: 'threw'));

    expect(store.lastUpdateTs, before);
  });

  /// The three things "the plugin does nothing" turns out to be. An author
  /// acts on each differently, which is the whole reason a stage is recorded.
  test('every stage says which of the three kinds it is', () {
    expect(PluginStage.exec.kind, PluginStageKind.collecting);
    expect(PluginStage.http.kind, PluginStageKind.collecting);
    expect(PluginStage.patch.kind, PluginStageKind.drawing);
    expect(PluginStage.load.kind, PluginStageKind.running);
    expect(PluginStage.hook.kind, PluginStageKind.running);
  });

  /// The names go into a report somebody quotes in an issue. One that moved
  /// with a refactor would make two reports incomparable.
  test('a stage name round-trips', () {
    for (final stage in PluginStage.values) {
      expect(PluginStage.byName(stage.name), stage, reason: stage.name);
    }
  });

  /// A stored record this build cannot read is not a crash: what is lost is a
  /// diagnostic, and refusing to answer would take the rest of the report with
  /// it.
  test('a row that will not decode reads as nothing recorded', () {
    store.set('a', {'ok': 'not an event', 'failures': 'lots'});

    final one = store.fetch('a');
    expect(one.lastOk, isNull);
    expect(one.failuresSinceOk, 0);
  });

  /// Recording is a diagnostic, and a diagnostic that throws is worse than one
  /// that is missing.
  test('recording into a store that is not there does not throw', () {
    expect(
      () => recordPluginEvent(
        'a',
        stage: PluginStage.open,
        elapsed: Duration.zero,
        store: PluginHealthStore('never_opened'),
      ),
      returnsNormally,
    );
  });
}

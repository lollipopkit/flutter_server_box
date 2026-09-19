/// How each tag's own view of the server list is remembered.
///
/// The density was already per tag; the order and the grouping joined it, and
/// the order is the one of the three that had a global setting before — so
/// what has to hold is that an install which chose an order before this
/// existed still opens on that order, and that choosing one for `#prod` does
/// not answer for the list with no tag on it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

void main() {
  const all = '';

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore.instance);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  group('the order', () {
    test('nothing chosen anywhere is the arrangement itself', () {
      expect(ServerSortOrder.of(all).field, ServerSortField.manual);
      expect(ServerSortOrder.of('prod').field, ServerSortField.manual);
    });

    test('a field and a direction survive the round trip', () {
      const order = ServerSortOrder(
        ServerSortField.name,
        ascending: false,
      );
      order.save('prod');

      final got = ServerSortOrder.of('prod');
      expect(got.field, ServerSortField.name);
      expect(got.ascending, isFalse);
      expect(order.isCurrentFor('prod'), isTrue);
    });

    test('one tag\'s answer is not another\'s', () {
      const ServerSortOrder(
        ServerSortField.cpu,
        ascending: true,
      ).save('prod');

      expect(ServerSortOrder.of('prod').field, ServerSortField.cpu);
      // The list with no tag on it was never asked.
      expect(ServerSortOrder.of(all).field, ServerSortField.manual);
      expect(ServerSortOrder.of('staging').field, ServerSortField.manual);
    });

    test('a direction on a field that has none is normalised away', () {
      // `alert` is a partition rather than a comparison, so "descending" is
      // not one of the things the sheet offers — and a direction left behind
      // by the field before it must not make the current one look like one of
      // them.
      const ServerSortOrder(
        ServerSortField.name,
        ascending: false,
      ).save('prod');
      const ServerSortOrder(
        ServerSortField.alert,
        ascending: true,
      ).save('prod');

      expect(ServerSortOrder.of('prod').ascending, isTrue);
    });

    test('what a pre-per-tag install chose is what "all" opens on', () {
      // The two globals this replaced, written the way that build wrote them.
      Stores.setting.serverPageSortBy.put(ServerSortField.uptime.name);
      Stores.setting.serverPageSortAsc.put(false);

      final got = ServerSortOrder.of(all);
      expect(got.field, ServerSortField.uptime);
      expect(got.ascending, isFalse);

      // Only for "all". A tag that install never had a separate answer for
      // gets the default rather than the one it chose for the whole list.
      expect(ServerSortOrder.of('prod').field, ServerSortField.manual);
    });

    test('and choosing again writes to the map, not back to the globals', () {
      Stores.setting.serverPageSortBy.put(ServerSortField.uptime.name);
      const ServerSortOrder(
        ServerSortField.cpu,
        ascending: true,
      ).save(all);

      expect(ServerSortOrder.of(all).field, ServerSortField.cpu);
      expect(
        Stores.setting.serverPageSortBy.fetch(),
        ServerSortField.uptime.name,
      );
    });
  });

  group('the grouping', () {
    test('nothing chosen is one list', () {
      expect(ServerListGrouping.of(all), ServerListGrouping.none);
    });

    test('it is remembered per tag, like the order beside it', () {
      ServerListGrouping.put(all, ServerListGrouping.tag);

      expect(ServerListGrouping.of(all), ServerListGrouping.tag);
      expect(ServerListGrouping.of('prod'), ServerListGrouping.none);
    });

    test('and it is stored by name, so a new case cannot repoint it', () {
      ServerListGrouping.put(all, ServerListGrouping.tag);
      expect(Stores.setting.serverListGroup.fetch()[all], 'tag');

      // A value this build does not know is one list, not a crash.
      Stores.setting.serverListGroup.put({all: 'by-phase-of-the-moon'});
      expect(ServerListGrouping.of(all), ServerListGrouping.none);
    });
  });
}

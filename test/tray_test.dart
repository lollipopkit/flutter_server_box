import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/model/server/server.dart';

/// What the tray shows, without the tray.
///
/// The rows are strings a native menu draws verbatim, so what is worth holding
/// is the text: which glyph a connection reads as, what stands in for a
/// measurement that has not arrived, and when the icon says something is wrong.
void main() {
  group('what a connection reads as', () {
    test('a machine that answered is a dot', () {
      expect(trayStateOf(ServerConn.connected), TrayLineState.ok);
      expect(trayStateOf(ServerConn.finished), TrayLineState.ok);
    });

    test('one on its way is neither up nor down', () {
      expect(trayStateOf(ServerConn.connecting), TrayLineState.working);
      expect(trayStateOf(ServerConn.loading), TrayLineState.working);
    });

    test('and a failure is told from never having tried', () {
      // Different glyphs, because they are different situations: one is a
      // machine that would not answer, the other is one nobody has asked.
      expect(trayStateOf(ServerConn.failed), TrayLineState.failed);
      expect(trayStateOf(ServerConn.disconnected), TrayLineState.offline);
    });
  });

  group('the detail column', () {
    test('is the readings when there are readings', () {
      final detail = trayDetail(
        conn: ServerConn.finished,
        cpuPercent: 12.4,
        memUsedKib: 3 * 1024 * 1024,
        memTotalKib: 8 * 1024 * 1024,
      );

      expect(detail, contains('12%'));
      expect(detail, contains('/'));
    });

    test('and says nothing rather than zero before they arrive', () {
      // A connection that is up with no status parsed yet. `0%` there would be
      // a measurement, and this is the absence of one.
      final detail = trayDetail(conn: ServerConn.connected, cpuPercent: null);

      expect(detail, '--');
    });

    test('a machine that is down says why, not how idle it is', () {
      expect(
        trayDetail(conn: ServerConn.failed, cpuPercent: 90),
        isNot(contains('%')),
      );
      expect(
        trayDetail(conn: ServerConn.disconnected, cpuPercent: 90),
        isNot(contains('%')),
      );
    });
  });

  group('a row', () {
    test('carries the id, which is what opening it needs', () {
      const row = TrayLine(
        id: 'srv-1',
        name: 'prod-web',
        detail: '12%  3G/8G',
        state: TrayLineState.ok,
      );

      expect(row.label, contains('prod-web'));
      expect(row.label, contains('12%  3G/8G'));
      expect(row.label, startsWith(TrayLineState.ok.glyph));
      expect(row.id, 'srv-1');
    });
  });

  group('pushing the same thing twice', () {
    // The menu is replaced whole on every push, which closes it if it is open.
    // Equality is what stops that happening at the poll rate.
    TrayModel modelWith(String detail) => TrayModel([
      TrayLine(
        id: 'a',
        name: 'one',
        detail: detail,
        state: TrayLineState.ok,
      ),
    ]);

    test('is one push', () {
      expect(modelWith('12%'), modelWith('12%'));
    });

    test('and a changed reading is not', () {
      expect(modelWith('12%'), isNot(modelWith('13%')));
    });
  });
}

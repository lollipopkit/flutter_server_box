import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';

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

  group('a row', () {
    test('carries the id, and reads as one line where that is all there is', () {
      const row = TrayLine(
        id: 'srv-1',
        name: 'prod-web',
        state: TrayLineState.ok,
        readings: [
          TrayReading(TrayMetric.cpu, '12%'),
          TrayReading(TrayMetric.mem, '40%'),
        ],
      );

      expect(row.id, 'srv-1');
      expect(row.label, startsWith(TrayLineState.ok.glyph));
      expect(row.label, contains('prod-web'));
      expect(row.label, contains('CPU 12%'));
      expect(row.label, contains('MEM 40%'));
    });

    test('and to a name alone when nothing was asked for', () {
      // Every reading turned off is a choice the settings allow: the dot still
      // says whether the machine is up.
      const row = TrayLine(id: 'a', name: 'nas', state: TrayLineState.offline);

      expect(row.label.trim(), '${TrayLineState.offline.glyph}  nas'.trim());
    });
  });

  group('what a row is built from', () {
    test('a metric the machine cannot answer is left out, not zeroed', () {
      // A machine with no temperature sensor is not a machine at 0 degrees.
      final readings = trayReadings(
        status: _emptyStatus(),
        metrics: TrayMetric.values,
      );

      expect(readings.map((r) => r.metric), isNot(contains(TrayMetric.temp)));
    });

    test('a chart is refused for a metric a chart says nothing about', () {
      // A disk that is 41% full for a week is a flat line spending the width
      // of the row on nothing.
      expect(TrayMetric.disk.chartable, isFalse);
      expect(TrayMetric.temp.chartable, isFalse);
      expect(TrayMetric.cpu.chartable, isTrue);
    });

    test('and for a series too short to be a trend', () {
      final status = _emptyStatus();
      status.history.add(timeMs: 1, cpu: 10);
      status.history.add(timeMs: 2, cpu: 20);

      expect(trayChart(status: status, metric: TrayMetric.cpu), isEmpty);
    });

    test('a series is scaled against the whole range, not its own', () {
      // A machine idling between 1% and 3% would otherwise draw the same
      // alarming shape as one swinging between 10% and 90%.
      final status = _emptyStatus();
      // Rising timestamps: a repeated instant is dropped, since it means the
      // source has not advanced.
      for (final (i, v) in [1.0, 2.0, 3.0, 2.0].indexed) {
        status.history.add(timeMs: i + 1, cpu: v);
      }

      final chart = trayChart(status: status, metric: TrayMetric.cpu);

      expect(chart, hasLength(4));
      expect(chart.reduce((a, b) => a > b ? a : b), lessThan(0.05));
    });
  });

  group('pushing the same thing twice', () {
    TrayModel modelWith(String cpu) => TrayModel(
      lines: [
        TrayLine(
          id: 'a',
          name: 'one',
          state: TrayLineState.ok,
          readings: [TrayReading(TrayMetric.cpu, cpu)],
        ),
      ],
    );

    test('is one push', () {
      // The menu is replaced whole on every platform, which closes it if it is
      // open. Equality is what stops that happening at the refresh rate.
      expect(modelWith('12%'), modelWith('12%'));
    });

    test('and a changed reading is not', () {
      expect(modelWith('12%'), isNot(modelWith('13%')));
    });

    test('nor is the same rows drawn a different way', () {
      const rows = [TrayLine(id: 'a', name: 'one', state: TrayLineState.ok)];

      expect(
        const TrayModel(lines: rows, config: TrayConfig(compact: true)),
        isNot(const TrayModel(lines: rows)),
      );
    });
  });
}

/// A status with nothing measured, which is what a server looks like before
/// its first refresh.
ServerStatus _emptyStatus() => ServerStatus(
  cpu: Cpus(),
  mem: const Memory(total: 0, free: 0, avail: 0),
  disk: const [],
  tcp: const Conn(maxConn: 0, fail: 0),
  netSpeed: NetSpeed(),
  swap: const Swap(total: 0, free: 0, cached: 0),
  temps: Temperatures(),
  system: SystemType.linux,
  diskIO: DiskIO(),
);

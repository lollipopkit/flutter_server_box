import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/status_history.dart';

/// The rolling buffer, and in particular the per-device series the focus chart
/// draws one line each from.
///
/// Every series shares an index with `time`, including the ones that appear
/// after the buffer already holds samples — a disk hot-plugged into a running
/// machine, an interface that comes up with a VPN. Without the backfill its
/// values line up against the wrong instants, and the line is drawn shifted
/// with no error anywhere.
void main() {
  group('per-device series', () {
    test('a device that appears mid-run is padded to the buffer length', () {
      final h = StatusHistory();

      h.add(timeMs: 1, diskWrites: const {'sda': 10});
      h.add(timeMs: 2, diskWrites: const {'sda': 20});
      h.add(timeMs: 3, diskWrites: const {'sda': 30, 'sdb': 5});

      expect(h.length, 3);
      expect(h.diskWritesByDevice['sda'], [10, 20, 30]);
      expect(
        h.diskWritesByDevice['sdb'],
        [null, null, 5],
        reason: 'the new device has to start where it appeared, not at index 0',
      );
    });

    test('a device that stops reporting keeps its place', () {
      final h = StatusHistory();

      h.add(timeMs: 1, netTxs: const {'eth0': 1, 'tun0': 2});
      h.add(timeMs: 2, netTxs: const {'eth0': 3});

      expect(h.netTxByDevice['eth0'], [1, 3]);
      expect(h.netTxByDevice['tun0'], [2, null]);
    });

    test('each metric keeps its own devices', () {
      final h = StatusHistory();

      h.add(
        timeMs: 1,
        diskReads: const {'sda': 1},
        diskWrites: const {'sda': 2},
        netRxs: const {'eth0': 3},
        netTxs: const {'eth0': 4},
        temps: const {'coretemp': 42},
      );

      expect(h.diskReadsByDevice['sda'], [1]);
      expect(h.diskWritesByDevice['sda'], [2]);
      expect(h.netRxByDevice['eth0'], [3]);
      expect(h.netTxByDevice['eth0'], [4]);
      expect(h.tempsByDevice['coretemp'], [42]);
      expect(h.diskReadsByDevice.containsKey('eth0'), isFalse);
    });

    test('a device series rolls with the buffer', () {
      final h = StatusHistory();

      for (var i = 0; i < StatusHistory.capacity + 10; i++) {
        h.add(timeMs: i + 1, diskWrites: {'sda': i.toDouble()});
      }

      expect(h.length, StatusHistory.capacity);
      expect(h.diskWritesByDevice['sda'], hasLength(StatusHistory.capacity));
      expect(h.diskWritesByDevice['sda']!.last, StatusHistory.capacity + 9);
    });

    test('a repeated instant is not a second sample', () {
      final h = StatusHistory();

      h.add(timeMs: 1, diskWrites: const {'sda': 10});
      h.add(timeMs: 1, diskWrites: const {'sda': 20});

      expect(h.length, 1);
      expect(h.diskWritesByDevice['sda'], [10]);
    });
  });

  test('GPU load is kept like any other percentage', () {
    final h = StatusHistory();

    h.add(timeMs: 1, gpu: 41);
    h.add(timeMs: 2);

    expect(h.gpu, [41, null]);
  });
}

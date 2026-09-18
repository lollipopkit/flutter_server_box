import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cpu.dart';

/// How many cores a machine has, which is not how many rows `/proc/stat` has.
///
/// Both sources hand [Cpus] the aggregate "cpu" row first and one row per core
/// after it, and every caller that walks the cores starts at index 1. The
/// count did not: a two-core machine read as three, on the one card that
/// states it as a fact about the hardware.
void main() {
  SingleCpuCore core(String id) => SingleCpuCore(id, 1, 0, 0, 1, 0, 0, 0);

  test('the aggregate row is not a core', () {
    final cpus = Cpus()..update([core('cpu'), core('cpu0'), core('cpu1')]);

    expect(cpus.coresCount, 2);
  });

  test('a sample with nothing in it counts nothing', () {
    final cpus = Cpus()..update([]);

    expect(cpus.coresCount, 0);
  });
}

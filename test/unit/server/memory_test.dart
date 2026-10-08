import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/memory.dart';

void main() {
  test('in use is what is not available, not what is not free', () {
    // The page cache is neither free nor in use: the kernel gives it back.
    const mem = Memory(total: 2000000, free: 200000, avail: 800000);
    expect(mem.used, 1200000);
    expect(mem.used / mem.total, closeTo(mem.usedPercent, 1e-9));
  });

  test('a kernel without MemAvailable falls back to MemFree', () {
    const mem = Memory(total: 1000, free: 400, avail: 0);
    expect(mem.used, 600);
    expect(mem.used / mem.total, closeTo(mem.usedPercent, 1e-9));
  });
}

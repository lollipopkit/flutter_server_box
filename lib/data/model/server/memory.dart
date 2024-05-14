import 'package:fl_lib/fl_lib.dart';

class Memory {
  final int total;
  final int free;
  final int avail;

  const Memory({
    required this.total,
    required this.free,
    required this.avail,
  });

  double get availPercent {
    if (avail == 0) {
      return free / total;
    }
    return avail / total;
  }

  double get usedPercent => 1 - availPercent;

  static Memory parse(String raw) {
    final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

    final total = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'MemTotal:')
                ?.group(2) ??
            '1') ??
        1;
    final free = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'MemFree:')
                ?.group(2) ??
            '0') ??
        0;
    final available = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'MemAvailable:')
                ?.group(2) ??
            '0') ??
        0;

    return Memory(
      total: total,
      free: free,
      avail: available,
    );
  }
}

final memItemReg = RegExp(r'([A-Z].+:)\s+([0-9]+) kB');

class Swap {
  final int total;
  final int free;
  final int cached;

  const Swap({
    required this.total,
    required this.free,
    required this.cached,
  });

  double get usedPercent => 1 - free / total;

  double get freePercent => free / total;

  @override
  String toString() {
    return 'Swap{total: $total, free: $free, cached: $cached}';
  }

  static Swap parse(String raw) {
    final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

    final total = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'SwapTotal:')
                ?.group(2) ??
            '1') ??
        0;
    final free = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'SwapFree:')
                ?.group(2) ??
            '1') ??
        0;
    final cached = int.tryParse(items
                .firstWhereOrNull((e) => e?.group(1) == 'SwapCached:')
                ?.group(2) ??
            '0') ??
        0;

    return Swap(
      total: total,
      free: free,
      cached: cached,
    );
  }
}

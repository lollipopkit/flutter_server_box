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
}

final memItemReg = RegExp(r'([A-Z].+:)\s+([0-9]+) kB');

Memory parseMem(String raw) {
  final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

  final total = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'MemTotal:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '1',
      ) ??
      1;
  final free = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'MemFree:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '0',
      ) ??
      0;
  final available = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'MemAvailable:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '0',
      ) ??
      0;

  return Memory(
    total: total,
    free: free,
    avail: available,
  );
}

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
}

Swap parseSwap(String raw) {
  final items = raw.split('\n').map((e) => memItemReg.firstMatch(e)).toList();

  final total = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'SwapTotal:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '1',
      ) ??
      0;
  final free = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'SwapFree:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '1',
      ) ??
      0;
  final cached = int.tryParse(
        items
                .firstWhere(
                  (e) => e?.group(1) == 'SwapCached:',
                  orElse: () => null,
                )
                ?.group(2) ??
            '0',
      ) ??
      0;

  return Swap(
    total: total,
    free: free,
    cached: cached,
  );
}

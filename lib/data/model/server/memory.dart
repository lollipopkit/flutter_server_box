
class Memory {
  final int total;
  final int free;
  final int avail;

  const Memory({required this.total, required this.free, required this.avail});

  double get availPercent {
    if (avail == 0) {
      return free / total;
    }
    return avail / total;
  }

  double get usedPercent => 1 - availPercent;

  /// In use, in KiB: what is not available, so the page cache the kernel
  /// gives back on demand does not count. `MemFree` where the kernel has no
  /// `MemAvailable` (before 3.14). The same rule as `sbm_parser`'s and the
  /// monitor agent's, and the one [usedPercent] follows.
  int get used => total - (avail == 0 ? free : avail);

}

// Parsing implementation migrated to the shared Rust library sbm_parser

class Swap {
  final int total;
  final int free;
  final int cached;

  const Swap({required this.total, required this.free, required this.cached});

  double get usedPercent => total == 0 ? 0.0 : 1 - free / total;

  @override
  String toString() {
    return 'Swap{total: $total, free: $free, cached: $cached}';
  }

}

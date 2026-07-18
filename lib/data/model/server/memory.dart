
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

}

// 解析实现已迁移至共享 Rust 库 sbm_parser(见 doc/adr/0001)

class Swap {
  final int total;
  final int free;
  final int cached;

  const Swap({required this.total, required this.free, required this.cached});

  double get usedPercent => total == 0 ? 0.0 : 1 - free / total;

  double get freePercent => total == 0 ? 0.0 : free / total;

  @override
  String toString() {
    return 'Swap{total: $total, free: $free, cached: $cached}';
  }

}

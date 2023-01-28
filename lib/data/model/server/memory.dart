get initMemory => Memory(
      total: 1,
      used: 0,
      free: 1,
      cache: 0,
      avail: 1,
    );

class Memory {
  int total;
  int used;
  int free;
  int cache;
  int avail;
  Memory(
      {required this.total,
      required this.used,
      required this.free,
      required this.cache,
      required this.avail});
}


// 解析实现已迁移至共享 Rust 库 sbm_parser(见 doc/adr/0001)

class NvidiaSmiItem {
  final String name;
  final int temp;
  final String power;
  final NvidiaSmiMem memory;
  final int percent;
  final int fanSpeed;

  const NvidiaSmiItem({
    required this.name,
    required this.temp,
    required this.power,
    required this.memory,
    required this.percent,
    required this.fanSpeed,
  });

  @override
  String toString() {
    return 'NvidiaSmiItem{name: $name, temp: $temp, power: $power, memory: $memory}';
  }
}

class NvidiaSmiMem {
  final int total;
  final int used;
  final String unit;
  final List<NvidiaSmiMemProcess> processes;

  const NvidiaSmiMem(this.total, this.used, this.unit, this.processes);

  @override
  String toString() {
    return 'NvidiaSmiMem{total: $total, used: $used, unit: $unit, processes: $processes}';
  }
}

class NvidiaSmiMemProcess {
  final int pid;
  final String name;
  final int memory;

  const NvidiaSmiMemProcess(this.pid, this.name, this.memory);

  @override
  String toString() {
    return 'NvidiaSmiMemProcess{pid: $pid, name: $name, memory: $memory}';
  }
}

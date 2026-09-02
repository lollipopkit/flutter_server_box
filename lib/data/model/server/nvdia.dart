import 'package:server_box/data/model/server/gpu.dart';

// Parsing implementation migrated to the shared Rust library sbm_parser

class NvidiaSmiItem {
  final String name;
  final int temp;
  final String power;
  final GpuSmiMem memory;
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

// Unified GPU memory types — subclasses for backward compat.
class NvidiaSmiMem extends GpuSmiMem {
  const NvidiaSmiMem(super.total, super.used, super.unit, super.processes);
}

class NvidiaSmiMemProcess extends GpuSmiMemProcess {
  const NvidiaSmiMemProcess(super.pid, super.name, super.memory);
}

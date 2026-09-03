library;

import 'package:server_box/data/model/server/gpu.dart';

/// AMD GPU monitoring data structures
/// Supports both amd-smi and rocm-smi tools
// Parsing implementation migrated to the shared Rust library sbm_parser

class AmdSmiItem {
  final String name;
  final int temp;
  final String power;
  final GpuSmiMem memory;
  final int utilization;
  final int fanSpeed;
  final int clockSpeed;

  const AmdSmiItem({
    required this.name,
    required this.temp,
    required this.power,
    required this.memory,
    required this.utilization,
    required this.fanSpeed,
    required this.clockSpeed,
  });

  @override
  String toString() {
    return 'AmdSmiItem{name: $name, temp: $temp, power: $power, utilization: $utilization%, memory: $memory}';
  }
}

// Unified GPU memory types — kept as subclasses for backward compat so
// `AmdSmiMem(...)` / `AmdSmiMemProcess(...)` still construct.
class AmdSmiMem extends GpuSmiMem {
  const AmdSmiMem(super.total, super.used, super.unit, super.processes);
}

class AmdSmiMemProcess extends GpuSmiMemProcess {
  const AmdSmiMemProcess(super.pid, super.name, super.memory);
}

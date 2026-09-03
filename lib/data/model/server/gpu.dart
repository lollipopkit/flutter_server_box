library;

// Parsing implementations migrated to the shared Rust library sbm_parser.
// This file is the single source for GPU memory/process models used by both
// AMD and NVIDIA paths. Vendor-specific item wrappers remain in amd.dart /
// nvdia.dart for now, but share these types.

class GpuSmiMemProcess {
  final int pid;
  final String name;
  final int memory;

  const GpuSmiMemProcess(this.pid, this.name, this.memory);

  @override
  String toString() =>
      'GpuSmiMemProcess{pid: $pid, name: $name, memory: $memory}';
}

class GpuSmiMem {
  final int total;
  final int used;
  final String unit;
  final List<GpuSmiMemProcess> processes;

  const GpuSmiMem(this.total, this.used, this.unit, this.processes);

  @override
  String toString() =>
      'GpuSmiMem{total: $total, used: $used, unit: $unit, processes: ${processes.length}}';
}

library;

/// AMD GPU monitoring data structures
/// Supports both amd-smi and rocm-smi tools
/// Example JSON output:
/// [
///   {
///     "name": "AMD Radeon RX 7900 XTX",
///     "device_id": "0",
///     "temp": 45,
///     "power": "120W / 355W",
///     "memory": {
///       "total": 24576,
///       "used": 1024,
///       "unit": "MB",
///       "processes": [
///         {
///           "pid": 2456,
///           "name": "firefox",
///           "memory": 512
///         }
///       ]
///     },
///     "utilization": 75,
///     "fan_speed": 1200,
///     "clock_speed": 2400
///   }
/// ]

// Parsing implementation migrated to the shared Rust library sbm_parser (see doc/adr/0001)

class AmdSmiItem {
  final String name;
  final int temp;
  final String power;
  final AmdSmiMem memory;
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

class AmdSmiMem {
  final int total;
  final int used;
  final String unit;
  final List<AmdSmiMemProcess> processes;

  const AmdSmiMem(this.total, this.used, this.unit, this.processes);

  @override
  String toString() {
    return 'AmdSmiMem{total: $total, used: $used, unit: $unit, processes: ${processes.length}}';
  }
}

class AmdSmiMemProcess {
  final int pid;
  final String name;
  final int memory;

  const AmdSmiMemProcess(this.pid, this.name, this.memory);

  @override
  String toString() {
    return 'AmdSmiMemProcess{pid: $pid, name: $name, memory: $memory}';
  }
}

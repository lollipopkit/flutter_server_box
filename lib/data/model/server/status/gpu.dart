library;

// Parsing implementations migrated to the shared Rust library sbm_parser.
// This file is the single source for vendor-neutral GPU, memory and process
// models. Vendor-specific item wrappers remain in amd.dart / nvdia.dart for
// backward compatibility.

class GpuItem {
  final String id;
  final String vendor;
  final String name;
  final double? utilization;
  final int? temperature;
  final String? power;
  final GpuSmiMem? memory;
  final int? fanSpeed;
  final int? clockSpeed;

  const GpuItem({
    required this.id,
    required this.vendor,
    required this.name,
    this.utilization,
    this.temperature,
    this.power,
    this.memory,
    this.fanSpeed,
    this.clockSpeed,
  });

  factory GpuItem.fromJson(Map<String, dynamic> json) {
    final memory = json['memory'] as Map<String, dynamic>?;
    return GpuItem(
      id: json['id'] as String,
      vendor: json['vendor'] as String,
      name: json['name'] as String,
      utilization: (json['utilization'] as num?)?.toDouble(),
      temperature: json['temperature'] as int?,
      power: json['power'] as String?,
      memory: memory == null
          ? null
          : GpuSmiMem(
              memory['total'] as int,
              memory['used'] as int,
              memory['unit'] as String,
              (memory['processes'] as List)
                  .map(
                    (rawProcess) {
                      final process = rawProcess as Map<String, dynamic>;
                      return GpuSmiMemProcess(
                      process['pid'] as int,
                      process['name'] as String,
                      process['memory'] as int,
                      );
                    },
                  )
                  .toList(),
            ),
      fanSpeed: json['fan_speed'] as int?,
      clockSpeed: json['clock_speed'] as int?,
    );
  }
}

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

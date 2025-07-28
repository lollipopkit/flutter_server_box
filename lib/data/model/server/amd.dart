import 'dart:convert';

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

class AmdSmi {
  static List<AmdSmiItem> fromJson(String raw) {
    try {
      final jsonData = json.decode(raw);
      if (jsonData is! List) return [];
      
      return jsonData
          .map((gpu) => _parseGpuItem(gpu))
          .where((item) => item != null)
          .cast<AmdSmiItem>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  static AmdSmiItem? _parseGpuItem(Map<String, dynamic> gpu) {
    try {
      final name = gpu['name'] ?? gpu['card_model'] ?? gpu['device_name'] ?? 'Unknown AMD GPU';
      final deviceId = gpu['device_id']?.toString() ?? gpu['gpu_id']?.toString() ?? '0';
      
      // Temperature parsing
      final tempRaw = gpu['temperature'] ?? gpu['temp'] ?? gpu['gpu_temp'];
      final temp = _parseIntValue(tempRaw);
      
      // Power parsing
      final powerDraw = gpu['power_draw'] ?? gpu['current_power'];
      final powerCap = gpu['power_cap'] ?? gpu['power_limit'] ?? gpu['max_power'];
      final power = _formatPower(powerDraw, powerCap);
      
      // Memory parsing
      final memory = _parseMemory(gpu['memory'] ?? gpu['vram'] ?? {});
      
      // Utilization parsing
      final utilization = _parseIntValue(gpu['utilization'] ?? gpu['gpu_util'] ?? gpu['activity']);
      
      // Fan speed parsing
      final fanSpeed = _parseIntValue(gpu['fan_speed'] ?? gpu['fan_rpm']);
      
      // Clock speed parsing
      final clockSpeed = _parseIntValue(gpu['clock_speed'] ?? gpu['gpu_clock'] ?? gpu['sclk']);
      
      return AmdSmiItem(
        deviceId: deviceId,
        name: name,
        temp: temp,
        power: power,
        memory: memory,
        utilization: utilization,
        fanSpeed: fanSpeed,
        clockSpeed: clockSpeed,
      );
    } catch (e) {
      return null;
    }
  }

  static int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // Remove units and parse (e.g., "45°C" -> 45, "1200 RPM" -> 1200)
      final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(cleanValue) ?? 0;
    }
    return 0;
  }

  static String _formatPower(dynamic draw, dynamic cap) {
    final drawValue = _parseIntValue(draw);
    final capValue = _parseIntValue(cap);
    
    if (drawValue == 0 && capValue == 0) return 'N/A';
    if (capValue == 0) return '${drawValue}W';
    return '${drawValue}W / ${capValue}W';
  }

  static AmdSmiMem _parseMemory(Map<String, dynamic> memData) {
    final total = _parseIntValue(memData['total'] ?? memData['total_memory']);
    final used = _parseIntValue(memData['used'] ?? memData['used_memory']);
    final unit = memData['unit']?.toString() ?? 'MB';
    
    final processes = <AmdSmiMemProcess>[];
    final processesData = memData['processes'];
    if (processesData is List) {
      for (final proc in processesData) {
        if (proc is Map<String, dynamic>) {
          final process = _parseProcess(proc);
          if (process != null) processes.add(process);
        }
      }
    }
    
    return AmdSmiMem(total, used, unit, processes);
  }

  static AmdSmiMemProcess? _parseProcess(Map<String, dynamic> procData) {
    final pid = _parseIntValue(procData['pid']);
    final name = procData['name']?.toString() ?? procData['process_name']?.toString() ?? 'Unknown';
    final memory = _parseIntValue(procData['memory'] ?? procData['used_memory']);
    
    if (pid == 0) return null;
    return AmdSmiMemProcess(pid, name, memory);
  }
}

class AmdSmiItem {
  final String deviceId;
  final String name;
  final int temp;
  final String power;
  final AmdSmiMem memory;
  final int utilization;
  final int fanSpeed;
  final int clockSpeed;

  const AmdSmiItem({
    required this.deviceId,
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
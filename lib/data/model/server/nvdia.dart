import 'package:xml/xml.dart';

/// [
///   {
///     "name": "GeForce RTX 3090",
///     "temp": 40,
///     "power": "30W / 350W",
///     "memory": {
///       "total": 24268,
///       "used": 240,
///       "unit": "MiB",
///       "processes": [
///         {
///           "pid": 1456,
///           "name": "/usr/lib/xorg/Xorg",
///           "memory": 40
///         },
///       ]
///     },
///   }
/// ]
///

class NvidiaSmi {
  static List<NvidiaSmiItem> fromXml(String raw) {
    final xmlData = XmlDocument.parse(raw);
    final gpus = xmlData.findAllElements('gpu');
    final result = List<NvidiaSmiItem?>.generate(gpus.length, (index) {
      final gpu = gpus.elementAt(index);
      final name = gpu.findElements('product_name').firstOrNull?.innerText;
      final temp = gpu
          .findElements('temperature')
          .firstOrNull
          ?.findElements('gpu_temp')
          .firstOrNull
          ?.innerText;
      final power = gpu.findElements('gpu_power_readings').firstOrNull;
      final powerDraw =
          power?.findElements('power_draw').firstOrNull?.innerText;
      final powerLimit =
          power?.findElements('current_power_limit').firstOrNull?.innerText;
      final memory = gpu.findElements('fb_memory_usage').firstOrNull;
      final memoryUsed = memory?.findElements('used').firstOrNull?.innerText;
      final memoryTotal = memory?.findElements('total').firstOrNull?.innerText;
      final processes = gpu
          .findElements('processes')
          .firstOrNull
          ?.findElements('process_info');
      final memoryProcesses =
          List<NvidiaSmiMemProcess?>.generate(processes?.length ?? 0, (index) {
        final process = processes?.elementAt(index);
        final pid = process?.findElements('pid').firstOrNull?.innerText;
        final name =
            process?.findElements('process_name').firstOrNull?.innerText;
        final memory =
            process?.findElements('used_memory').firstOrNull?.innerText;
        if (pid != null && name != null && memory != null) {
          return NvidiaSmiMemProcess(
            int.tryParse(pid) ?? 0,
            name,
            int.tryParse(memory.split(' ').firstOrNull ?? '0') ?? 0,
          );
        }
        return null;
      });
      memoryProcesses.removeWhere((element) => element == null);
      final percent = gpu
          .findElements('utilization')
          .firstOrNull
          ?.findElements('gpu_util')
          .firstOrNull
          ?.innerText;
      final fanSpeed = gpu.findElements('fan_speed').firstOrNull?.innerText;
      if (name != null && temp != null) {
        return NvidiaSmiItem(
          name: name,
          uuid: gpu.findElements('uuid').firstOrNull?.innerText ?? '',
          temp: int.tryParse(temp.split(' ').firstOrNull ?? '0') ?? 0,
          percent: int.tryParse(percent?.split(' ').firstOrNull ?? '0') ?? 0,
          power: '$powerDraw / $powerLimit',
          memory: NvidiaSmiMem(
            int.tryParse(memoryTotal?.split(' ').firstOrNull ?? '0') ?? 0,
            int.tryParse(memoryUsed?.split(' ').firstOrNull ?? '0') ?? 0,
            'MiB',
            List.from(memoryProcesses),
          ),
          fanSpeed: int.tryParse(fanSpeed?.split(' ').firstOrNull ?? '0') ?? 0,
        );
      }
      return null;
    });
    result.removeWhere((element) => element == null);
    return List.from(result);
  }
}

class NvidiaSmiItem {
  final String uuid;
  final String name;
  final int temp;
  final String power;
  final NvidiaSmiMem memory;
  final int percent;
  final int fanSpeed;

  const NvidiaSmiItem({
    required this.uuid,
    required this.name,
    required this.temp,
    required this.power,
    required this.memory,
    required this.percent,
    required this.fanSpeed,
  });

  @override
  String toString() {
    return 'NvdiaSmiItem{name: $name, temp: $temp, power: $power, memory: $memory}';
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
    return 'NvdiaSmiMem{total: $total, used: $used, unit: $unit, processes: $processes}';
  }
}

class NvidiaSmiMemProcess {
  final int pid;
  final String name;
  final int memory;

  const NvidiaSmiMemProcess(this.pid, this.name, this.memory);

  @override
  String toString() {
    return 'NvdiaSmiMemProcess{pid: $pid, name: $name, memory: $memory}';
  }
}

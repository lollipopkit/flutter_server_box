import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/amd.dart';

const _amdSmiRaw = '''
[
  {
    "name": "AMD Radeon RX 7900 XTX",
    "device_id": "0",
    "temp": 45,
    "power_draw": 120,
    "power_cap": 355,
    "memory": {
      "total": 24576,
      "used": 1024,
      "unit": "MB",
      "processes": [
        {
          "pid": 2456,
          "name": "firefox",
          "memory": 512
        },
        {
          "pid": 3784,
          "name": "blender",
          "memory": 256
        }
      ]
    },
    "utilization": 75,
    "fan_speed": 1200,
    "clock_speed": 2400
  },
  {
    "name": "AMD Radeon RX 6800 XT",
    "device_id": "1",
    "temp": 38,
    "power_draw": 85,
    "power_cap": 300,
    "memory": {
      "total": 16384,
      "used": 512,
      "unit": "MB",
      "processes": []
    },
    "utilization": 25,
    "fan_speed": 800,
    "clock_speed": 2100
  }
]
''';

const _amdSmiRocmRaw = '''
[
  {
    "card_model": "AMD Radeon RX 6700 XT",
    "gpu_id": "card0",
    "temperature": "42°C",
    "power_draw": "95",
    "power_cap": "230",
    "vram": {
      "total_memory": 12288,
      "used_memory": 768,
      "unit": "MiB",
      "processes": [
        {
          "pid": 1234,
          "process_name": "game.exe",
          "used_memory": 512
        }
      ]
    },
    "gpu_util": "60%",
    "fan_rpm": "950 RPM",
    "sclk": "1800MHz"
  }
]
''';

const _amdSmiAlternativeRaw = '''
[
  {
    "device_name": "Radeon RX 580",
    "gpu_temp": 55,
    "current_power": 150,
    "power_limit": 185,
    "memory": {
      "total": 8192,
      "used": 2048,
      "unit": "MB"
    },
    "activity": 90,
    "fan_speed": 1500,
    "gpu_clock": 1366
  }
]
''';

const _amdSmiEdgeCasesRaw = '''
[
  {
    "name": "Unknown AMD GPU",
    "device_id": "",
    "temp": null,
    "power": null,
    "memory": {},
    "utilization": null,
    "fan_speed": null,
    "clock_speed": null
  },
  {
    "name": "AMD Test GPU",
    "device_id": "test",
    "temp": "50°C",
    "power_draw": 100,
    "memory": {
      "total": "16384MB",
      "used": "2048MB"
    },
    "utilization": "80%",
    "fan_speed": "1100 RPM",
    "clock_speed": "2000 MHz"
  }
]
''';

const _invalidJson = '''
{
  "invalid": "not an array"
}
''';

const _emptyArray = '[]';

const _malformedJson = '''
[
  {
    "name": "Test GPU"
    // missing closing brace
''';

void main() {
  group('AmdSmi JSON parsing', () {
    test('parse standard AMD SMI output', () {
      final gpus = AmdSmi.fromJson(_amdSmiRaw);
      expect(gpus.length, 2);

      final gpu1 = gpus[0];
      expect(gpu1.name, 'AMD Radeon RX 7900 XTX');
      expect(gpu1.deviceId, '0');
      expect(gpu1.temp, 45);
      expect(gpu1.power, '120W / 355W');
      expect(gpu1.memory.total, 24576);
      expect(gpu1.memory.used, 1024);
      expect(gpu1.memory.unit, 'MB');
      expect(gpu1.memory.processes.length, 2);
      expect(gpu1.memory.processes[0].pid, 2456);
      expect(gpu1.memory.processes[0].name, 'firefox');
      expect(gpu1.memory.processes[0].memory, 512);
      expect(gpu1.memory.processes[1].pid, 3784);
      expect(gpu1.memory.processes[1].name, 'blender');
      expect(gpu1.memory.processes[1].memory, 256);
      expect(gpu1.utilization, 75);
      expect(gpu1.fanSpeed, 1200);
      expect(gpu1.clockSpeed, 2400);

      final gpu2 = gpus[1];
      expect(gpu2.name, 'AMD Radeon RX 6800 XT');
      expect(gpu2.deviceId, '1');
      expect(gpu2.temp, 38);
      expect(gpu2.power, '85W / 300W');
      expect(gpu2.memory.total, 16384);
      expect(gpu2.memory.used, 512);
      expect(gpu2.memory.unit, 'MB');
      expect(gpu2.memory.processes.length, 0);
      expect(gpu2.utilization, 25);
      expect(gpu2.fanSpeed, 800);
      expect(gpu2.clockSpeed, 2100);
    });

    test('parse ROCm SMI output with different field names', () {
      final gpus = AmdSmi.fromJson(_amdSmiRocmRaw);
      expect(gpus.length, 1);

      final gpu = gpus[0];
      expect(gpu.name, 'AMD Radeon RX 6700 XT');
      expect(gpu.deviceId, 'card0');
      expect(gpu.temp, 42);
      expect(gpu.power, '95W / 230W');
      expect(gpu.memory.total, 12288);
      expect(gpu.memory.used, 768);
      expect(gpu.memory.unit, 'MiB');
      expect(gpu.memory.processes.length, 1);
      expect(gpu.memory.processes[0].pid, 1234);
      expect(gpu.memory.processes[0].name, 'game.exe');
      expect(gpu.memory.processes[0].memory, 512);
      expect(gpu.utilization, 60);
      expect(gpu.fanSpeed, 950);
      expect(gpu.clockSpeed, 1800);
    });

    test('parse alternative field names', () {
      final gpus = AmdSmi.fromJson(_amdSmiAlternativeRaw);
      expect(gpus.length, 1);

      final gpu = gpus[0];
      expect(gpu.name, 'Radeon RX 580');
      expect(gpu.deviceId, '0');
      expect(gpu.temp, 55);
      expect(gpu.power, '150W / 185W');
      expect(gpu.memory.total, 8192);
      expect(gpu.memory.used, 2048);
      expect(gpu.memory.unit, 'MB');
      expect(gpu.memory.processes.length, 0);
      expect(gpu.utilization, 90);
      expect(gpu.fanSpeed, 1500);
      expect(gpu.clockSpeed, 1366);
    });

    test('handle edge cases and string parsing', () {
      final gpus = AmdSmi.fromJson(_amdSmiEdgeCasesRaw);
      expect(gpus.length, 2);

      final gpu1 = gpus[0];
      expect(gpu1.name, 'Unknown AMD GPU');
      expect(gpu1.deviceId, '');
      expect(gpu1.temp, 0);
      expect(gpu1.power, 'N/A');
      expect(gpu1.memory.total, 0);
      expect(gpu1.memory.used, 0);
      expect(gpu1.memory.unit, 'MB');
      expect(gpu1.memory.processes.length, 0);
      expect(gpu1.utilization, 0);
      expect(gpu1.fanSpeed, 0);
      expect(gpu1.clockSpeed, 0);

      final gpu2 = gpus[1];
      expect(gpu2.name, 'AMD Test GPU');
      expect(gpu2.deviceId, 'test');
      expect(gpu2.temp, 50);
      expect(gpu2.power, '100W');
      expect(gpu2.memory.total, 16384);
      expect(gpu2.memory.used, 2048);
      expect(gpu2.memory.unit, 'MB');
      expect(gpu2.utilization, 80);
      expect(gpu2.fanSpeed, 1100);
      expect(gpu2.clockSpeed, 2000);
    });

    test('handle invalid JSON gracefully', () {
      final gpus1 = AmdSmi.fromJson(_invalidJson);
      expect(gpus1.length, 0);

      final gpus2 = AmdSmi.fromJson(_malformedJson);
      expect(gpus2.length, 0);

      final gpus3 = AmdSmi.fromJson('invalid json');
      expect(gpus3.length, 0);
    });

    test('handle empty array', () {
      final gpus = AmdSmi.fromJson(_emptyArray);
      expect(gpus.length, 0);
    });
  });

  group('AmdSmi helper methods', () {
    test('_parseIntValue handles various input types', () {
      expect(AmdSmi.fromJson('[{"name":"test","temp":42}]')[0].temp, 42);
      expect(AmdSmi.fromJson('[{"name":"test","temp":"45°C"}]')[0].temp, 45);
      expect(AmdSmi.fromJson('[{"name":"test","temp":"1200 RPM"}]')[0].temp, 1200);
      expect(AmdSmi.fromJson('[{"name":"test","temp":"N/A"}]')[0].temp, 0);
      expect(AmdSmi.fromJson('[{"name":"test","temp":null}]')[0].temp, 0);
    });

    test('_formatPower handles different power scenarios', () {
      final gpu1 = AmdSmi.fromJson('[{"name":"test","power_draw":100,"power_cap":200}]')[0];
      expect(gpu1.power, '100W / 200W');

      final gpu2 = AmdSmi.fromJson('[{"name":"test","power_draw":50}]')[0];
      expect(gpu2.power, '50W');

      final gpu3 = AmdSmi.fromJson('[{"name":"test"}]')[0];
      expect(gpu3.power, 'N/A');
    });

    test('_parseMemory handles missing memory data', () {
      final gpu = AmdSmi.fromJson('[{"name":"test"}]')[0];
      expect(gpu.memory.total, 0);
      expect(gpu.memory.used, 0);
      expect(gpu.memory.unit, 'MB');
      expect(gpu.memory.processes.length, 0);
    });

    test('_parseProcess filters invalid processes', () {
      const jsonWithInvalidProcess = '''
      [
        {
          "name": "Test GPU",
          "memory": {
            "processes": [
              {
                "pid": 0,
                "name": "invalid",
                "memory": 100
              },
              {
                "pid": 1234,
                "name": "valid",
                "memory": 200
              }
            ]
          }
        }
      ]
      ''';

      final gpu = AmdSmi.fromJson(jsonWithInvalidProcess)[0];
      expect(gpu.memory.processes.length, 1);
      expect(gpu.memory.processes[0].pid, 1234);
      expect(gpu.memory.processes[0].name, 'valid');
    });
  });

  group('AmdSmi data classes', () {
    test('AmdSmiItem toString', () {
      final memory = AmdSmiMem(8192, 2048, 'MB', []);
      final item = AmdSmiItem(
        deviceId: '0',
        name: 'Test GPU',
        temp: 45,
        power: '100W / 200W',
        memory: memory,
        utilization: 75,
        fanSpeed: 1200,
        clockSpeed: 2400,
      );

      final toString = item.toString();
      expect(toString, contains('Test GPU'));
      expect(toString, contains('45'));
      expect(toString, contains('100W / 200W'));
      expect(toString, contains('75%'));
    });

    test('AmdSmiMem toString', () {
      final process = AmdSmiMemProcess(1234, 'test', 512);
      final memory = AmdSmiMem(8192, 2048, 'MB', [process]);

      final toString = memory.toString();
      expect(toString, contains('8192'));
      expect(toString, contains('2048'));
      expect(toString, contains('MB'));
      expect(toString, contains('1'));
    });

    test('AmdSmiMemProcess toString', () {
      final process = AmdSmiMemProcess(1234, 'firefox', 512);

      final toString = process.toString();
      expect(toString, contains('1234'));
      expect(toString, contains('firefox'));
      expect(toString, contains('512'));
    });
  });

  group('AmdSmi robustness', () {
    test('handles malformed GPU objects gracefully', () {
      const malformedGpuJson = '''
      [
        {
          "name": "Valid GPU",
          "temp": 45
        },
        {
          "malformed": true
        },
        {
          "name": "Another Valid GPU",
          "temp": 50
        }
      ]
      ''';

      final gpus = AmdSmi.fromJson(malformedGpuJson);
      expect(gpus.length, 3);
      expect(gpus[0].name, 'Valid GPU');
      expect(gpus[0].temp, 45);
      expect(gpus[1].name, 'Unknown AMD GPU');
      expect(gpus[1].temp, 0);
      expect(gpus[2].name, 'Another Valid GPU');
      expect(gpus[2].temp, 50);
    });

    test('handles missing required fields with defaults', () {
      const minimalGpuJson = '''
      [
        {}
      ]
      ''';

      final gpus = AmdSmi.fromJson(minimalGpuJson);
      expect(gpus.length, 1);
      expect(gpus[0].name, 'Unknown AMD GPU');
      expect(gpus[0].deviceId, '0');
      expect(gpus[0].temp, 0);
      expect(gpus[0].power, 'N/A');
      expect(gpus[0].utilization, 0);
      expect(gpus[0].fanSpeed, 0);
      expect(gpus[0].clockSpeed, 0);
    });
  });
}

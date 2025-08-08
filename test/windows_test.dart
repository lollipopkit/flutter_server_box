import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';

void main() {
  group('Windows System Tests', () {
    test('should verify Windows segments length matches command types', () {
      final systemType = SystemType.windows;
      final expectedLength = WindowsStatusCmdType.values.length;
      expect(systemType.segmentsLen, equals(expectedLength));
      expect(systemType.isSegmentsLenMatch(expectedLength), isTrue);
    });

    test('should generate Windows PowerShell script correctly', () {
      final script = ShellFunc.windowsScript({'custom_cmd': 'echo "test"'});

      expect(script, contains('PowerShell script for ServerBox'));
      expect(script, contains('function SbStatus'));
      expect(script, contains('function SbProcess'));
      expect(script, contains('function SbShutdown'));
      expect(script, contains('function SbReboot'));
      expect(script, contains('function SbSuspend'));
      expect(script, contains('switch (\$args[0])'));
      expect(script, contains('"-s" { SbStatus }'));
      expect(script, contains('echo "test"'));
    });

    test('should handle Windows system parsing with real data', () async {
      final segments = _windowsStatusSegments;
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      // Verify system information was parsed
      expect(result.more[StatusCmdType.sys], equals('Microsoft Windows 11 Pro for Workstations'));
      expect(result.more[StatusCmdType.host], equals('LKH6'));

      // Verify CPU information
      expect(result.cpu.now, isNotEmpty);
      expect(result.cpu.brand.keys.first, contains('12th Gen Intel(R) Core(TM) i5-12490F'));

      // Verify memory information
      expect(result.mem, isNotNull);
      expect(result.mem.total, equals(66943944));
      expect(result.mem.free, equals(58912812));

      // Verify disk information
      expect(result.disk, isNotEmpty);
      final cDrive = result.disk.firstWhere((disk) => disk.path == 'C:');
      expect(cDrive.fsTyp, equals('NTFS'));
      expect(cDrive.size, equals(BigInt.parse('999271952384') ~/ BigInt.from(1024)));
      expect(cDrive.avail, equals(BigInt.parse('386084032512') ~/ BigInt.from(1024)));

      // Verify TCP connections
      expect(result.tcp, isNotNull);
      expect(result.tcp.active, equals(2));
    });

    test('should parse Windows CPU data correctly', () async {
      const cpuJson = '''
      {
          "Name":  "12th Gen Intel(R) Core(TM) i5-12490F",
          "LoadPercentage":  42
      }
      ''';

      final segments = ['__windows', '1754151483', '', '', cpuJson];
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.cpu.now, hasLength(1));
      expect(result.cpu.now.first.user, equals(42));
      expect(result.cpu.now.first.idle, equals(58));
    });

    test('should parse Windows memory data correctly', () async {
      const memoryJson = '''
      {
          "TotalVisibleMemorySize":  66943944,
          "FreePhysicalMemory":  58912812
      }
      ''';

      final segments = ['__windows', '1754151483', '', '', '', '', '', '', memoryJson];
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.mem, isNotNull);
      expect(result.mem.total, equals(66943944));
      expect(result.mem.free, equals(58912812));
      expect(result.mem.avail, equals(58912812));
    });

    test('should parse Windows disk data correctly', () async {
      const diskJson = '''
      {
          "DeviceID":  "C:",
          "Size":  999271952384,
          "FreeSpace":  386084032512,
          "FileSystem":  "NTFS"
      }
      ''';

      final segments = ['__windows', '1754151483', '', '', '', '', '', diskJson];
      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.disk, hasLength(1));
      final disk = result.disk.first;
      expect(disk.path, equals('C:'));
      expect(disk.mount, equals('C:'));
      expect(disk.fsTyp, equals('NTFS'));
      expect(disk.size, equals(BigInt.parse('999271952384') ~/ BigInt.from(1024)));
      expect(disk.avail, equals(BigInt.parse('386084032512') ~/ BigInt.from(1024)));
      expect(disk.usedPercent, equals(61));
    });

    test('should parse Windows battery data correctly', () async {
      const batteryJson = '''
      {
          "EstimatedChargeRemaining": 85,
          "BatteryStatus": 6
      }
      ''';

      // Create segments with enough elements to reach battery position
      final segments = List.filled(WindowsStatusCmdType.values.length, '');
      segments[0] = '__windows';
      segments[WindowsStatusCmdType.battery.index] = batteryJson;

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.batteries, hasLength(1));
      final battery = result.batteries.first;
      expect(battery.name, equals('Battery'));
      expect(battery.percent, equals(85));
      expect(battery.status.name, equals('charging'));
    });

    test('should handle Windows uptime parsing correctly', () async {
      // Test new format with date line + uptime days
      const uptimeNewFormat = 'Friday, July 25, 2025 2:26:42 PM\n2';

      final segments = List.filled(WindowsStatusCmdType.values.length, '');
      segments[0] = '__windows';
      segments[WindowsStatusCmdType.uptime.index] = uptimeNewFormat;

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.more[StatusCmdType.uptime], isNotNull);
    });

    test('should handle Windows uptime parsing with old format', () async {
      const uptimeDateTime = 'Friday, July 25, 2025 2:26:42 PM';

      final segments = List.filled(WindowsStatusCmdType.values.length, '');
      segments[0] = '__windows';
      segments[WindowsStatusCmdType.uptime.index] = uptimeDateTime;

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      expect(result.more[StatusCmdType.uptime], isNotNull);
    });

    test('should handle Windows script path generation', () {
      const serverId = 'test-server';

      final scriptPath = ShellFunc.getScriptPath(serverId, systemType: SystemType.windows);
      expect(scriptPath, contains('.ps1'));
      expect(scriptPath, contains('\\'));

      final installCmd = ShellFunc.getInstallShellCmd(serverId, systemType: SystemType.windows);
      expect(installCmd, contains('New-Item'));
      expect(installCmd, contains('Set-Content'));
      // No longer contains 'powershell' prefix as commands now run in PowerShell session
    });

    test('should execute Windows commands correctly', () {
      const serverId = 'test-server';

      final statusCmd = ShellFunc.status.exec(serverId, systemType: SystemType.windows);
      expect(statusCmd, contains('powershell'));
      expect(statusCmd, contains('-ExecutionPolicy Bypass'));
      expect(statusCmd, contains('-s'));

      final processCmd = ShellFunc.process.exec(serverId, systemType: SystemType.windows);
      expect(processCmd, contains('powershell'));
      expect(processCmd, contains('-p'));
    });

    test('should handle GPU detection on Windows', () async {
      const nvidiaNotFound = 'NVIDIA driver not found';
      const amdNotFound = 'AMD driver not found';

      final segments = List.filled(WindowsStatusCmdType.values.length, '');
      segments[0] = '__windows';
      segments[WindowsStatusCmdType.nvidia.index] = nvidiaNotFound;
      segments[WindowsStatusCmdType.amd.index] = amdNotFound;

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      final result = await getStatus(req);

      // Should not throw errors even when GPU drivers are not found
      expect(result.nvidia, anyOf(isNull, isEmpty));
      expect(result.amd, anyOf(isNull, isEmpty));
    });

    test('should handle Windows error conditions gracefully', () async {
      // Test with malformed JSON and error messages
      final segments = [
        '__windows',
        '1754151483',
        'Network adapter error',
        'Microsoft Windows 11 Pro for Workstations',
        'invalid json {',
        'uptime error',
        'connection error',
        'disk error',
        'memory error',
        'temp error',
        'LKH6',
        'diskio error',
        'battery error',
        'NVIDIA driver not found',
        'AMD driver not found',
        'sensor error',
        'smart error',
        '12th Gen Intel(R) Core(TM) i5-12490F',
      ];

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      // Should not throw exceptions
      expect(() async => await getStatus(req), returnsNormally);

      final result = await getStatus(req);
      expect(result.more[StatusCmdType.sys], equals('Microsoft Windows 11 Pro for Workstations'));
      expect(result.more[StatusCmdType.host], equals('LKH6'));
    });

    test('should handle Windows temperature error output gracefully', () async {
      // Test with actual error output from win_raw.txt
      final segments = [
        '__windows',
        '1754151483',
        '', // network
        'Microsoft Windows 11 Pro for Workstations', // system
        '''
        {
            "Name":  "12th Gen Intel(R) Core(TM) i5-12490F",
            "LoadPercentage":  42
        }
        ''', // cpu
        'Friday, July 25, 2025 2:26:42 PM', // uptime
        '2', // connections
        '''
        {
            "DeviceID":  "C:",
            "Size":  999271952384,
            "FreeSpace":  386084032512,
            "FileSystem":  "NTFS"
        }
        ''', // disk
        '''
        {
            "TotalVisibleMemorySize":  66943944,
            "FreePhysicalMemory":  58912812
        }
        ''', // memory
        '''
The string is missing the terminator: ".
    + CategoryInfo          : ParserError: (:) [], ParentContainsErrorRecordException
    + FullyQualifiedErrorId : TerminatorExpectedAtEndOfString
        ''', // temp (error output)
        'LKH6', // host
        '', // diskio
        '', // battery
        'NVIDIA driver not found', // nvidia
        'AMD driver not found', // amd
        '', // sensors
        '''
        {
            "DeviceId":  "0",
            "Temperature":  41,
            "TemperatureMax":  70,
            "Wear":  0,
            "PowerOnHours":  null
        }
        ''', // smart
        '12th Gen Intel(R) Core(TM) i5-12490F', // cpu brand
      ];

      final serverStatus = InitStatus.status;

      final req = ServerStatusUpdateReq(
        system: SystemType.windows,
        ss: serverStatus,
        segments: segments,
        customCmds: {},
      );

      // Should not throw exceptions even with error output in temperature values
      expect(() async => await getStatus(req), returnsNormally);

      final result = await getStatus(req);
      expect(result.more[StatusCmdType.sys], equals('Microsoft Windows 11 Pro for Workstations'));
      expect(result.more[StatusCmdType.host], equals('LKH6'));
      // Temperature should be empty since we got error output
      expect(result.temps.isEmpty, isTrue);
    });
  });
}

// Sample Windows status segments based on real PowerShell output
final _windowsStatusSegments = [
  '__windows', // System type marker
  '1754151483', // Unix timestamp
  '', // Network data (empty for now)
  'Microsoft Windows 11 Pro for Workstations', // System name
  '''
  {
      "Name":  "12th Gen Intel(R) Core(TM) i5-12490F",
      "LoadPercentage":  42
  }
  ''', // CPU data
  'Friday, July 25, 2025 2:26:42 PM', // Uptime (boot time)
  '2', // Connection count
  '''
  {
      "DeviceID":  "C:",
      "Size":  999271952384,
      "FreeSpace":  386084032512,
      "FileSystem":  "NTFS"
  }
  ''', // Disk data
  '''
  {
      "TotalVisibleMemorySize":  66943944,
      "FreePhysicalMemory":  58912812
  }
  ''', // Memory data
  '', // Temperature (combined command - empty due to OpenHardwareMonitor error)
  'LKH6', // Hostname
  '', // Disk I/O (empty for now)
  '', // Battery data (empty)
  'NVIDIA driver not found', // NVIDIA GPU
  'AMD driver not found', // AMD GPU
  '', // Sensors (empty due to OpenHardwareMonitor error)
  '''
  {
      "CimClass":  {
          "CimSuperClassName":  "MSFT_StorageObject",
          "CimSuperClass":  {
              "CimSuperClassName":  null,
              "CimSuperClass":  null,
              "CimClassProperties":  "ObjectId PassThroughClass PassThroughIds PassThroughNamespace PassThroughServer UniqueId",
              "CimClassQualifiers":  "Abstract = True locale = 1033",
              "CimClassMethods":  "",
              "CimSystemProperties":  "Microsoft.Management.Infrastructure.CimSystemProperties"
          },
          "CimClassProperties":  [
              "ObjectId",
              "PassThroughClass",
              "PassThroughIds",
              "PassThroughNamespace",
              "PassThroughServer",
              "UniqueId",
              "DeviceId",
              "FlushLatencyMax",
              "LoadUnloadCycleCount",
              "LoadUnloadCycleCountMax",
              "ManufactureDate",
              "PowerOnHours",
              "ReadErrorsCorrected",
              "ReadErrorsTotal",
              "ReadErrorsUncorrected",
              "ReadLatencyMax",
              "StartStopCycleCount",
              "StartStopCycleCountMax",
              "Temperature",
              "TemperatureMax",
              "Wear",
              "WriteErrorsCorrected",
              "WriteErrorsTotal",
              "WriteErrorsUncorrected",
              "WriteLatencyMax"
          ]
      },
      "Temperature":  46,
      "TemperatureMax":  70,
      "Wear":  0,
      "ReadLatencyMax":  1930,
      "WriteLatencyMax":  1903,
      "FlushLatencyMax":  262
  }
  ''', // Disk SMART data
  '12th Gen Intel(R) Core(TM) i5-12490F', // CPU brand
];

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';

/// Windows CPU parse result
class WindowsCpuResult {
  final List<SingleCpuCore> cores;
  final int totalCoreCount;
  const WindowsCpuResult(this.cores, this.totalCoreCount);
}

/// Windows-specific status parsing utilities
///
/// This module handles parsing of Windows PowerShell command outputs
/// for server monitoring. It extracts the Windows parsing logic
/// to improve maintainability and readability.
class WindowsParser {
  const WindowsParser._();

  /// Parse Windows custom commands from parsed output
  static void parseCustomCommands(
    ServerStatus serverStatus,
    Map<String, String> parsedOutput,
    Map<String, String> customCmds,
  ) {
    try {
      for (final entry in customCmds.entries) {
        final key = entry.key;
        final value =
            parsedOutput[ScriptConstants.getCustomResultKey(key)] ?? '';
        serverStatus.customCmds[key] = value;
      }
    } catch (e, s) {
      Loggers.app.warning('Windows custom commands parsing failed: $e', s);
    }
  }

  /// Parse Windows CPU information from PowerShell output
  /// Returns WindowsCpuResult containing CPU cores and total core count
  static WindowsCpuResult parseCpu(String raw, ServerStatus serverStatus) {
    try {
      final dynamic jsonData = json.decode(raw);
      final List<SingleCpuCore> cpus = [];
      int totalCoreCount = 1;

      if (jsonData is List) {
        // Multiple physical processors
        totalCoreCount = 0; // Reset to sum up
        var logicalProcessorOffset = 0;
        final prevCpus = serverStatus.cpu.now;
        for (int procIdx = 0; procIdx < jsonData.length; procIdx++) {
          final processor = jsonData[procIdx];
          if (processor is! Map) continue;
          final loadPercentage = _parsePercentage(processor['LoadPercentage']);
          final numberOfCores = _parsePositiveInt(processor['NumberOfCores']);
          final numberOfLogicalProcessors = _parsePositiveInt(
            processor['NumberOfLogicalProcessors'],
          );
          if (loadPercentage == null ||
              numberOfCores == null ||
              numberOfLogicalProcessors == null) {
            continue;
          }
          totalCoreCount += numberOfCores;
          final usage = loadPercentage.toInt();
          final idle = 100 - usage;

          // Create a SingleCpuCore entry for each logical processor
          // Windows only reports overall CPU load, so we distribute it evenly
          for (int i = 0; i < numberOfLogicalProcessors; i++) {
            final coreId = logicalProcessorOffset + i;
            // Skip summary entry at index 0 when looking up previous samples
            final prevIndex = coreId + 1;
            final prevCpu = prevIndex < prevCpus.length
                ? prevCpus[prevIndex]
                : null;

            // LIMITATION: Windows CPU counters approach
            // PowerShell provides LoadPercentage as instantaneous percentage, not cumulative time.
            // We simulate cumulative counters by adding current percentages to previous totals.
            // Additionally, Windows only provides overall CPU load, not per-core load.
            // We distribute the load evenly across all logical processors.
            final newUser = (prevCpu?.user ?? 0) + usage;
            final newIdle = (prevCpu?.idle ?? 0) + idle;

            cpus.add(
              SingleCpuCore(
                'cpu$coreId',
                newUser, // cumulative user time
                0, // sys (not available)
                0, // nice (not available)
                newIdle, // cumulative idle time
                0, // iowait (not available)
                0, // irq (not available)
                0, // softirq (not available)
              ),
            );
          }
          logicalProcessorOffset += numberOfLogicalProcessors;
        }
      } else if (jsonData is Map) {
        // Single physical processor
        final loadPercentage = _parsePercentage(jsonData['LoadPercentage']);
        final numberOfCores = _parsePositiveInt(jsonData['NumberOfCores']);
        final numberOfLogicalProcessors = _parsePositiveInt(
          jsonData['NumberOfLogicalProcessors'],
        );
        if (loadPercentage == null ||
            numberOfCores == null ||
            numberOfLogicalProcessors == null) {
          return const WindowsCpuResult([], 0);
        }
        totalCoreCount = numberOfCores;
        final usage = loadPercentage.toInt();
        final idle = 100 - usage;

        // Create a SingleCpuCore entry for each logical processor
        final prevCpus = serverStatus.cpu.now;
        for (int i = 0; i < numberOfLogicalProcessors; i++) {
          // Skip summary entry at index 0 when looking up previous samples
          final prevIndex = i + 1;
          final prevCpu = prevIndex < prevCpus.length
              ? prevCpus[prevIndex]
              : null;

          // LIMITATION: See comment above for Windows CPU counter limitations
          final newUser = (prevCpu?.user ?? 0) + usage;
          final newIdle = (prevCpu?.idle ?? 0) + idle;

          cpus.add(
            SingleCpuCore(
              'cpu$i',
              newUser, // cumulative user time
              0, // sys
              0, // nice
              newIdle, // cumulative idle time
              0, // iowait
              0, // irq
              0, // softirq
            ),
          );
        }
      }

      // Add a summary entry at the beginning (like Linux 'cpu' line)
      // This is the aggregate of all logical processors
      if (cpus.isNotEmpty) {
        int totalUser = 0;
        int totalIdle = 0;
        for (final core in cpus) {
          totalUser += core.user;
          totalIdle += core.idle;
        }
        // Insert at the beginning with ID 'cpu' (matching Linux format)
        cpus.insert(
          0,
          SingleCpuCore(
            'cpu', // Summary entry, like Linux
            totalUser,
            0,
            0,
            totalIdle,
            0,
            0,
            0,
          ),
        );
      }

      return WindowsCpuResult(cpus, totalCoreCount);
    } catch (e, s) {
      Loggers.app.warning('Windows CPU parsing failed: $e', s);
      return WindowsCpuResult([], 1);
    }
  }

  /// Parse Windows memory information from PowerShell output
  ///
  /// NOTE: Windows Win32_OperatingSystem properties TotalVisibleMemorySize
  /// and FreePhysicalMemory are returned in KB units.
  static Memory? parseMemory(String raw) {
    try {
      final dynamic jsonData = json.decode(raw);
      final data = jsonData is List ? jsonData.first : jsonData;
      if (data is! Map) return null;

      // Win32_OperatingSystem properties are in KB
      final totalKB = _parseNonNegativeInt(data['TotalVisibleMemorySize']);
      final freeKB = _parseNonNegativeInt(data['FreePhysicalMemory']);
      if (totalKB == null ||
          freeKB == null ||
          totalKB <= 0 ||
          freeKB > totalKB) {
        return null;
      }

      return Memory(
        total: totalKB,
        free: freeKB,
        avail: freeKB, // Windows doesn't distinguish between free and available
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse Windows disk information from PowerShell output
  static List<Disk> parseDisks(String raw) {
    try {
      final dynamic jsonData = json.decode(raw);
      final List<Disk> disks = [];

      final diskList = jsonData is List ? jsonData : [jsonData];

      for (final diskData in diskList) {
        final deviceId = diskData['DeviceID']?.toString() ?? '';
        final size = BigInt.tryParse(diskData['Size']?.toString() ?? '');
        final freeSpace = BigInt.tryParse(
          diskData['FreeSpace']?.toString() ?? '',
        );
        final fileSystem = diskData['FileSystem']?.toString() ?? '';

        // Validate all required fields
        final hasRequiredFields =
            deviceId.isNotEmpty &&
            size != null &&
            size > BigInt.zero &&
            freeSpace != null &&
            freeSpace >= BigInt.zero &&
            freeSpace <= size &&
            fileSystem.isNotEmpty;

        if (!hasRequiredFields) {
          Loggers.app.warning(
            'Windows disk parsing: skipping disk with missing required fields. '
            'DeviceID: $deviceId, Size: $size, FreeSpace: $freeSpace, FileSystem: $fileSystem',
          );
          continue;
        }

        final sizeKB = size ~/ BigInt.from(1024);
        final freeKB = freeSpace ~/ BigInt.from(1024);
        final usedKB = sizeKB - freeKB;
        final usedPercent = sizeKB > BigInt.zero
            ? ((usedKB * BigInt.from(100)) ~/ sizeKB).toInt().clamp(0, 100)
            : 0;

        disks.add(
          Disk(
            path: deviceId,
            fsTyp: fileSystem,
            size: sizeKB,
            avail: freeKB,
            used: usedKB,
            usedPercent: usedPercent,
            mount: deviceId, // Windows uses drive letters as mount points
          ),
        );
      }

      return disks;
    } catch (e) {
      Loggers.app.warning('Windows disk parsing failed: $e');
      return [];
    }
  }

  static List<DiskSmart> parseDiskSmart(String raw) {
    try {
      final decoded = json.decode(raw);
      final values = decoded is List ? decoded : [decoded];
      return [
        for (final value in values)
          if (value is Map && value['DeviceId'] != null)
            DiskSmart(
              device: value['DeviceId'].toString(),
              temperature: (value['Temperature'] as num?)?.toDouble(),
              powerOnHours: _parseNonNegativeInt(value['PowerOnHours']),
              rawData: Map<String, dynamic>.from(value),
              smartAttributes: const {},
            ),
      ];
    } catch (e, s) {
      Loggers.app.warning('Windows SMART parsing failed: $e', s);
      return const [];
    }
  }

  static List<SensorItem> parseSensors(String raw) {
    try {
      final decoded = json.decode(raw);
      final values = decoded is List ? decoded : [decoded];
      return [
        for (final value in values)
          if (value is Map &&
              value['Name']?.toString().trim().isNotEmpty == true)
            SensorItem(
              device: value['Name'].toString(),
              adapter: const SensorAdaptor('Windows WMI'),
              details: {
                if (value['CurrentReading'] != null)
                  'CurrentReading': value['CurrentReading'].toString(),
              },
            ),
      ];
    } catch (e, s) {
      Loggers.app.warning('Windows sensor parsing failed: $e', s);
      return const [];
    }
  }
}

int? _parsePositiveInt(Object? value) {
  final parsed = _parseNonNegativeInt(value);
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _parseNonNegativeInt(Object? value) {
  final parsed = switch (value) {
    final int value => value,
    final num value when value.isFinite && value == value.truncateToDouble() =>
      value.toInt(),
    _ => int.tryParse(value?.toString() ?? ''),
  };
  return parsed != null && parsed >= 0 ? parsed : null;
}

double? _parsePercentage(Object? value) {
  final parsed = switch (value) {
    final num value => value.toDouble(),
    _ => double.tryParse(value?.toString() ?? ''),
  };
  return parsed != null && parsed.isFinite && parsed >= 0 && parsed <= 100
      ? parsed
      : null;
}

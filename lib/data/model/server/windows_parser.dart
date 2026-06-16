import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';

/// Windows CPU parse result
class WindowsCpuResult {
  final List<SingleCpuCore> cores;
  final int coreCount;
  const WindowsCpuResult(this.cores, this.coreCount);
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
        final value = parsedOutput[key] ?? '';
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
          final loadPercentage = (processor['LoadPercentage'] as num?) ?? 0;
          final numberOfCores = (processor['NumberOfCores'] as int?) ?? 1;
          final numberOfLogicalProcessors =
              (processor['NumberOfLogicalProcessors'] as int?) ?? numberOfCores;
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
        final loadPercentage = (jsonData['LoadPercentage'] as num?) ?? 0;
        final numberOfCores = (jsonData['NumberOfCores'] as int?) ?? 1;
        final numberOfLogicalProcessors =
            (jsonData['NumberOfLogicalProcessors'] as int?) ?? numberOfCores;
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

      // Win32_OperatingSystem properties are in KB
      final totalKB = data['TotalVisibleMemorySize'] as int? ?? 0;
      final freeKB = data['FreePhysicalMemory'] as int? ?? 0;

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
        final size =
            BigInt.tryParse(diskData['Size']?.toString() ?? '0') ?? BigInt.zero;
        final freeSpace =
            BigInt.tryParse(diskData['FreeSpace']?.toString() ?? '0') ??
            BigInt.zero;
        final fileSystem = diskData['FileSystem']?.toString() ?? '';

        // Validate all required fields
        final hasRequiredFields =
            deviceId.isNotEmpty &&
            size != BigInt.zero &&
            freeSpace != BigInt.zero &&
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
}

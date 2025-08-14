import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:intl/intl.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';

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

  /// Parse Windows uptime from PowerShell output
  static String? parseUpTime(String raw) {
    try {
      // Clean the input - trim whitespace and get the first non-empty line
      final cleanedInput = raw.trim().split('\n').where((line) => line.trim().isNotEmpty).firstOrNull;

      if (cleanedInput == null || cleanedInput.isEmpty) {
        Loggers.app.warning('Windows uptime parsing: empty or null input');
        return null;
      }

      // Try multiple date formats to handle different Windows locale/version outputs
      final formatters = [
        DateFormat('EEEE, MMMM d, yyyy h:mm:ss a', 'en_US'), // Original format
        DateFormat('EEEE, MMMM dd, yyyy h:mm:ss a', 'en_US'), // Double-digit day
        DateFormat('EEE, MMM d, yyyy h:mm:ss a', 'en_US'), // Shortened format
        DateFormat('EEE, MMM dd, yyyy h:mm:ss a', 'en_US'), // Shortened with double-digit day
        DateFormat('M/d/yyyy h:mm:ss a', 'en_US'), // Short US format
        DateFormat('MM/dd/yyyy h:mm:ss a', 'en_US'), // Short US format with zero padding
        DateFormat('d/M/yyyy h:mm:ss a', 'en_US'), // Short European format
        DateFormat('dd/MM/yyyy h:mm:ss a', 'en_US'), // Short European format with zero padding
      ];

      DateTime? dateTime;
      for (final formatter in formatters) {
        dateTime = formatter.tryParseLoose(cleanedInput);
        if (dateTime != null) break;
      }

      if (dateTime == null) {
        Loggers.app.warning('Windows uptime parsing: could not parse date format for: $cleanedInput');
        return null;
      }

      final now = DateTime.now();
      final uptime = now.difference(dateTime);

      // Validate that the uptime is reasonable (not negative, not too far in the future)
      if (uptime.isNegative || uptime.inDays > 3650) {
        // More than 10 years seems unreasonable
        Loggers.app.warning(
          'Windows uptime parsing: unreasonable uptime calculated: ${uptime.inDays} days for date: $cleanedInput',
        );
        return null;
      }

      final days = uptime.inDays;
      final hours = uptime.inHours % 24;
      final minutes = uptime.inMinutes % 60;

      if (days > 0) {
        return '$days days, $hours:${minutes.toString().padLeft(2, '0')}';
      } else {
        return '$hours:${minutes.toString().padLeft(2, '0')}';
      }
    } catch (e, s) {
      Loggers.app.warning('Windows uptime parsing failed: $e for input: $raw', s);
      return null;
    }
  }

  /// Parse Windows CPU information from PowerShell output
  static List<SingleCpuCore> parseCpu(String raw, ServerStatus serverStatus) {
    try {
      final dynamic jsonData = json.decode(raw);
      final List<SingleCpuCore> cpus = [];

      if (jsonData is List) {
        for (int i = 0; i < jsonData.length; i++) {
          final cpu = jsonData[i];
          final loadPercentage = cpu['LoadPercentage'] ?? 0;
          final usage = loadPercentage as int;
          final idle = 100 - usage;

          // Get previous CPU data to calculate cumulative values
          final prevCpus = serverStatus.cpu.now;
          final prevCpu = i < prevCpus.length ? prevCpus[i] : null;

          // LIMITATION: Windows CPU counters approach
          // PowerShell provides LoadPercentage as instantaneous percentage, not cumulative time.
          // We simulate cumulative counters by adding current percentages to previous totals.
          // This approach has limitations:
          // 1. Not as accurate as true cumulative time counters (Linux /proc/stat)
          // 2. May drift over time with variable polling intervals
          // 3. Results depend on consistent polling frequency
          // However, this allows compatibility with existing delta-based CPU calculation logic.
          final newUser = (prevCpu?.user ?? 0) + usage;
          final newIdle = (prevCpu?.idle ?? 0) + idle;

          cpus.add(
            SingleCpuCore(
              'cpu$i',
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
      } else if (jsonData is Map) {
        // Single CPU core
        final loadPercentage = jsonData['LoadPercentage'] ?? 0;
        final usage = loadPercentage as int;
        final idle = 100 - usage;

        // Get previous CPU data to calculate cumulative values
        final prevCpus = serverStatus.cpu.now;
        final prevCpu = prevCpus.isNotEmpty ? prevCpus[0] : null;

        // LIMITATION: See comment above for Windows CPU counter limitations
        final newUser = (prevCpu?.user ?? 0) + usage;
        final newIdle = (prevCpu?.idle ?? 0) + idle;

        cpus.add(
          SingleCpuCore(
            'cpu0',
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

      return cpus;
    } catch (e) {
      return [];
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
        final size = BigInt.tryParse(diskData['Size']?.toString() ?? '0') ?? BigInt.zero;
        final freeSpace = BigInt.tryParse(diskData['FreeSpace']?.toString() ?? '0') ?? BigInt.zero;
        final fileSystem = diskData['FileSystem']?.toString() ?? '';

        // Validate all required fields
        final hasRequiredFields =
            deviceId.isNotEmpty && size != BigInt.zero && freeSpace != BigInt.zero && fileSystem.isNotEmpty;

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

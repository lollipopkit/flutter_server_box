import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Exception thrown when executable management fails
class ExecutableException implements Exception {
  final String message;

  ExecutableException(this.message);

  @override
  String toString() => 'ExecutableException: $message';
}

/// Information about an executable
class ExecutableInfo {
  final String name;
  final String? spokenName;
  final String? version;

  ExecutableInfo({required this.name, this.version, this.spokenName});
}

/// Generic executable manager for downloading and managing external tools
abstract final class ExecutableManager {
  static const String _executablesDirName = 'executables';
  static late final Directory _executablesDir;

  static Future<void> initialize() async {
    final appDir = await getApplicationSupportDirectory();
    _executablesDir = Directory(path.join(appDir.path, _executablesDirName));
    if (!await _executablesDir.exists()) {
      await _executablesDir.create(recursive: true);
    }
  }

  /// Predefined executables
  static final Map<String, ExecutableInfo> _predefinedExecutables = {
    'cloudflared': ExecutableInfo(name: 'cloudflared'),
    'ssh': ExecutableInfo(name: 'ssh'),
    'nc': ExecutableInfo(name: 'nc'),
    'socat': ExecutableInfo(name: 'socat'),
  };

  /// Check if an executable exists in PATH or local directory
  static Future<bool> isExecutableAvailable(String name) async {
    // First check if it's in PATH
    final pathExecutable = await _lookupExecutableInSystemPath(name);
    if (pathExecutable != null) {
      return true;
    }

    // Check local executables directory
    final localExecutable = _getLocalExecutablePath(name);
    if (await localExecutable.exists()) {
      return true;
    }

    return false;
  }

  /// Get the path to an executable (either in PATH or local)
  static Future<String> getExecutablePath(String name) async {
    // First check if it's in PATH
    final pathExecutable = await _lookupExecutableInSystemPath(name);
    if (pathExecutable != null) {
      return pathExecutable;
    }

    // Check local executables directory
    final localExecutable = _getLocalExecutablePath(name);
    if (await localExecutable.exists()) {
      return localExecutable.path;
    }

    throw ExecutableException('Executable $name not found in PATH or local directory');
  }

  /// Download an executable if it's not available
  static Future<String> ensureExecutable(String name) async {
    if (await isExecutableAvailable(name)) {
      return await getExecutablePath(name);
    }

    return await getExecutablePath(name);
  }

  /// Remove a local executable
  static Future<void> removeExecutable(String name) async {
    final localExecutable = _getLocalExecutablePath(name);
    if (await localExecutable.exists()) {
      await localExecutable.delete();
      Loggers.app.info('Removed local executable: $name');
    }
  }

  /// List all locally downloaded executables
  static Future<List<String>> listLocalExecutables() async {
    if (!await _executablesDir.exists()) {
      return [];
    }

    final executables = <String>[];
    await for (final entity in _executablesDir.list()) {
      if (entity is File && _isExecutable(entity)) {
        executables.add(path.basenameWithoutExtension(entity.path));
      }
    }
    return executables;
  }

  /// Get the size of a local executable
  static Future<int> getExecutableSize(String name) async {
    final localExecutable = _getLocalExecutablePath(name);
    if (await localExecutable.exists()) {
      return await localExecutable.length();
    }
    return 0;
  }

  /// Get the version of an executable
  static Future<String?> getExecutableVersion(String name) async {
    try {
      final executablePath = await getExecutablePath(name);

      // Try common version flags
      final versionFlags = ['--version', '-v', '-V', 'version'];

      for (final flag in versionFlags) {
        try {
          final result = await Process.run(executablePath, [flag]);
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            if (output.isNotEmpty) {
              return output.split('\n').first; // Return first line only
            }
          }
        } catch (e) {
          // Try next flag
        }
      }
    } catch (e) {
      Loggers.app.warning('Error getting version for $name: $e');
    }

    return null;
  }

  /// Validate an executable by trying to run it with a help flag
  static Future<bool> validateExecutable(String name) async {
    try {
      final executablePath = await getExecutablePath(name);

      // Try to run the executable with a help flag
      final helpFlags = ['--help', '-h', '-help'];

      for (final flag in helpFlags) {
        try {
          final result = await Process.run(executablePath, [flag]);
          if (result.exitCode == 0 || result.exitCode == 1) {
            // Help often returns 1
            return true;
          }
        } catch (e) {
          // Try next flag
        }
      }
    } catch (e) {
      Loggers.app.warning('Error validating $name: $e');
      return false;
    }

    return false;
  }

  static Future<String?> _lookupExecutableInSystemPath(String name) async {
    final command = Platform.isWindows ? 'where' : 'which';
    try {
      final result = await Process.run(command, [name]);
      if (result.exitCode != 0) {
        return null;
      }

      final stdoutString = result.stdout.toString().trim();
      if (stdoutString.isEmpty) {
        return null;
      }

      final candidate = stdoutString
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => '');

      if (candidate.isEmpty) {
        return null;
      }

      return candidate;
    } catch (e) {
      Loggers.app.warning('Error checking PATH for $name: $e');
      return null;
    }
  }

  /// Get the local path for an executable
  static File _getLocalExecutablePath(String name) {
    final extension = Platform.isWindows ? '.exe' : '';
    return File(path.join(_executablesDir.path, '$name$extension'));
  }

  /// Check if a file is executable
  static bool _isExecutable(File file) {
    if (Platform.isWindows) {
      return file.path.endsWith('.exe');
    } else {
      // Check file permissions
      final stat = file.statSync();
      return (stat.mode & 0x111) != 0; // Check execute bits
    }
  }

  /// Get predefined executable info
  static ExecutableInfo? getExecutableInfo(String name) {
    return _predefinedExecutables[name];
  }

  /// Add a custom executable definition
  static void addCustomExecutable(String name, ExecutableInfo info) {
    // TODO: Implement persistent storage for custom executables
    Loggers.app.info('Adding custom executable: $name');
  }

  /// Remove a custom executable definition
  static void removeCustomExecutable(String name) {
    // TODO: Implement persistent storage for custom executables
    Loggers.app.info('Removing custom executable: $name');
  }
}

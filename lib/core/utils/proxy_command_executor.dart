import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/executable_manager.dart';
import 'package:server_box/core/utils/proxy_socket.dart';
import 'package:server_box/data/model/server/proxy_command_config.dart';

/// Exception thrown when proxy command execution fails
class ProxyCommandException implements Exception {
  final String message;
  final int? exitCode;
  final String? stdout;
  final String? stderr;

  ProxyCommandException({required this.message, this.exitCode, this.stdout, this.stderr});

  @override
  String toString() {
    return 'ProxyCommandException: $message'
        '${exitCode != null ? ' (exit code: $exitCode)' : ''}'
        '${stderr != null ? '\nStderr: $stderr' : ''}';
  }
}

/// Generic proxy command executor that handles SSH ProxyCommand functionality
abstract final class ProxyCommandExecutor {
  /// Execute a proxy command and return a socket connected through the proxy
  static Future<SSHSocket> executeProxyCommand(
    ProxyCommandConfig config, {
    required String hostname,
    required int port,
    required String user,
  }) async {
    if (Platform.isIOS) {
      throw ProxyCommandException(message: 'ProxyCommand is not supported on iOS');
    }

    final finalCommand = config.getFinalCommand(hostname: hostname, port: port, user: user);

    Loggers.app.info('Executing proxy command: $finalCommand');

    // Ensure executable is available if required
    String executablePath;
    if (config.requiresExecutable && config.executableName != null) {
      executablePath = await ExecutableManager.ensureExecutable(config.executableName!);
    } else {
      // Parse command to get executable
      final parts = finalCommand.split(' ');
      final executable = parts.first;
      executablePath = await ExecutableManager.getExecutablePath(executable);
    }

    // Parse command and arguments
    final parts = finalCommand.split(' ');
    final args = parts.skip(1).toList();

    // Set up environment
    final environment = {...Platform.environment, ...?config.environment};

    // Start the process
    Process process;
    try {
      process = await Process.start(
        executablePath,
        args,
        workingDirectory: config.workingDirectory,
        environment: environment,
      );
    } catch (e) {
      throw ProxyCommandException(message: 'Failed to start proxy command: $e', exitCode: -1);
    }

    // Set up timeout handling
    var timedOut = false;
    final timeoutTimer = Timer(config.timeout, () {
      timedOut = true;
      process.kill();
    });

    try {
      // For ProxyCommand, we create a ProxySocket that wraps the process
      final socket = ProxySocket(process);

      // Monitor the process for immediate failures
      unawaited(
        process.exitCode.then((code) {
          if (code != 0 && !socket.closed && !timedOut) {
            socket.close();
          }
        }),
      );

      return socket;
    } catch (e) {
      process.kill();
      rethrow;
    } finally {
      timeoutTimer.cancel();
    }
  }

  /// Validate proxy command configuration
  static Future<String?> validateConfig(ProxyCommandConfig config) async {
    if (Platform.isIOS) {
      return 'ProxyCommand is not supported on iOS';
    }

    final testCommand = config.getFinalCommand(hostname: 'test.example.com', port: 22, user: 'testuser');

    // Check if required placeholders are present
    if (!config.command.contains('%h')) {
      return 'Proxy command must contain %h (hostname) placeholder';
    }

    // If executable is required, check if it exists
    if (config.requiresExecutable && config.executableName != null) {
      try {
        await ExecutableManager.ensureExecutable(config.executableName!);
      } catch (e) {
        return e.toString();
      }
    }

    // Try to validate command syntax (dry run)
    final parts = testCommand.split(' ');
    final executable = parts.first;

    try {
      await Process.run(executable, ['--help'], runInShell: true);
    } catch (e) {
      return 'Command validation failed: $e';
    }

    return null; // No error
  }

  /// Get available proxy command presets
  static Map<String, ProxyCommandConfig> getPresets() {
    return proxyCommandPresets;
  }

  /// Add a custom preset
  static Future<void> addCustomPreset(String name, ProxyCommandConfig config) async {
    // TODO: Implement custom preset storage
    // This would involve storing custom presets in a persistent storage
    Loggers.app.info('Adding custom proxy preset: $name');
  }

  /// Remove a custom preset
  static Future<void> removeCustomPreset(String name) async {
    // TODO: Implement custom preset removal
    Loggers.app.info('Removing custom proxy preset: $name');
  }
}

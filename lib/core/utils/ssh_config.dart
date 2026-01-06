import 'dart:io';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// Utility class to parse SSH config files under `~/.ssh/config`
abstract final class SSHConfig {
  static const String _defaultPath = '~/.ssh/config';

  static String? get _homePath {
    final homePath = isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
    if (homePath == null || homePath.isEmpty) {
      return null;
    }
    return homePath;
  }

  /// Get possible SSH config file paths, with macOS-specific handling
  static List<String> get _possibleConfigPaths {
    final paths = <String>[];
    final homePath = _homePath;

    if (homePath != null) {
      // Standard path
      paths.add('$homePath/.ssh/config');

      // On macOS, also try the actual user home directory
      if (isMacOS) {
        // Try to get the real user home directory
        final username = Platform.environment['USER'];
        if (username != null) {
          paths.add('/Users/$username/.ssh/config');
        }
      }
    }

    return paths;
  }

  /// Parse SSH config file and return a list of Spi objects
  static Future<List<Spi>> parseConfig([String? configPath]) async {
    final (file, exists) = configExists(configPath);
    if (!exists || file == null) {
      Loggers.app.info('SSH config file does not exist at path: ${configPath ?? _defaultPath}');
      return [];
    }

    final content = await file.readAsString();
    return _parseSSHConfig(content);
  }

  /// Parse SSH config content
  static List<Spi> _parseSSHConfig(String content) {
    final servers = <Spi>[];
    final lines = content.split('\n');

    String? currentHost;
    String? hostname;
    String? user;
    int port = 22;
    String? identityFile;
    String? jumpHost;

    void addServer() {
      if (currentHost != null && currentHost != '*' && hostname != null) {
        final spi = Spi(
          id: ShortId.generate(),
          name: currentHost,
          ip: hostname,
          port: port,
          user: user ?? 'root', // Default user is 'root'
          keyId: identityFile,
          jumpId: jumpHost,
        );
        servers.add(spi);
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Handle inline comments
      final commentIndex = trimmed.indexOf('#');
      final cleanLine = commentIndex != -1 ? trimmed.substring(0, commentIndex).trim() : trimmed;
      if (cleanLine.isEmpty) continue;

      final parts = cleanLine.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final key = parts[0].toLowerCase();
      var value = parts.sublist(1).join(' ');

      // Remove quotes from values
      if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      switch (key) {
        case 'host':
          // Save previous host config
          addServer();

          // Reset for new host
          final originalValue = parts.sublist(1).join(' ');
          final isQuoted =
              (originalValue.startsWith('"') && originalValue.endsWith('"')) ||
              (originalValue.startsWith("'") && originalValue.endsWith("'"));

          currentHost = value;
          // Skip hosts with multiple patterns (contains spaces but not quoted)
          if (currentHost.contains(' ') && !isQuoted) {
            currentHost = null; // Mark as invalid to skip
          }
          hostname = null;
          user = null;
          port = 22;
          identityFile = null;
          jumpHost = null;
          break;

        case 'hostname':
          hostname = value;
          break;

        case 'user':
          user = value;
          break;

        case 'port':
          port = int.tryParse(value) ?? 22;
          break;

        case 'identityfile':
          identityFile = value; // Store the path directly
          break;

        case 'proxyjump':
        case 'proxycommand':
          jumpHost = _extractJumpHost(value);
          break;
      }
    }

    // Add the last server
    addServer();

    return servers;
  }

  /// Extract jump host from ProxyJump or ProxyCommand
  static String? _extractJumpHost(String value) {
    if (value.isEmpty) return null;
    // For ProxyJump, the format is usually: user@host:port
    // For ProxyCommand, it's more complex and might need custom parsing
    if (value.contains('@')) {
      final parts = value.split(' ');
      return parts.isNotEmpty ? parts[0] : null;
    }
    return null;
  }

  /// Check if SSH config file exists, trying multiple possible paths
  static (File?, bool) configExists([String? configPath]) {
    if (configPath != null) {
      // If specific path is provided, use it directly
      final homePath = _homePath;
      if (homePath == null) {
        Loggers.app.warning('Cannot determine home directory for SSH config parsing.');
        return (null, false);
      }
      final expandedPath = configPath.replaceFirst('~', homePath);
      dprint('Checking SSH config at path: $expandedPath');
      final file = File(expandedPath);
      return (file, file.existsSync());
    }

    // Try multiple possible paths
    for (final path in _possibleConfigPaths) {
      dprint('Checking SSH config at path: $path');
      final file = File(path);
      if (file.existsSync()) {
        dprint('Found SSH config at: $path');
        return (file, true);
      }
    }

    dprint('SSH config file not found in any of the expected locations');
    return (null, false);
  }
}

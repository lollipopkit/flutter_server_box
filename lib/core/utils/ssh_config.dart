import 'dart:io';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// Utility class to parse SSH config files under `~/.ssh/config`
abstract final class SSHConfig {
  static const String _defaultPath = '~/.ssh/config';

  static String? get _homePath {
    final homePath = isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (homePath == null || homePath.isEmpty) {
      return null;
    }
    return homePath;
  }

  /// A leading `~` replaced with this account's home directory.
  ///
  /// Public because `IdentityFile` values are kept verbatim — the file they
  /// name is resolved when the connection is made, not when the config is
  /// parsed — so whoever opens one has to do this too.
  ///
  /// Returns [path] unchanged when it does not start with `~`, or when the
  /// environment names no home: a path that cannot be expanded is better
  /// reported by the open that fails on it than silently turned into
  /// something else.
  static String expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = _homePath;
    if (home == null) return path;
    return path.replaceFirst('~', home);
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
      Loggers.app.info(
        'SSH config file does not exist at path: ${configPath ?? _defaultPath}',
      );
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
    String? proxyCommand;

    void addServer() {
      if (currentHost != null && currentHost != '*' && hostname != null) {
        final normalizedProxyCommand = proxyCommand?.trim();
        final resolvedProxyCommand =
            normalizedProxyCommand == null || normalizedProxyCommand.isEmpty
            ? null
            : normalizedProxyCommand;
        final resolvedJumpHost = resolvedProxyCommand != null ? null : jumpHost;
        if (resolvedProxyCommand != null && jumpHost != null) {
          Loggers.app.info(
            'SSH config host $currentHost defines both ProxyJump and '
            'ProxyCommand; preferring ProxyCommand.',
          );
        }
        final spi = Spi(
          id: ShortId.generate(),
          name: currentHost,
          ssh: SshCredential(
            ip: hostname,
            port: port,
            user: user ?? 'root', // Default user is 'root'
            // A path, not a store id — see `SshCredential.keyPath`. Putting it
            // in `keyId` is what made every imported host with an IdentityFile
            // fail to connect.
            keyPath: identityFile,
            jumpId: resolvedJumpHost,
            proxyCommand: resolvedProxyCommand,
          ),
        );
        final validationError = spi.validate();
        if (validationError != null) {
          Loggers.app.warning(
            'Skipping invalid SSH config host $currentHost: $validationError',
          );
          return;
        }
        servers.add(spi);
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Handle inline comments
      final cleanLine = _stripInlineComment(trimmed);
      if (cleanLine.isEmpty) continue;

      final parts = cleanLine.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final key = parts[0].toLowerCase();
      var value = parts.sublist(1).join(' ');

      // Remove quotes from values
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
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
          proxyCommand = null;
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
          // Kept verbatim, `~` and all: it is resolved when the connection is
          // made, on the machine the file is on
          identityFile = value;
          break;

        case 'proxyjump':
          jumpHost = _extractJumpHost(value);
          break;
        case 'proxycommand':
          proxyCommand = value;
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

  static String _stripInlineComment(String line) {
    var inSingleQuotes = false;
    var inDoubleQuotes = false;
    var escaped = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }
      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
        continue;
      }
      if (char == '#' &&
          !inSingleQuotes &&
          !inDoubleQuotes &&
          (i == 0 || line[i - 1].trim().isEmpty)) {
        return line.substring(0, i).trim();
      }
    }

    return line.trim();
  }

  @visibleForTesting
  static String stripInlineCommentForTest(String line) {
    return _stripInlineComment(line);
  }

  /// Check if SSH config file exists, trying multiple possible paths
  static (File?, bool) configExists([String? configPath]) {
    if (configPath != null) {
      // If specific path is provided, use it directly
      final homePath = _homePath;
      if (homePath == null) {
        Loggers.app.warning(
          'Cannot determine home directory for SSH config parsing.',
        );
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

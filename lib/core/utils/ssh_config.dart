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
    return _expandTilde(path);
  }

  static String expandIdentityFile(
    String path, {
    required String hostname,
    required String remoteUser,
    String? originalHost,
    int port = 22,
  }) {
    final home = _homePath ?? '';
    final localUser =
        Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '';
    const escapedPercent = '\u0000SSH_PERCENT\u0000';
    final expanded = path
        .replaceAll('%%', escapedPercent)
        .replaceAll('%d', home)
        .replaceAll('%u', localUser)
        .replaceAll('%h', hostname)
        .replaceAll('%n', originalHost ?? hostname)
        .replaceAll('%p', '$port')
        .replaceAll('%r', remoteUser)
        .replaceAll(escapedPercent, '%');
    return _expandTilde(expanded);
  }

  static String _expandTilde(String path) {
    if (!path.startsWith('~')) return path;
    final separator = path.indexOf(RegExp(r'[/\\]'));
    final user = path.substring(1, separator == -1 ? path.length : separator);
    final suffix = separator == -1 ? '' : path.substring(separator);
    if (user.isEmpty) {
      final home = _homePath;
      return home == null ? path : '$home$suffix';
    }

    final localUser =
        Platform.environment['USER'] ?? Platform.environment['USERNAME'];
    if (user == localUser && _homePath != null) return '$_homePath$suffix';
    if (!Platform.isWindows && RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(user)) {
      try {
        for (final line in File('/etc/passwd').readAsLinesSync()) {
          final fields = line.split(':');
          if (fields.length > 5 && fields.first == user) {
            return '${fields[5]}$suffix';
          }
        }
      } catch (_) {}
    }
    return path;
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
    final (file, exists) = await configExistsAsync(configPath);
    if (!exists || file == null) {
      Loggers.app.info(
        'SSH config file does not exist at path: ${configPath ?? _defaultPath}',
      );
      return [];
    }

    // Guard against unbounded config files.
    const maxSize = 1024 * 1024; // 1 MB
    final stat = await file.stat();
    if (stat.size > maxSize) {
      Loggers.app.warning(
        'SSH config file too large (${stat.size} bytes), refusing to read',
      );
      return [];
    }
    final content = await file.readAsString();
    return _parseSSHConfig(content);
  }

  /// Parse SSH config content
  static List<Spi> _parseSSHConfig(String content) {
    final blocks = <_SSHConfigBlock>[
      _SSHConfigBlock(const ['*']),
    ];
    var current = blocks.first;

    for (final line in content.split('\n')) {
      final cleanLine = _stripInlineComment(line.trim());
      if (cleanLine.isEmpty) continue;
      final match = RegExp(r'^(\S+)\s+(.+)$').firstMatch(cleanLine);
      if (match == null) continue;
      final key = match.group(1)!.toLowerCase();
      final rawValue = match.group(2)!.trim();
      if (key == 'host') {
        final patterns = _splitWords(rawValue);
        if (patterns.isEmpty) continue;
        current = _SSHConfigBlock(patterns);
        blocks.add(current);
      } else {
        current.options.add((key, rawValue));
      }
    }

    final aliases = <String>[];
    for (final block in blocks.skip(1)) {
      for (final pattern in block.patterns) {
        if (_isConcreteHost(pattern) && !aliases.contains(pattern)) {
          aliases.add(pattern);
        }
      }
    }

    final servers = <Spi>[];
    final jumpSpecs = <String, List<String>>{};
    for (final alias in aliases) {
      String? hostname;
      String? user;
      int? port;
      String? proxyJump;
      String? proxyCommand;
      final identityFiles = <String>[];

      for (final block in blocks) {
        if (!_hostMatches(block.patterns, alias)) continue;
        for (final option in block.options) {
          final value = option.$1 == 'proxycommand'
              ? option.$2.trim()
              : _decodeValue(option.$2);
          switch (option.$1) {
            case 'hostname' when hostname == null:
              hostname = value;
            case 'user' when user == null:
              user = value;
            case 'port' when port == null:
              final parsed = int.tryParse(value);
              port = parsed != null && parsed >= 1 && parsed <= 65535
                  ? parsed
                  : 22;
            case 'identityfile':
              if (value.toLowerCase() != 'none' &&
                  value.isNotEmpty &&
                  !identityFiles.contains(value)) {
                identityFiles.add(value);
              }
            case 'proxyjump' when proxyJump == null:
              proxyJump = value;
            case 'proxycommand' when proxyCommand == null:
              proxyCommand = value;
          }
        }
      }

      if (hostname == null || hostname.isEmpty) continue;
      final normalizedProxy = proxyCommand?.trim();
      final resolvedProxy =
          normalizedProxy == null ||
              normalizedProxy.isEmpty ||
              normalizedProxy.toLowerCase() == 'none'
          ? null
          : normalizedProxy;
      final configuredJumps = _splitProxyJumps(proxyJump);
      final jumps = resolvedProxy == null ? configuredJumps : const <String>[];
      if (resolvedProxy != null && configuredJumps.isNotEmpty) {
        Loggers.app.info(
          'SSH config host $alias defines both ProxyJump and ProxyCommand; '
          'preferring ProxyCommand.',
        );
      }
      if (resolvedProxy != null && resolvedProxy.length > 4096) {
        Loggers.app.warning(
          'SSH config host $alias ProxyCommand too long, skipping host',
        );
        continue;
      }

      final spi = Spi(
        id: ShortId.generate(),
        name: alias,
        ssh: SshCredential(
          ip: hostname,
          port: port ?? 22,
          user: user ?? 'root',
          keyPath: identityFiles.isEmpty ? null : identityFiles.first,
          identityFiles: identityFiles.length > 1 ? identityFiles : null,
          proxyCommand: resolvedProxy,
        ),
      );
      final validationError = spi.validate();
      if (validationError != null) {
        Loggers.app.warning(
          'Skipping invalid SSH config host $alias: $validationError',
        );
        continue;
      }
      servers.add(spi);
      if (jumps.isNotEmpty) jumpSpecs[spi.id] = jumps;
    }

    final byName = {for (final server in servers) server.name: server};
    final byHostname = <String, Spi>{};
    for (final server in servers) {
      final ip = server.ssh?.ip;
      if (ip != null && ip.isNotEmpty) byHostname[ip] = server;
    }
    final derived = <String, Spi>{};
    final invalidJumpOwners = <String>{};
    for (var i = 0; i < servers.length; i++) {
      final specs = jumpSpecs[servers[i].id];
      if (specs == null) continue;
      final jumpIds = <String>[];
      for (final raw in specs) {
        final spec = _parseJumpSpec(raw);
        var base = byName[spec.host] ?? byHostname[spec.host];
        if (base == null) {
          if (spec.host.isEmpty || spec.host == servers[i].name) {
            Loggers.app.warning(
              'SSH config ProxyJump "$raw" has no usable host',
            );
            continue;
          }
          final cacheKey = [
            'direct',
            spec.host,
            spec.user ?? '',
            spec.port ?? '',
          ].join('\u0000');
          base = derived.putIfAbsent(
            cacheKey,
            () => Spi(
              id: ShortId.generate(),
              name: raw,
              ssh: SshCredential(
                ip: spec.host,
                user: spec.user ?? 'root',
                port: spec.port ?? 22,
              ),
            ),
          );
        }
        if (base.id == servers[i].id) {
          Loggers.app.warning(
            'SSH config ProxyJump "$raw" points back to its own Host',
          );
          continue;
        }
        final resolvedBase = base;
        if (spec.user == null && spec.port == null) {
          jumpIds.add(resolvedBase.id);
          continue;
        }
        final cacheKey =
            '${resolvedBase.id}\u0000${spec.user ?? ''}\u0000${spec.port ?? ''}';
        final override = derived.putIfAbsent(cacheKey, () {
          final baseSsh = resolvedBase.ssh!;
          return resolvedBase.copyWith(
            id: ShortId.generate(),
            name:
                '${resolvedBase.name} (${spec.user ?? baseSsh.user}@${spec.port ?? baseSsh.port})',
            ssh: baseSsh.copyWith(
              user: spec.user ?? baseSsh.user,
              port: spec.port ?? baseSsh.port,
            ),
          );
        });
        jumpIds.add(override.id);
      }
      if (jumpIds.isNotEmpty) {
        final old = servers[i];
        servers[i] = old.copyWith(
          ssh: old.ssh!.copyWith(jumpId: jumpIds.first, jumpIds: jumpIds),
        );
      } else {
        invalidJumpOwners.add(servers[i].id);
      }
    }
    servers.removeWhere((server) => invalidJumpOwners.contains(server.id));
    servers.addAll(derived.values);
    final validIds = servers.map((server) => server.id).toSet();
    for (var i = 0; i < servers.length; i++) {
      final ssh = servers[i].ssh;
      if (ssh == null || ssh.resolvedJumpIds.isEmpty) continue;
      final filtered = ssh.resolvedJumpIds.where(validIds.contains).toList();
      if (filtered.length == ssh.resolvedJumpIds.length) continue;
      servers[i] = servers[i].copyWith(
        ssh: ssh.copyWith(
          jumpId: filtered.firstOrNull,
          jumpIds: filtered.isEmpty ? null : filtered,
        ),
      );
    }
    return servers;
  }

  static List<String> _splitWords(String value) {
    final words = <String>[];
    final current = StringBuffer();
    String? quote;
    var escaped = false;
    var started = false;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      if (escaped) {
        current.write(char);
        escaped = false;
        started = true;
      } else if (char == r'\') {
        escaped = true;
        started = true;
      } else if (quote != null) {
        if (char == quote) {
          quote = null;
        } else {
          current.write(char);
        }
        started = true;
      } else if (char == '"' || char == "'") {
        quote = char;
        started = true;
      } else if (RegExp(r'\s').hasMatch(char)) {
        if (started) {
          words.add(current.toString());
          current.clear();
          started = false;
        }
      } else {
        current.write(char);
        started = true;
      }
    }
    if (escaped) current.write(r'\');
    if (started) words.add(current.toString());
    return words;
  }

  static String _decodeValue(String value) => _splitWords(value).join(' ');

  static bool _isConcreteHost(String pattern) {
    if (pattern.startsWith('!')) return false;
    return !pattern.contains(RegExp(r'[?*\[]'));
  }

  static bool _hostMatches(List<String> patterns, String host) {
    var matched = false;
    for (var pattern in patterns) {
      final negated = pattern.startsWith('!');
      if (negated) pattern = pattern.substring(1);
      if (!_globMatches(pattern, host)) continue;
      if (negated) return false;
      matched = true;
    }
    return matched;
  }

  static bool _globMatches(String pattern, String value) {
    final regex = StringBuffer('^');
    for (final rune in pattern.runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case '*':
          regex.write('.*');
        case '?':
          regex.write('.');
        default:
          regex.write(RegExp.escape(char));
      }
    }
    regex.write(r'$');
    return RegExp(regex.toString(), caseSensitive: false).hasMatch(value);
  }

  static List<String> _splitProxyJumps(String? value) {
    if (value == null ||
        value.trim().isEmpty ||
        value.toLowerCase() == 'none') {
      return const [];
    }
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static ({String host, String? user, int? port}) _parseJumpSpec(String value) {
    var hostPort = value.trim();
    String? user;
    final at = hostPort.lastIndexOf('@');
    if (at >= 0) {
      user = hostPort.substring(0, at).selfNotEmptyOrNull;
      hostPort = hostPort.substring(at + 1);
    }
    String host = hostPort;
    int? port;
    if (hostPort.startsWith('[')) {
      final end = hostPort.indexOf(']');
      if (end > 0) {
        host = hostPort.substring(1, end);
        if (end + 1 < hostPort.length && hostPort[end + 1] == ':') {
          port = int.tryParse(hostPort.substring(end + 2));
        }
      }
    } else {
      final colon = hostPort.lastIndexOf(':');
      if (colon > 0 && hostPort.indexOf(':') == colon) {
        final parsed = int.tryParse(hostPort.substring(colon + 1));
        if (parsed != null) {
          host = hostPort.substring(0, colon);
          port = parsed;
        }
      }
    }
    if (port != null && (port < 1 || port > 65535)) port = null;
    return (host: host, user: user, port: port);
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

  /// Async variant of [configExists] that avoids blocking the UI thread.
  static Future<(File?, bool)> configExistsAsync([String? configPath]) async {
    if (configPath != null) {
      final homePath = _homePath;
      if (homePath == null) {
        Loggers.app.warning(
          'Cannot determine home directory for SSH config parsing.',
        );
        return (null, false);
      }
      final expandedPath = configPath.replaceFirst('~', homePath);
      final file = File(expandedPath);
      return (file, await file.exists());
    }
    for (final path in _possibleConfigPaths) {
      final file = File(path);
      if (await file.exists()) return (file, true);
    }
    return (null, false);
  }
}

final class _SSHConfigBlock {
  _SSHConfigBlock(this.patterns);

  final List<String> patterns;
  final List<(String, String)> options = [];
}

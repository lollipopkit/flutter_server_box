import 'dart:convert';

import 'package:server_box/data/res/build_data.dart';

/// Constants used throughout the script system
class ScriptConstants {
  const ScriptConstants._();

  // Script file names
  static const String scriptFile = 'srvboxm_v${BuildData.script}.sh';
  static const String scriptFileWindows = 'srvboxm_v${BuildData.script}.ps1';

  // Script directories
  static const String scriptDirHome = '~/.config/server_box';
  static const String scriptDirTmp = '/tmp/server_box';
  static const String scriptDirHomeWindows =
      r'$env:USERPROFILE/.config/server_box';
  static const String scriptDirTmpWindows = r'$env:TEMP/server_box';

  // Command separators and dividers
  static const String separator = 'SrvBoxSep';

  /// Custom command separator
  static const String customCmdSep = 'SrvBoxCusCmdSep';

  /// Prefix applied to every command output line so output cannot be confused
  /// with a section marker.
  static const String dataPrefix = 'SrvBoxData.';

  static const String _encodedNamePrefix = 'b64.';

  static String _encodeName(String name) => base64Url.encode(utf8.encode(name));

  /// Generate command-specific separator
  static String getCmdSeparator(String cmdName) =>
      '$separator.$_encodedNamePrefix${_encodeName(cmdName)}';

  /// Generate command-specific divider for custom commands
  static String getCustomCmdSeparator(String cmdName) =>
      '$customCmdSep.$_encodedNamePrefix${_encodeName(cmdName)}';

  /// Internal result-map key for custom commands. This keeps arbitrary custom
  /// names from overwriting built-in status sections with the same name.
  static String getCustomResultKey(String cmdName) => '$customCmdSep.$cmdName';

  /// Generate command-specific divider
  static String getCmdDivider(String cmdName) =>
      '\necho ${getCmdSeparator(cmdName)}\n\t';

  /// Generate command-specific divider for Windows PowerShell
  static String getWindowsCmdDivider(String cmdName) =>
      '\n    Write-Host "${getCmdSeparator(cmdName)}"\n    ';

  /// Parse script output into command-specific map
  static Map<String, String> parseScriptOutput(String raw) {
    final result = <String, String>{};

    if (raw.isEmpty) return result;

    // Parse line by line to properly handle command-specific separators
    final lines = raw.split('\n');
    String? currentKey;
    var framedOutput = false;
    final buffer = <String>[];

    void flush() {
      final key = currentKey;
      if (key == null) return;
      final output = buffer.join('\n');
      result[key] = framedOutput ? output : output.trim();
      buffer.clear();
    }

    for (final (index, rawLine) in lines.indexed) {
      if (index == lines.length - 1 && rawLine.isEmpty) continue;
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      final marker = _parseMarker(line);
      if (marker != null) {
        flush();
        currentKey = marker.custom
            ? getCustomResultKey(marker.name)
            : marker.name;
        framedOutput = marker.framed;
      } else if (currentKey != null) {
        buffer.add(
          framedOutput && line.startsWith(dataPrefix)
              ? line.substring(dataPrefix.length)
              : line,
        );
      }
    }

    flush();

    return result;
  }

  static ({String name, bool framed, bool custom})? _parseMarker(String line) {
    final isCustom = line.startsWith('$customCmdSep.');
    final prefix = line.startsWith('$separator.')
        ? '$separator.'
        : isCustom
        ? '$customCmdSep.'
        : null;
    if (prefix == null) return null;
    final value = line.substring(prefix.length);
    // Unframed legacy markers are ambiguous with ordinary command output.
    // Only the encoded/framed protocol can distinguish data from delimiters.
    if (!value.startsWith(_encodedNamePrefix)) return null;
    try {
      return (
        name: utf8.decode(
          base64Url.decode(value.substring(_encodedNamePrefix.length)),
        ),
        framed: true,
        custom: isCustom,
      );
    } catch (_) {
      return null;
    }
  }

  // Path separators
  static const String unixPathSeparator = '/';
  static const String windowsPathSeparator = '\\';

  // Script headers
  static const String unixScriptHeader =
      '''
#!/bin/sh
# Script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

export LANG=en_US.UTF-8

# If macSign & bsdSign are both empty, then it's linux
macSign=\$(uname -a 2>&1 | grep "Darwin")
bsdSign=\$(uname -a 2>&1 | grep "BSD")

# Link /bin/sh to busybox?
isBusybox=\$(ls -l /bin/sh | grep "busybox")

userId=\$(id -u)

exec 2>/dev/null

''';

  static const String windowsScriptHeader =
      '''
# PowerShell script for ServerBox app v1.0.${BuildData.build}
# DO NOT delete this file while app is running

\$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

''';
}

/// Script path configuration and management
class ScriptPaths {
  ScriptPaths._();

  static final Map<(String, bool), String> _scriptDirMap =
      <(String, bool), String>{};

  /// Get the script directory for the given [id].
  ///
  /// Default is [ScriptConstants.scriptDirTmp]/[ScriptConstants.scriptFile],
  /// if this path is not accessible, it will be changed to
  /// [ScriptConstants.scriptDirHome]/[ScriptConstants.scriptFile].
  static String getScriptDir(String id, {bool isWindows = false}) {
    final key = (id, isWindows);
    final defaultTmpDir = isWindows
        ? ScriptConstants.scriptDirTmpWindows
        : ScriptConstants.scriptDirTmp;
    _scriptDirMap[key] ??= defaultTmpDir;
    return _scriptDirMap[key]!;
  }

  /// Switch between tmp and home directories for script storage
  static String switchScriptDir(String id, {bool isWindows = false}) {
    final key = (id, isWindows);
    return switch (_scriptDirMap[key]) {
      ScriptConstants.scriptDirTmp =>
        _scriptDirMap[key] = ScriptConstants.scriptDirHome,
      ScriptConstants.scriptDirTmpWindows =>
        _scriptDirMap[key] = ScriptConstants.scriptDirHomeWindows,
      ScriptConstants.scriptDirHome =>
        _scriptDirMap[key] = ScriptConstants.scriptDirTmp,
      ScriptConstants.scriptDirHomeWindows =>
        _scriptDirMap[key] = ScriptConstants.scriptDirTmpWindows,
      _ =>
        _scriptDirMap[key] = isWindows
            ? ScriptConstants.scriptDirHomeWindows
            : ScriptConstants.scriptDirHome,
    };
  }

  /// Get the full script path for the given [id]
  static String getScriptPath(String id, {bool isWindows = false}) {
    final dir = getScriptDir(id, isWindows: isWindows);
    final fileName = isWindows
        ? ScriptConstants.scriptFileWindows
        : ScriptConstants.scriptFile;
    final separator = isWindows
        ? ScriptConstants.windowsPathSeparator
        : ScriptConstants.unixPathSeparator;
    return '$dir$separator$fileName';
  }

  /// Clear cached script directories (useful for testing)
  static void clearCache() {
    _scriptDirMap.clear();
  }
}

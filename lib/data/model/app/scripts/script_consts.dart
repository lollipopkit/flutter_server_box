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
  static const String scriptDirHomeWindows = '%USERPROFILE%/.config/server_box';
  static const String scriptDirTmpWindows = '%TEMP%/server_box';

  // Command separators and dividers
  static const String separator = 'SrvBoxSep';

  /// Custom command separator
  static const String customCmdSep = 'SrvBoxCusCmdSep';

  /// Generate command-specific separator
  static String getCmdSeparator(String cmdName) => '$separator.$cmdName';

  /// Generate command-specific divider for custom commands
  static String getCustomCmdSeparator(String cmdName) => '$customCmdSep.$cmdName';

  /// Generate command-specific divider
  static String getCmdDivider(String cmdName) => '\necho ${getCmdSeparator(cmdName)}\n\t';

  /// Parse script output into command-specific map
  static Map<String, String> parseScriptOutput(String raw) {
    final result = <String, String>{};

    if (raw.isEmpty) return result;

    // Parse line by line to properly handle command-specific separators
    final lines = raw.split('\n');
    String? currentCmd;
    final buffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('$separator.')) {
        // Save previous command content
        if (currentCmd != null) {
          result[currentCmd] = buffer.toString().trim();
          buffer.clear();
        }
        // Start new command
        currentCmd = line.substring('$separator.'.length);
      } else if (line.startsWith('$customCmdSep.')) {
        // Save previous command content
        if (currentCmd != null) {
          result[currentCmd] = buffer.toString().trim();
          buffer.clear();
        }
        // Start new custom command
        currentCmd = line.substring('$customCmdSep.'.length);
      } else if (currentCmd != null) {
        buffer.writeln(line);
      }
    }

    // Don't forget the last command
    if (currentCmd != null) {
      result[currentCmd] = buffer.toString().trim();
    }

    return result;
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

''';
}

/// Script path configuration and management
class ScriptPaths {
  ScriptPaths._();

  static final Map<String, String> _scriptDirMap = <String, String>{};

  /// Get the script directory for the given [id].
  ///
  /// Default is [ScriptConstants.scriptDirTmp]/[ScriptConstants.scriptFile],
  /// if this path is not accessible, it will be changed to
  /// [ScriptConstants.scriptDirHome]/[ScriptConstants.scriptFile].
  static String getScriptDir(String id, {bool isWindows = false}) {
    final defaultTmpDir = isWindows ? ScriptConstants.scriptDirTmpWindows : ScriptConstants.scriptDirTmp;
    _scriptDirMap[id] ??= defaultTmpDir;
    return _scriptDirMap[id]!;
  }

  /// Switch between tmp and home directories for script storage
  static String switchScriptDir(String id, {bool isWindows = false}) {
    return switch (_scriptDirMap[id]) {
      ScriptConstants.scriptDirTmp => _scriptDirMap[id] = ScriptConstants.scriptDirHome,
      ScriptConstants.scriptDirTmpWindows => _scriptDirMap[id] = ScriptConstants.scriptDirHomeWindows,
      ScriptConstants.scriptDirHome => _scriptDirMap[id] = ScriptConstants.scriptDirTmp,
      ScriptConstants.scriptDirHomeWindows => _scriptDirMap[id] = ScriptConstants.scriptDirTmpWindows,
      _ =>
        _scriptDirMap[id] = isWindows ? ScriptConstants.scriptDirHomeWindows : ScriptConstants.scriptDirHome,
    };
  }

  /// Get the full script path for the given [id]
  static String getScriptPath(String id, {bool isWindows = false}) {
    final dir = getScriptDir(id, isWindows: isWindows);
    final fileName = isWindows ? ScriptConstants.scriptFileWindows : ScriptConstants.scriptFile;
    final separator = isWindows ? ScriptConstants.windowsPathSeparator : ScriptConstants.unixPathSeparator;
    return '$dir$separator$fileName';
  }

  /// Clear cached script directories (useful for testing)
  static void clearCache() {
    _scriptDirMap.clear();
  }
}

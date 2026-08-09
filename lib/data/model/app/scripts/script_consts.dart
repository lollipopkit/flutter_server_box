
import 'package:server_box/data/res/build_data.dart';

/// Path constants and per-connection script directory state.
///
/// Script content, dividers, headers, and output splitting live in the shared
/// Rust library (sbm_parser::script, see the shared-parser design); only path/filename
/// conventions and Flutter-connection state remain here.
// TODO(migration): residue of the Dart script layer — reevaluate once the app
// endpoints move fully onto the FFI script API.
class ScriptConstants {
  const ScriptConstants._();

  // Script file names (versioned: bumping BuildData.script forces re-upload)
  static const String scriptFile = 'srvboxm_v${BuildData.script}.sh';
  static const String scriptFileWindows = 'srvboxm_v${BuildData.script}.ps1';

  // Script directories
  static const String scriptDirHome = '~/.config/server_box';
  static const String scriptDirTmp = '/tmp/server_box';
  static const String scriptDirHomeWindows =
      r'$env:USERPROFILE/.config/server_box';
  static const String scriptDirTmpWindows = r'$env:TEMP/server_box';

  /// Output segment separator (mirrors sbm_parser commands::SEPARATOR); also
  /// used by container/systemd providers for their own command segmenting
  static const String separator = 'SrvBoxSep';

  // Path separators
  static const String unixPathSeparator = '/';
  static const String windowsPathSeparator = '\\';
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

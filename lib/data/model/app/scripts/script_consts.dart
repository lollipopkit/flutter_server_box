
/// Path constants and per-connection script directory state.
///
/// Script content, markers, headers, and output splitting live in the shared
/// Rust library (`sbm_parser::script`); only path/filename conventions and
/// Flutter-connection state remain here.
// TODO(migration): residue of the Dart script layer — reevaluate once the app
// endpoints move fully onto the FFI script API.
class ScriptConstants {
  const ScriptConstants._();

  /// The number in the remote script's filename.
  ///
  /// It must only increase, and it must increase whenever the generated script
  /// changes: the name is what decides whether a server reuses the copy it
  /// already has. Two builds writing different scripts under one name is the
  /// failure this exists to prevent.
  ///
  /// A plain constant, here. It was a Git-history count computed during the
  /// build, whose result varied with the source paths and with whether a build
  /// went through `fl_build` at all — so it became a hand-maintained number,
  /// and then a hand-maintained number in *two* files with a test holding them
  /// level, because `fl_build` regenerates `BuildData` and drops anything it
  /// was not fed.
  static const int version = 77;

  static const String scriptFile = 'srvboxm_v$version.sh';
  static const String scriptFileWindows = 'srvboxm_v$version.ps1';

  // Script directories
  static const String scriptDirHome = '~/.config/server_box';
  static const String scriptDirTmp = '/tmp/server_box';
  static const String scriptDirHomeWindows =
      r'$env:USERPROFILE/.config/server_box';
  static const String scriptDirTmpWindows = r'$env:TEMP/server_box';

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

}

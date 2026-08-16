import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/src/rust/api/script.dart' as ffi;

/// Shell functions of the generated script.
///
/// The FRB-generated enum is the single source; function names, flags, and
/// script generation live in the shared Rust library (sbm_parser::script, see
/// the shared-parser design). This file only maps app types onto the FFI and keeps the
/// connection-state concerns (script paths, custom dirs).
typedef ShellFunc = ffi.ShellFuncKind;

extension ShellFuncX on ShellFunc {
  /// Command line flag for this function (wire format owned by Rust)
  String get flag => ffi.shellFuncFlag(func: this);

  /// Execute this shell function on the specified server
  String exec(String id, {SystemType? systemType, required String? customDir}) {
    final scriptPath = ShellFuncManager.getScriptPath(
      id,
      systemType: systemType,
      customDir: customDir,
    );
    return ffi.execCommand(
      system: ShellFuncManager.ffiSystem(systemType),
      scriptPath: scriptPath,
      func: this,
    );
  }
}

/// Manager class for shell function operations
class ShellFuncManager {
  const ShellFuncManager._();

  /// System string used by the FFI ("linux" | "bsd" | "windows");
  /// null defaults to linux (linux and bsd produce the same Unix script)
  static String ffiSystem(SystemType? systemType) => switch (systemType) {
    SystemType.windows => 'windows',
    SystemType.bsd => 'bsd',
    _ => 'linux',
  };

  /// Normalize a directory path to ensure it doesn't end with trailing separators
  static String _normalizeDir(String dir, bool isWindows) {
    final separator = isWindows
        ? ScriptConstants.windowsPathSeparator
        : ScriptConstants.unixPathSeparator;

    // Remove all trailing separators
    final pattern = RegExp('${RegExp.escape(separator)}+\$');
    return dir.replaceAll(pattern, '');
  }

  /// Get the script directory for the given [id].
  ///
  /// Checks for custom script directory first, then falls back to default.
  static String getScriptDir(
    String id, {
    SystemType? systemType,
    required String? customDir,
  }) {
    final isWindows = systemType == SystemType.windows;

    if (customDir != null) return _normalizeDir(customDir, isWindows);
    return ScriptPaths.getScriptDir(id, isWindows: isWindows);
  }

  /// Switch between tmp and home directories for script storage
  static void switchScriptDir(String id, {SystemType? systemType}) {
    final isWindows = systemType == SystemType.windows;
    ScriptPaths.switchScriptDir(id, isWindows: isWindows);
  }

  /// Get the full script path for the given [id]
  static String getScriptPath(
    String id, {
    SystemType? systemType,
    required String? customDir,
  }) {
    final isWindows = systemType == SystemType.windows;
    if (customDir != null) {
      final normalizedDir = _normalizeDir(customDir, isWindows);
      final fileName = isWindows
          ? ScriptConstants.scriptFileWindows
          : ScriptConstants.scriptFile;
      final separator = isWindows
          ? ScriptConstants.windowsPathSeparator
          : ScriptConstants.unixPathSeparator;
      return '$normalizedDir$separator$fileName';
    }

    return ScriptPaths.getScriptPath(id, isWindows: isWindows);
  }

  /// Get the installation shell command for the script
  static String getInstallShellCmd(
    String id, {
    SystemType? systemType,
    required String? customDir,
  }) {
    final scriptDir = getScriptDir(
      id,
      systemType: systemType,
      customDir: customDir,
    );
    final isWindows = systemType == SystemType.windows;
    final normalizedDir = _normalizeDir(scriptDir, isWindows);
    final fileName = isWindows
        ? ScriptConstants.scriptFileWindows
        : ScriptConstants.scriptFile;
    final separator = isWindows
        ? ScriptConstants.windowsPathSeparator
        : ScriptConstants.unixPathSeparator;
    final scriptPath = '$normalizedDir$separator$fileName';

    return ffi.installCommand(
      system: ffiSystem(systemType),
      scriptDir: normalizedDir,
      scriptPath: scriptPath,
    );
  }

  /// Generate complete script based on system type.
  ///
  /// No longer a function of the user's custom commands: those are files in a
  /// directory beside the script, which the script reads. So these bytes
  /// change only when the app does, and a command with a stray quote in it
  /// breaks that command rather than the whole status page.
  static String allScript({
    SystemType? systemType,
    List<String>? disabledCmdTypes,
  }) {
    return ffi.buildScript(
      system: ffiSystem(systemType),
      disabled: disabledCmdTypes ?? const [],
      buildNumber: '${BuildData.build}',
    );
  }

  /// What the directory-writing script is fed to, or null where it is already
  /// a command.
  ///
  /// Unix reads it on stdin, so nothing in a user's command has to survive
  /// shell quoting. The Windows form is a base64-wrapped PowerShell command
  /// line for the same reason the script installer is: a host whose OpenSSH
  /// default shell is cmd.exe would mangle the raw syntax.
  static String? customCmdsInstallEntry(SystemType? systemType) =>
      systemType == SystemType.windows ? null : 'sh';

  /// The command that writes those files, in one round trip.
  ///
  /// Their order is their position here, spaced so that moving one between two
  /// others later renames a single file instead of renumbering the set.
  static String installCustomCmds(
    Map<String, String>? customCmds, {
    required String scriptDir,
    SystemType? systemType,
  }) {
    return ffi.installCustomCmdsCommand(
      system: ffiSystem(systemType),
      scriptDir: scriptDir,
      cmds: [
        for (final e in (customCmds ?? const {}).entries)
          ffi.CustomCmd(name: e.key, cmd: e.value),
      ],
    );
  }
}

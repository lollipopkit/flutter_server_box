import 'package:server_box/data/model/app/scripts/script_builders.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server.dart';

/// Shell functions available in the ServerBox application
enum ShellFunc {
  status('SbStatus'),
  process('SbProcess'),
  shutdown('SbShutdown'),
  reboot('SbReboot'),
  suspend('SbSuspend');

  /// The function name used in scripts
  final String name;

  const ShellFunc(this.name);

  /// Get the command line flag for this function
  String get flag => switch (this) {
    ShellFunc.process => 'p',
    ShellFunc.shutdown => 'sd',
    ShellFunc.reboot => 'r',
    ShellFunc.suspend => 'sp',
    ShellFunc.status => 's',
  };

  /// Execute this shell function on the specified server
  String exec(String id, {SystemType? systemType}) {
    final scriptPath = ShellFuncManager.getScriptPath(id, systemType: systemType);
    final isWindows = systemType == SystemType.windows;
    final builder = ScriptBuilderFactory.getBuilder(isWindows);

    return builder.getExecCommand(scriptPath, this);
  }
}

/// Manager class for shell function operations
class ShellFuncManager {
  const ShellFuncManager._();

  /// Normalize a directory path to ensure it doesn't end with trailing separators
  static String _normalizeDir(String dir, bool isWindows) {
    final separator = isWindows ? ScriptConstants.windowsPathSeparator : ScriptConstants.unixPathSeparator;

    // Remove all trailing separators
    final pattern = RegExp('${RegExp.escape(separator)}+\$');
    return dir.replaceAll(pattern, '');
  }

  /// Get the script directory for the given [id].
  ///
  /// Checks for custom script directory first, then falls back to default.
  static String getScriptDir(String id, {SystemType? systemType}) {
    final customScriptDir = ServerProvider.pick(id: id)?.value.spi.custom?.scriptDir;
    final isWindows = systemType == SystemType.windows;

    if (customScriptDir != null) return _normalizeDir(customScriptDir, isWindows);
    return ScriptPaths.getScriptDir(id, isWindows: isWindows);
  }

  /// Switch between tmp and home directories for script storage
  static void switchScriptDir(String id, {SystemType? systemType}) {
    final isWindows = systemType == SystemType.windows;
    ScriptPaths.switchScriptDir(id, isWindows: isWindows);
  }

  /// Get the full script path for the given [id]
  static String getScriptPath(String id, {SystemType? systemType}) {
    final customScriptDir = ServerProvider.pick(id: id)?.value.spi.custom?.scriptDir;
    if (customScriptDir != null) {
      final isWindows = systemType == SystemType.windows;
      final normalizedDir = _normalizeDir(customScriptDir, isWindows);
      final fileName = isWindows ? ScriptConstants.scriptFileWindows : ScriptConstants.scriptFile;
      final separator = isWindows ? ScriptConstants.windowsPathSeparator : ScriptConstants.unixPathSeparator;
      return '$normalizedDir$separator$fileName';
    }

    final isWindows = systemType == SystemType.windows;
    return ScriptPaths.getScriptPath(id, isWindows: isWindows);
  }

  /// Get the installation shell command for the script
  static String getInstallShellCmd(String id, {SystemType? systemType}) {
    final scriptDir = getScriptDir(id, systemType: systemType);
    final isWindows = systemType == SystemType.windows;
    final normalizedDir = _normalizeDir(scriptDir, isWindows);
    final builder = ScriptBuilderFactory.getBuilder(isWindows);
    final separator = isWindows ? ScriptConstants.windowsPathSeparator : ScriptConstants.unixPathSeparator;
    final scriptPath = '$normalizedDir$separator${builder.scriptFileName}';

    return builder.getInstallCommand(normalizedDir, scriptPath);
  }

  /// Generate complete script based on system type
  static String allScript(
    Map<String, String>? customCmds, {
    SystemType? systemType,
    List<String>? disabledCmdTypes,
  }) {
    final isWindows = systemType == SystemType.windows;
    final builder = ScriptBuilderFactory.getBuilder(isWindows);

    return builder.buildScript(customCmds, disabledCmdTypes);
  }
}

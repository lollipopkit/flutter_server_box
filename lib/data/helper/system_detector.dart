import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';

/// Detects the operating system exposed by a remote SSH server.
class SystemDetector {
  /// Returns the configured system type or detects it from remote commands.
  ///
  /// First checks if a custom system type is configured in [spi].
  /// If not, attempts to detect the system by running commands:
  /// 1. 'uname -a' command to detect Linux/BSD/Darwin
  /// 2. 'ver' command to detect Windows (if uname fails)
  ///
  /// Returns [SystemType.linux] as default if detection fails.
  static Future<SystemType> detect(SSHClient client, Spi spi) async {
    SystemType? detectedSystemType = spi.customSystemType;
    if (detectedSystemType != null) {
      dprint(
        'Using custom system type ${detectedSystemType.name} for ${spi.oldId}',
      );
      return detectedSystemType;
    }

    try {
      // `uname` is the least invasive probe and identifies Unix-like systems.
      final unixResult = await client.runSafe(
        'uname -a 2>/dev/null',
        context: 'uname detection for ${spi.oldId}',
      );
      if (unixResult.contains('Linux')) {
        detectedSystemType = SystemType.linux;
        dprint('Detected Linux system type for ${spi.oldId}');
        return detectedSystemType;
      } else if (unixResult.contains('Darwin') || unixResult.contains('BSD')) {
        detectedSystemType = SystemType.bsd;
        dprint('Detected BSD system type for ${spi.oldId}');
        return detectedSystemType;
      }

      // Fall back to the Windows `ver` command when `uname` is inconclusive.
      final powershellResult = await client.runSafe(
        'ver 2>nul',
        systemType: SystemType.windows,
        context: 'ver detection for ${spi.oldId}',
      );
      if (powershellResult.isNotEmpty &&
          (powershellResult.contains('Windows') ||
              powershellResult.contains('NT'))) {
        detectedSystemType = SystemType.windows;
        dprint('Detected Windows system type for ${spi.oldId}');
        return detectedSystemType;
      }
    } catch (e, stackTrace) {
      Loggers.app.warning(
        'System detection failed for ${spi.oldId}: $e\n$stackTrace',
      );
    }

    // Preserve the historical Linux default when neither probe succeeds.
    detectedSystemType = SystemType.linux;
    dprint('Defaulting to Linux system type for ${spi.oldId}');
    return detectedSystemType;
  }
}

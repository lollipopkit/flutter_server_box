import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';

/// Helper class for detecting remote system types
class SystemDetector {
  /// Detects the system type of a remote server
  ///
  /// First checks if a custom system type is configured in [spi].
  /// If not, attempts to detect the system by running commands:
  /// 1. 'ver' command to detect Windows
  /// 2. 'uname -a' command to detect Linux/BSD/Darwin
  ///
  /// Returns [SystemType.linux] as default if detection fails.
  static Future<SystemType> detect(SSHClient client, Spi spi) async {
    // First, check if custom system type is defined
    SystemType? detectedSystemType = spi.customSystemType;
    if (detectedSystemType != null) {
      dprint('Using custom system type ${detectedSystemType.name} for ${spi.oldId}');
      return detectedSystemType;
    }

    try {
      // Try to detect Windows systems first (more reliable detection)
      final powershellResult = await client.run('ver 2>nul').string;
      if (powershellResult.isNotEmpty &&
          (powershellResult.contains('Windows') || powershellResult.contains('NT'))) {
        detectedSystemType = SystemType.windows;
        dprint('Detected Windows system type for ${spi.oldId}');
        return detectedSystemType;
      }

      // Try to detect Unix/Linux/BSD systems
      final unixResult = await client.run('uname -a').string;
      if (unixResult.contains('Linux')) {
        detectedSystemType = SystemType.linux;
        dprint('Detected Linux system type for ${spi.oldId}');
        return detectedSystemType;
      } else if (unixResult.contains('Darwin') || unixResult.contains('BSD')) {
        detectedSystemType = SystemType.bsd;
        dprint('Detected BSD system type for ${spi.oldId}');
        return detectedSystemType;
      }
    } catch (e) {
      Loggers.app.warning('System detection failed for ${spi.oldId}: $e');
    }

    // Default fallback
    detectedSystemType = SystemType.linux;
    dprint('Defaulting to Linux system type for ${spi.oldId}');
    return detectedSystemType;
  }
}

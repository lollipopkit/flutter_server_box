import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/parser.dart' as ffi;

/// Detects the operating system exposed by a remote SSH server.
///
/// The probes and what their output means are Rust's (`sbm_parser::system`);
/// this runs them, before the status script is installed. A server reached
/// through its agent is told by the agent itself.
class SystemDetector {
  /// The configured system type, or the one the probes tell: `uname` first,
  /// then Windows' `ver`. Linux when neither says.
  static Future<SystemType> detect(SSHClient client, Spi spi) async {
    final configured = spi.customSystemType;
    if (configured != null) {
      dprint('Using custom system type ${configured.name} for ${spi.oldId}');
      return configured;
    }

    try {
      final uname = await client.runSafe(ffi.systemProbeUname(), context: 'uname detection for ${spi.oldId}');
      final unix = SystemType.fromWire(ffi.systemFromUname(output: uname));
      if (unix != null) return unix;

      final ver = await client.runSafe(
        ffi.systemProbeVer(),
        systemType: SystemType.windows,
        context: 'ver detection for ${spi.oldId}',
      );
      final windows = SystemType.fromWire(ffi.systemFromVer(output: ver));
      if (windows != null) return windows;
    } catch (e, stackTrace) {
      Loggers.app.warning('System detection failed for ${spi.oldId}: $e\n$stackTrace');
    }

    // Preserve the historical Linux default when neither probe succeeds.
    dprint('Defaulting to Linux system type for ${spi.oldId}');
    return SystemType.linux;
  }
}

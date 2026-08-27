import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_status_update_req.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/provider/server/data_source.dart';
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

/// Reads status from the `SrvBoxSep`-delimited output of the generated status
/// script, run over SSH.
///
/// Only the *reading* half lives here. Establishing the SSH connection stays
/// with `ServerNotifier`, because the same client also backs the terminal,
/// SFTP and port forwarding — capabilities this interface deliberately does
/// not describe. [runScript] is that boundary: the notifier supplies a way to
/// execute the status script, this class owns turning its output into a
/// [ServerStatus].
class SshDataSource implements ServerDataSource {
  SshDataSource({required this.spi, required this.runScript});

  final Spi spi;

  /// Runs the status script on the already-connected host and returns its raw
  /// stdout. Throws whatever the transport throws.
  final Future<String> Function() runScript;

  @override
  Future<ServerStatus> fetchStatus(ServerStatus into) async {
    final raw = await runScript();
    // Parsing runs on the Rust thread pool (async FFI); no isolate needed.
    //
    // Segments rather than a map, kept in order: the custom commands the user
    // arranged are printed in that order and nothing else records it — the
    // app no longer holds the list, the server's directory does.
    final segments = await script_ffi.parseScriptSegments(raw: raw);
    final parsedOutput = {for (final s in segments) s.key: s.value};
    final status = await getStatus(
      ServerStatusUpdateReq(
        ss: into,
        parsedOutput: parsedOutput,
        system: into.system,
        tempDivisor: spi.custom?.tempIsCelsius == true ? 1.0 : 1000.0,
      ),
    );
    // Receipt time is the only timestamp available: the shell output carries
    // counters, not a sampling instant
    status.history.add(
      timeMs: DateTime.now().millisecondsSinceEpoch,
      cpu: status.cpu.usedPercent(),
      mem: status.mem.total > 0 ? status.mem.usedPercent * 100 : null,
      disk: status.diskUsage?.usedPercent,
      netRx: status.netSpeed.speedInBytesOf(),
      netTx: status.netSpeed.speedOutBytesOf(),
      diskRead: status.diskIO.allSpeedBytes.$1,
      diskWrite: status.diskIO.allSpeedBytes.$2,
      temp: status.temps.first,
      temps: {
        for (final d in status.temps.devices) d: ?status.temps.get(d),
      },
      battery: status.batteries.firstOrNull?.percent?.toDouble(),
    );
    return status;
  }

  /// SSH exposes no stored history — the app's own buffer is the only place
  /// these samples ever exist
  @override
  Future<List<StatusHistorySample>> fetchHistory({
    int minutes = 60,
    int maxPoints = StatusHistory.capacity,
  }) async => const [];

  /// The SSH client is owned by `ServerNotifier`, which closes it
  @override
  void close() {}
}

import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status/status_history.dart';

/// One way of obtaining a server's status.
///
/// Implementations convert whatever their transport returns into the app's
/// [ServerStatus] and [StatusHistorySample], so what is drawn never depends on
/// how a server is reached. The two start from completely different data —
/// SSH parses `SrvBoxSep`-delimited shell output, monitor decodes its JSON
/// API — and both land on the same shape. Getting that data differs as much:
/// `ServerNotifier` drives each transport's fetch itself.
///
/// Deliberately narrow: this covers *reading status*, not the SSH session
/// itself. Terminal, SFTP and port forwarding stay with `ServerNotifier`
/// because they are a different capability. What a server can do is asked of
/// `ServerState.capabilities`, and not of a source: the answer depends on what
/// the agent grants, which a source built at connect time cannot know, so a
/// getter here could only ever hold a second, staler answer.
abstract interface class ServerDataSource {
  /// Fetches one sample on top of [into], returning the result.
  ///
  /// The result carries [into]'s rolling state — what the app derives rates
  /// from (`cpu`, `netSpeed`, `diskIO`, `history`) and what one sample does
  /// not repeat (`ips`, the OS id) — whether it is [into] itself or a status
  /// built from it with the per-sample readings reset. Monitor applies its
  /// answer onto [into]; the script source builds afresh
  /// (`_createWorkingStatus`), since a section the script stopped printing
  /// must not keep last sample's value.
  ///
  /// Throws on failure; the caller owns retry accounting and error mapping.
  Future<ServerStatus> fetchStatus(ServerStatus into);

  /// Trend points the source already holds, oldest first. Empty when
  /// [ServerCapabilities.storedHistory] is false.
  ///
  /// [maxPoints] is what the caller can keep — [StatusHistory.capacity]. A
  /// source that thins on its side is told rather than left to answer with
  /// everything it has for the buffer to discard on arrival; the agent
  /// averages over wider buckets, which keeps spikes that dropping rows loses.
  /// The defaults are named here as well as on both implementations, so what
  /// a caller holding a [DataSource] gets by omitting them is a property of
  /// the interface rather than of whichever source it happens to be.
  Future<List<StatusHistorySample>> fetchHistory({
    int minutes = 60,
    int maxPoints = StatusHistory.capacity,
    DateTime? from,
    DateTime? to,
  });

  /// Releases transport-owned resources. Safe to call more than once.
  void close();
}

/// Appending a sample to the rolling buffer, which both sources do identically.
///
/// Where the numbers came from stops mattering here: by this point the source
/// has landed on a [ServerStatus] and what is kept of it is the same either
/// way. The only difference is the instant, which is why it is a parameter —
/// an agent reports its own sampling time and a shell script has none.
extension ServerStatusHistoryX on ServerStatus {
  void recordSample({required int timeMs}) {
    final (diskRead, diskWrite) = diskIO.allSpeedBytes;
    history.add(StatusHistorySample(
      timeMs: timeMs,
      cpu: cpu.usedPercent(),
      mem: switch (mem.usedPercent) {
        final ratio? => ratio * 100,
        null => null,
      },
      swap: swap.total > 0 ? swap.usedPercent * 100 : null,
      disk: diskUsage?.usedPercent,
      netRx: netSpeed.speedInBytesOf(),
      netTx: netSpeed.speedOutBytesOf(),
      diskRead: diskRead,
      diskWrite: diskWrite,
      // The one that is going to be a problem, not the mean of them: a host
      // with two cards is busy because one of them is.
      gpu: gpus.map((e) => e.utilization).nonNulls.fold<double?>(
        null,
        (top, e) => top == null || e > top ? e : top,
      ),
      temp: temps.first,
      temps: {for (final d in temps.devices) d: ?temps.get(d)},
      diskReads: {
        for (final d in diskIO.devices) d: ?diskIO.speedBytes(d).$1,
      },
      diskWrites: {
        for (final d in diskIO.devices) d: ?diskIO.speedBytes(d).$2,
      },
      netRxs: {
        for (final d in netSpeed.ifaces) d: ?netSpeed.speedInBytesOf(device: d),
      },
      netTxs: {
        for (final d in netSpeed.ifaces) d: ?netSpeed.speedOutBytesOf(device: d),
      },
      battery: batteries.firstOrNull?.percent?.toDouble(),
    ));
  }
}

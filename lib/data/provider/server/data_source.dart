import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status_history.dart';

/// One way of obtaining a server's status.
///
/// Implementations own their transport and convert whatever it returns into
/// the app's [ServerStatus] and [StatusHistorySample], so nothing above this
/// line branches on how a server is reached. The two implementations start
/// from completely different data — SSH parses `SrvBoxSep`-delimited shell
/// output, monitor decodes its JSON API — and both land on the same shape.
///
/// Deliberately narrow: this covers *reading status*, not the SSH session
/// itself. Terminal, SFTP and port forwarding stay with `ServerNotifier`
/// because they are a different capability. What a server can do is asked of
/// `ServerState.capabilities`, and not of a source: the answer depends on what
/// the agent grants, which a source built at connect time cannot know, so a
/// getter here could only ever hold a second, staler answer.
abstract interface class ServerDataSource {
  /// Fetches one sample and applies it onto [into], returning the result.
  ///
  /// Implementations mutate and return [into] rather than building a fresh
  /// status: the rolling state the app derives rates from (`cpu`, `netSpeed`,
  /// `diskIO`, `history`) lives on it and has to survive across refreshes.
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
    history.add(
      timeMs: timeMs,
      cpu: cpu.usedPercent(),
      mem: mem.total > 0 ? mem.usedPercent * 100 : null,
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
        for (final d in netSpeed.realIfaces) d: ?netSpeed.speedInBytesOf(device: d),
      },
      netTxs: {
        for (final d in netSpeed.realIfaces) d: ?netSpeed.speedOutBytesOf(device: d),
      },
      battery: batteries.firstOrNull?.percent?.toDouble(),
    );
  }
}

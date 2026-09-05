import 'package:server_box/core/extension/context/locale.dart';

/// Which part of a run the log says it is in.
///
/// Read out of the log's section headers, because yabs has no progress channel
/// — it prints a header, works for minutes, then prints results. Without this a
/// run is a spinner for a quarter of an hour with nothing to say whether it is
/// on the disk test or waiting on a download.
///
/// A guess, and only ever used as a label. The headers are stable enough
/// (unchanged across yabs releases for years) and getting one wrong shows the
/// previous phase's name for a while, which is why nothing else depends on it.
enum BenchmarkPhase {
  system,
  disk,
  network,
  cpu,
  finishing;

  String get label => switch (this) {
    system => l10n.benchmarkPhaseSystem,
    disk => l10n.benchmarkPhaseDisk,
    network => l10n.benchmarkPhaseNetwork,
    cpu => l10n.benchmarkPhaseCpu,
    finishing => l10n.benchmarkPhaseDone,
  };

  /// The last header [log] contains.
  ///
  /// Last rather than first: the log accumulates, so every earlier header is
  /// still in it. Searched newest-first for that reason.
  static BenchmarkPhase of(String log) {
    if (log.contains('YABS completed in')) return finishing;
    if (log.contains('Benchmark Test:')) return cpu;
    if (log.contains('Network Speed Tests')) return network;
    if (log.contains('Disk Speed Tests')) return disk;
    return system;
  }
}

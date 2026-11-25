import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/src/rust/api/container.dart' as ffi;

/// One container, as `sbm_parser::container` read it from either runtime.
///
/// The stats are the runtime's own renderings, split into their parts on the
/// Rust side; the sentences they are drawn in are this app's, so they are put
/// together here, in its language.
final class ContainerPs {
  const ContainerPs({
    this.id,
    this.name,
    this.image,
    this.project,
    this.workingDir,
    this.ports,
    this.rawStatus,
    this.status = ContainerStatus.unknown,
    this.cpu,
    this.mem,
    this.net,
    this.disk,
    this.cpuPercent,
    this.memPercent,
    this.memUsedBytes,
    this.memLimitBytes,
    this.netDown,
    this.netUp,
    this.netRxBytes,
    this.netTxBytes,
    this.diskRead,
    this.diskWrite,
    this.blockReadBytes,
    this.blockWriteBytes,
  });

  factory ContainerPs.fromFfi(ffi.ContainerItem item) {
    final stats = item.stats;
    final hasValidNet =
        stats != null && stats.netRxBytes != null && stats.netTxBytes != null;
    final hasValidDisk =
        stats != null &&
        stats.blockReadBytes != null &&
        stats.blockWriteBytes != null;
    return ContainerPs(
      id: item.id,
      name: item.name,
      image: item.image,
      project: item.project,
      workingDir: item.workingDir,
      ports: item.ports,
      rawStatus: item.rawStatus,
      status: ContainerStatus.values.byName(item.status),
      cpu: switch (stats) {
        null => null,
        ffi.ContainerStatsItem(:final cpu, cpuAvg: null) => cpu,
        ffi.ContainerStatsItem(:final cpu, :final cpuAvg) =>
          '$cpu / ${libL10n.pingAvg} $cpuAvg',
      },
      mem: stats?.mem,
      net: stats == null ? null : '↓ ${stats.netDown} / ↑ ${stats.netUp}',
      disk: stats == null
          ? null
          : '${l10n.read} ${stats.diskRead} / ${l10n.write} ${stats.diskWrite}',
      cpuPercent: stats?.cpuPercent,
      memPercent: stats?.memPercent,
      memUsedBytes: stats?.memUsedBytes,
      memLimitBytes: stats?.memLimitBytes,
      netDown: hasValidNet ? _cleanStatToken(stats.netDown) : null,
      netUp: hasValidNet ? _cleanStatToken(stats.netUp) : null,
      netRxBytes: stats?.netRxBytes,
      netTxBytes: stats?.netTxBytes,
      diskRead: hasValidDisk ? _cleanStatToken(stats.diskRead) : null,
      diskWrite: hasValidDisk ? _cleanStatToken(stats.diskWrite) : null,
      blockReadBytes: stats?.blockReadBytes,
      blockWriteBytes: stats?.blockWriteBytes,
    );
  }

  final String? id;
  final String? name;
  final String? image;

  /// The compose project this container belongs to, when it was started by
  /// one; what the list is grouped by.
  final String? project;
  final String? workingDir;

  /// Published ports condensed to `host→container`.
  final String? ports;

  /// The runtime's own lifecycle text, verbatim.
  final String? rawStatus;
  final ContainerStatus status;

  /// `1.5%`, with Podman's average over the sample window beside it.
  final String? cpu;
  final String? mem;
  final String? net;
  final String? disk;

  /// Parsed numeric stats produced on the Rust side (`sbm_parser::container`).
  final double? cpuPercent;
  final double? memPercent;
  final BigInt? memUsedBytes;
  final BigInt? memLimitBytes;
  final String? netDown;
  final String? netUp;
  final BigInt? netRxBytes;
  final BigInt? netTxBytes;
  final String? diskRead;
  final String? diskWrite;
  final BigInt? blockReadBytes;
  final BigInt? blockWriteBytes;

  static final _whitespace = RegExp(r'\s+');

  static String? _cleanStatToken(String? raw) {
    final cleaned = raw?.replaceAll(_whitespace, ' ').trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}

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
  });

  factory ContainerPs.fromFfi(ffi.ContainerItem item) {
    final stats = item.stats;
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
}

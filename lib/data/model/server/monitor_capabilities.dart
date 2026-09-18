import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/system.dart';

/// A `monitor` agent's answer to `GET /api/v1/capabilities`.
///
/// Two things the app cannot work out on its own: what the agent will let it
/// do, and what the machine is. The second used to arrive only by running
/// `uname` over SSH, which a monitor-backed server has no way to do — and it
/// decides which script gets installed there.
class MonitorCapabilities {
  final MonitorRemoteAccess remoteAccess;

  /// What the agent was built for. Null when it names something this app does
  /// not know, so a newer agent is not silently read as Linux.
  final SystemType? platform;

  /// The agent's own version. Null for one built before it said so, which is
  /// shown as no version rather than as an unknown one.
  final String? version;

  /// How far back this agent is configured to keep readings. Null for an agent
  /// too old to say, which is the same answer as "this app does not know" and
  /// is offered the fixed windows instead of a range it cannot check.
  final Duration? retention;

  /// The oldest reading still stored, which is the half of the answer that is
  /// true rather than intended: an agent started yesterday under a 90-day
  /// policy has a day.
  final DateTime? oldestSample;

  const MonitorCapabilities({
    this.remoteAccess = MonitorRemoteAccess.none,
    this.platform,
    this.version,
    this.retention,
    this.oldestSample,
  });

  /// How far back this agent can actually answer for: the later of what it
  /// keeps and what it has.
  DateTime? get historyFrom {
    final oldest = oldestSample;
    final kept = retention == null ? null : DateTime.now().subtract(retention!);
    if (oldest == null) return kept;
    if (kept == null) return oldest;
    return oldest.isAfter(kept) ? oldest : kept;
  }

  factory MonitorCapabilities.fromJson(Map<String, dynamic> json) {
    return MonitorCapabilities(
      remoteAccess: MonitorRemoteAccess.fromJson(
        json['remote_access'] as Map<String, dynamic>? ?? const {},
      ),
      platform: SystemType.fromWire(json['platform'] as String?),
      version: json['version'] as String?,
      retention: switch (json['retention_days']) {
        final num days when days > 0 => Duration(days: days.round()),
        _ => null,
      },
      oldestSample: switch (json['oldest_sample']) {
        final String at => DateTime.tryParse(at)?.toLocal(),
        _ => null,
      },
    );
  }

  @override
  String toString() =>
      'MonitorCapabilities(remoteAccess: $remoteAccess, platform: $platform, '
      'version: $version, retention: $retention, oldest: $oldestSample)';
}

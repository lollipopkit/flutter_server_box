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

  const MonitorCapabilities({
    this.remoteAccess = MonitorRemoteAccess.none,
    this.platform,
  });

  factory MonitorCapabilities.fromJson(Map<String, dynamic> json) {
    return MonitorCapabilities(
      remoteAccess: MonitorRemoteAccess.fromJson(
        json['remote_access'] as Map<String, dynamic>? ?? const {},
      ),
      platform: SystemType.fromWire(json['platform'] as String?),
    );
  }

  @override
  String toString() =>
      'MonitorCapabilities(remoteAccess: $remoteAccess, platform: $platform)';
}

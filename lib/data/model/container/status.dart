import 'package:fl_lib/fl_lib.dart';

/// A normalized Docker or Podman container state.
enum ContainerStatus {
  running,
  exited,
  created,
  paused,
  restarting,
  removing,
  dead,
  unknown;

  /// Whether the container is actively running.
  bool get isRunning => this == ContainerStatus.running;

  /// Parses a Docker-style status string.
  static ContainerStatus fromDockerState(String? state) {
    if (state == null || state.isEmpty) return ContainerStatus.unknown;

    final lowerState = state.toLowerCase();

    if (lowerState.contains('exited')) return ContainerStatus.exited;
    if (lowerState.contains('created')) return ContainerStatus.created;
    if (lowerState.contains('paused')) return ContainerStatus.paused;
    if (lowerState.contains('restarting')) return ContainerStatus.restarting;
    if (lowerState.contains('removing') ||
        lowerState.contains('removal in progress')) {
      return ContainerStatus.removing;
    }
    if (lowerState.contains('dead')) return ContainerStatus.dead;
    if (lowerState == 'running' || lowerState.startsWith('up')) {
      return ContainerStatus.running;
    }

    return ContainerStatus.unknown;
  }

  /// Maps Podman's legacy `exited` flag to a container state.
  static ContainerStatus fromPodmanExited(bool? exited) {
    if (exited == true) return ContainerStatus.exited;
    if (exited == false) return ContainerStatus.running;
    return ContainerStatus.unknown;
  }

  /// Parse Podman status text first, with the legacy exited flag as fallback.
  static ContainerStatus fromPodman(bool? exited, String? rawStatus) {
    final parsed = fromDockerState(rawStatus);
    if (parsed != ContainerStatus.unknown) return parsed;
    return fromPodmanExited(exited);
  }

  bool get isStopped => switch (this) {
    ContainerStatus.exited ||
    ContainerStatus.created ||
    ContainerStatus.dead => true,
    _ => false,
  };

  /// Localized status label where one is available.
  String get displayName {
    return switch (this) {
      ContainerStatus.running => libL10n.running,
      ContainerStatus.exited => libL10n.exit,
      ContainerStatus.created => 'Created',
      ContainerStatus.paused => 'Paused',
      ContainerStatus.restarting => 'Restarting',
      ContainerStatus.removing => 'Removing',
      ContainerStatus.dead => 'Dead',
      ContainerStatus.unknown => libL10n.unknown,
    };
  }
}

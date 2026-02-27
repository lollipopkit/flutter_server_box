import 'package:fl_lib/fl_lib.dart';

/// Represents the various states a container can be in.
/// Supports both Docker and Podman container status parsing.
enum ContainerStatus {
  running,
  exited,
  created,
  paused,
  restarting,
  removing,
  dead,
  unknown;

  /// Check if the container is actively running
  bool get isRunning => this == ContainerStatus.running;

  /// Check if the container can be started
  bool get canStart =>
      this == ContainerStatus.exited ||
      this == ContainerStatus.created ||
      this == ContainerStatus.dead;

  /// Check if the container can be stopped
  bool get canStop =>
      this == ContainerStatus.running || this == ContainerStatus.paused;

  /// Check if the container can be restarted
  bool get canRestart =>
      this != ContainerStatus.removing && this != ContainerStatus.unknown;

  /// Parse Docker container status string to ContainerStatus
  static ContainerStatus fromDockerState(String? state) {
    if (state == null || state.isEmpty) return ContainerStatus.unknown;

    final lowerState = state.toLowerCase();

    if (lowerState.startsWith('up')) return ContainerStatus.running;
    if (lowerState.contains('exited')) return ContainerStatus.exited;
    if (lowerState.contains('created')) return ContainerStatus.created;
    if (lowerState.contains('paused')) return ContainerStatus.paused;
    if (lowerState.contains('restarting')) return ContainerStatus.restarting;
    if (lowerState.contains('removing')) return ContainerStatus.removing;
    if (lowerState.contains('dead')) return ContainerStatus.dead;

    return ContainerStatus.unknown;
  }

  /// Parse Podman container status from exited boolean
  static ContainerStatus fromPodmanExited(bool? exited) {
    if (exited == true) return ContainerStatus.exited;
    if (exited == false) return ContainerStatus.running;
    return ContainerStatus.unknown;
  }

  /// Get display string for the status
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

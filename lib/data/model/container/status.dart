import 'package:fl_lib/fl_lib.dart';

/// A normalized Docker or Podman container state, as
/// `sbm_parser::container::ContainerStatus` names it.
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

  /// Nothing happens until someone starts it again. `unknown` is not
  /// stopped: an unrecognised state is not evidence the container is down.
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

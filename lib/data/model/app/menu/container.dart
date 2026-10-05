import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/container/status.dart';
import 'package:server_box/src/rust/api/container.dart' as ffi;

enum ContainerMenu {
  start,
  stop,
  restart,
  rm,
  logs,
  terminal;

  /// What a container in [status] is offered, by `sbm_parser::container`'s
  /// rule: an unrecognised state is grouped with a stopped one, and logs are
  /// offered in every state.
  static List<ContainerMenu> items(ContainerStatus status) => [
    for (final kind in ffi.containerMenuItems(statusName: status.name))
      kind == 'remove' ? rm : values.byName(kind),
  ];

  IconData get icon => switch (this) {
    ContainerMenu.start => Icons.play_arrow,
    ContainerMenu.stop => Icons.stop,
    ContainerMenu.restart => Icons.restart_alt,
    ContainerMenu.rm => Icons.delete,
    ContainerMenu.logs => Icons.logo_dev,
    ContainerMenu.terminal => Icons.terminal,
  };

  String get toStr => switch (this) {
    ContainerMenu.start => libL10n.start,
    ContainerMenu.stop => libL10n.stop,
    ContainerMenu.restart => libL10n.restart,
    ContainerMenu.rm => libL10n.delete,
    ContainerMenu.logs => libL10n.log,
    ContainerMenu.terminal => libL10n.terminal,
  };
}


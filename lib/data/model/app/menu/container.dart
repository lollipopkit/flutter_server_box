import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

enum ContainerMenu {
  start,
  stop,
  restart,
  rm,
  logs,
  terminal;

  static List<ContainerMenu> items(bool running) {
    if (running) {
      return [
        stop,
        restart,
        rm,
        logs,
        terminal,
      ];
    }
    return [start, rm, logs];
  }

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

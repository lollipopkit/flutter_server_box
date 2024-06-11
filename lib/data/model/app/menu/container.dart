import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum ContainerMenu {
  start,
  stop,
  restart,
  rm,
  logs,
  terminal,
  //stats,
  ;

  static List<ContainerMenu> items(bool running) {
    if (running) {
      return [
        stop,
        restart,
        rm,
        logs,
        terminal,
        //stats,
      ];
    } else {
      return [start, rm, logs];
    }
  }

  IconData get icon {
    switch (this) {
      case ContainerMenu.start:
        return Icons.play_arrow;
      case ContainerMenu.stop:
        return Icons.stop;
      case ContainerMenu.restart:
        return Icons.restart_alt;
      case ContainerMenu.rm:
        return Icons.delete;
      case ContainerMenu.logs:
        return Icons.logo_dev;
      case ContainerMenu.terminal:
        return Icons.terminal;
      // case DockerMenuType.stats:
      //   return Icons.bar_chart;
    }
  }

  String get toStr {
    switch (this) {
      case ContainerMenu.start:
        return l10n.start;
      case ContainerMenu.stop:
        return l10n.stop;
      case ContainerMenu.restart:
        return l10n.restart;
      case ContainerMenu.rm:
        return l10n.delete;
      case ContainerMenu.logs:
        return l10n.log;
      case ContainerMenu.terminal:
        return l10n.terminal;
      // case DockerMenuType.stats:
      //   return s.stats;
    }
  }
}

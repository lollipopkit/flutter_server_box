import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';

enum ServerTabMenu {
  terminal,
  sftp,
  container,
  process,
  pkg,
  //snippet,
  ;

  IconData get icon {
    switch (this) {
      case ServerTabMenu.sftp:
        return Icons.insert_drive_file;
      //case ServerTabMenuType.snippet:
      //return Icons.code;
      case ServerTabMenu.pkg:
        return Icons.system_security_update;
      case ServerTabMenu.container:
        return Icons.view_agenda;
      case ServerTabMenu.process:
        return Icons.list_alt_outlined;
      case ServerTabMenu.terminal:
        return Icons.terminal;
    }
  }

  String get toStr {
    switch (this) {
      case ServerTabMenu.sftp:
        return 'SFTP';
      //case ServerTabMenuType.snippet:
      //return l10n.snippet;
      case ServerTabMenu.pkg:
        return l10n.pkg;
      case ServerTabMenu.container:
        return l10n.container;
      case ServerTabMenu.process:
        return l10n.process;
      case ServerTabMenu.terminal:
        return l10n.terminal;
    }
  }
}

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

  PopupMenuItem<ContainerMenu> get widget => _build(this, icon, toStr);
}

PopupMenuItem<T> _build<T>(T t, IconData icon, String text) {
  return PopupMenuItem<T>(
    value: t,
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(
          width: 10,
        ),
        Text(text),
      ],
    ),
  );
}

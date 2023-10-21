import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';

enum ServerTabMenuType {
  terminal,
  sftp,
  docker,
  process,
  pkg,
  //snippet,
  ;

  IconData get icon {
    switch (this) {
      case ServerTabMenuType.sftp:
        return Icons.insert_drive_file;
      //case ServerTabMenuType.snippet:
      //return Icons.code;
      case ServerTabMenuType.pkg:
        return Icons.system_security_update;
      case ServerTabMenuType.docker:
        return Icons.view_agenda;
      case ServerTabMenuType.process:
        return Icons.list_alt_outlined;
      case ServerTabMenuType.terminal:
        return Icons.terminal;
    }
  }

  String get toStr {
    switch (this) {
      case ServerTabMenuType.sftp:
        return 'SFTP';
      //case ServerTabMenuType.snippet:
      //return l10n.snippet;
      case ServerTabMenuType.pkg:
        return l10n.pkg;
      case ServerTabMenuType.docker:
        return 'Docker';
      case ServerTabMenuType.process:
        return l10n.process;
      case ServerTabMenuType.terminal:
        return l10n.terminal;
    }
  }
}

enum DockerMenuType {
  start,
  stop,
  restart,
  rm,
  logs,
  terminal,
  //stats,
  ;

  static List<DockerMenuType> items(bool running) {
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
      case DockerMenuType.start:
        return Icons.play_arrow;
      case DockerMenuType.stop:
        return Icons.stop;
      case DockerMenuType.restart:
        return Icons.restart_alt;
      case DockerMenuType.rm:
        return Icons.delete;
      case DockerMenuType.logs:
        return Icons.logo_dev;
      case DockerMenuType.terminal:
        return Icons.terminal;
      // case DockerMenuType.stats:
      //   return Icons.bar_chart;
    }
  }

  String get toStr {
    switch (this) {
      case DockerMenuType.start:
        return l10n.start;
      case DockerMenuType.stop:
        return l10n.stop;
      case DockerMenuType.restart:
        return l10n.restart;
      case DockerMenuType.rm:
        return l10n.delete;
      case DockerMenuType.logs:
        return l10n.log;
      case DockerMenuType.terminal:
        return l10n.terminal;
      // case DockerMenuType.stats:
      //   return s.stats;
    }
  }

  PopupMenuItem<DockerMenuType> get widget => _build(this, icon, toStr);
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

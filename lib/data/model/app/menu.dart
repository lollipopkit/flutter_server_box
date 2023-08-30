import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

enum ServerTabMenuType {
  terminal,
  sftp,
  docker,
  process,
  pkg,
  snippet,
  ;

  IconData get icon {
    switch (this) {
      case ServerTabMenuType.sftp:
        return Icons.insert_drive_file;
      case ServerTabMenuType.snippet:
        return Icons.code;
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

  String text(S s) {
    switch (this) {
      case ServerTabMenuType.sftp:
        return 'SFTP';
      case ServerTabMenuType.snippet:
        return s.snippet;
      case ServerTabMenuType.pkg:
        return s.pkg;
      case ServerTabMenuType.docker:
        return 'Docker';
      case ServerTabMenuType.process:
        return s.process;
      case ServerTabMenuType.terminal:
        return s.terminal;
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

  String text(S s) {
    switch (this) {
      case DockerMenuType.start:
        return s.start;
      case DockerMenuType.stop:
        return s.stop;
      case DockerMenuType.restart:
        return s.restart;
      case DockerMenuType.rm:
        return s.delete;
      case DockerMenuType.logs:
        return s.log;
      case DockerMenuType.terminal:
        return s.terminal;
      // case DockerMenuType.stats:
      //   return s.stats;
    }
  }

  PopupMenuItem<DockerMenuType> build(S s) => _build(this, icon, text(s));
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

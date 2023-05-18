import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

enum ServerTabMenuType {
  sftp,
  snippet,
  pkg,
  docker,
  edit;

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
      case ServerTabMenuType.edit:
        return Icons.edit;
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
      case ServerTabMenuType.edit:
        return s.edit;
    }
  }

  PopupMenuItem<ServerTabMenuType> build(S s) => _build(this, icon, text(s));
}

enum DockerMenuType {
  start,
  stop,
  restart,
  rm,
  logs;

  static List<DockerMenuType> items(bool running) {
    if (running) {
      return [stop, restart, rm, logs];
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

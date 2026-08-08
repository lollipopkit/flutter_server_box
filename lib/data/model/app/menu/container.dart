import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/container/status.dart';

enum ContainerMenu {
  start,
  stop,
  restart,
  rm,
  logs,
  terminal;

  static List<ContainerMenu> items(ContainerStatus status) {
    if (status.isRunning) {
      return [
        stop,
        restart,
        rm,
        logs,
        terminal,
      ];
    }
    if (status.isStopped ||
        status == ContainerStatus.paused ||
        status == ContainerStatus.unknown) {
      return [start, rm, logs];
    }
    return [rm, logs];
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

enum ContainerGroupMenu {
  start,
  stop,
  restart,
  logs;

  static List<ContainerGroupMenu> items({
    required bool anyRunning,
    required bool anyStopped,
  }) => [
    if (anyStopped) start,
    if (anyRunning) stop,
    if (anyRunning) restart,
    logs,
  ];

  IconData get icon => switch (this) {
    ContainerGroupMenu.start => Icons.play_arrow,
    ContainerGroupMenu.stop => Icons.stop,
    ContainerGroupMenu.restart => Icons.restart_alt,
    ContainerGroupMenu.logs => Icons.receipt_long_outlined,
  };

  String get toStr => switch (this) {
    ContainerGroupMenu.start => libL10n.start,
    ContainerGroupMenu.stop => libL10n.stop,
    ContainerGroupMenu.restart => libL10n.restart,
    ContainerGroupMenu.logs => libL10n.log,
  };
}

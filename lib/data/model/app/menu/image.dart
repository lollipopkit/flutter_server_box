import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum ImageMenu {
  pull,
  rm;

  static List<ImageMenu> get items => [pull, rm];

  IconData get icon => switch (this) {
    ImageMenu.pull => Icons.download,
    ImageMenu.rm => Icons.delete,
  };

  String get toStr => switch (this) {
    ImageMenu.pull => l10n.pull,
    ImageMenu.rm => libL10n.delete,
  };
}

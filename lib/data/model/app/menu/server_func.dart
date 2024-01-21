import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';

enum ServerTabMenu {
  terminal,
  sftp,
  container,
  process,
  pkg,
  snippet,
  ;

  IconData get icon => switch (this) {
      ServerTabMenu.sftp => Icons.insert_drive_file,
      ServerTabMenu.snippet => Icons.code,
      ServerTabMenu.pkg => Icons.system_security_update,
      ServerTabMenu.container => Icons.view_agenda,
      ServerTabMenu.process => Icons.list_alt_outlined,
      ServerTabMenu.terminal => Icons.terminal,
    };

  String get toStr => switch (this) {
      ServerTabMenu.sftp => 'SFTP',
      ServerTabMenu.snippet => l10n.snippet,
      ServerTabMenu.pkg => l10n.pkg,
      ServerTabMenu.container => l10n.container,
      ServerTabMenu.process => l10n.process,
      ServerTabMenu.terminal => l10n.terminal,
    };
}
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../../view/widget/dropdown_menu.dart';

class ServerTabMenuItems {
  static const List<DropdownBtnItem> firstItems = [sftp, snippet, pkg, docker];
  static const List<DropdownBtnItem> secondItems = [edit];

  static const sftp =
      DropdownBtnItem(text: 'SFTP', icon: Icons.insert_drive_file);
  static const snippet = DropdownBtnItem(text: 'Snippet', icon: Icons.code);
  static const pkg =
      DropdownBtnItem(text: 'Pkg', icon: Icons.system_security_update);
  static const docker =
      DropdownBtnItem(text: 'Docker', icon: Icons.view_agenda);
  static const edit = DropdownBtnItem(text: 'Edit', icon: Icons.edit);
}

class DockerMenuItems {
  static const rm = DropdownBtnItem(text: 'Remove', icon: Icons.delete);
  static const start = DropdownBtnItem(text: 'Start', icon: Icons.play_arrow);
  static const stop = DropdownBtnItem(text: 'Stop', icon: Icons.stop);
  static const restart =
      DropdownBtnItem(text: 'Restart', icon: Icons.restart_alt);
}

String getDropdownBtnText(S s, String text) {
  switch (text) {
    case 'Snippet':
      return s.snippet;
    case 'Pkg':
      return s.pkg;
    case 'Remove':
      return s.delete;
    case 'Start':
      return s.start;
    case 'Stop':
      return s.stop;
    case 'Edit':
      return s.edit;
    default:
      return text;
  }
}

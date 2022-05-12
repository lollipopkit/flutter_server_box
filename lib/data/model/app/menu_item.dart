import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';

class DropdownBtnItem {
  final String text;
  final IconData icon;

  const DropdownBtnItem({
    required this.text,
    required this.icon,
  });

  Widget get build => Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(
            width: 10,
          ),
          Text(
            text,
          ),
        ],
      );
}

class ServerTabMenuItems {
  static const List<DropdownBtnItem> firstItems = [sftp, snippet, apt, docker];
  static const List<DropdownBtnItem> secondItems = [edit];

  static const sftp =
      DropdownBtnItem(text: 'SFTP', icon: Icons.insert_drive_file);
  static const snippet = DropdownBtnItem(text: 'Snippet', icon: Icons.label);
  static const apt =
      DropdownBtnItem(text: 'Apt/Yum', icon: Icons.system_security_update);
  static const docker =
      DropdownBtnItem(text: 'Docker', icon: Icons.view_agenda);
  static const edit = DropdownBtnItem(text: 'Edit', icon: Icons.edit);
}

class DockerMenuItems {
  static const rm = DropdownBtnItem(text: 'Remove', icon: Icons.delete);
  static const start = DropdownBtnItem(text: 'Start', icon: Icons.play_arrow);
  static const stop = DropdownBtnItem(text: 'Stop', icon: Icons.stop);
}

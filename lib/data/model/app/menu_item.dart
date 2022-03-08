import 'package:flutter/material.dart';
import 'package:toolbox/data/res/color.dart';

class MenuItem {
  final String text;
  final IconData icon;

  const MenuItem({
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
  static const List<MenuItem> firstItems = [sftp, snippet, apt, docker];
  static const List<MenuItem> secondItems = [edit];

  static const sftp = MenuItem(text: 'SFTP', icon: Icons.insert_drive_file);
  static const snippet = MenuItem(text: 'Snippet', icon: Icons.label);
  static const apt = MenuItem(text: 'Apt', icon: Icons.system_security_update);
  static const docker = MenuItem(text: 'Docker', icon: Icons.view_agenda);
  static const edit = MenuItem(text: 'Edit', icon: Icons.edit);
}

class DockerMenuItems {
  static const rm = MenuItem(text: 'Remove', icon: Icons.delete);
  static const start = MenuItem(text: 'Start', icon: Icons.play_arrow);
  static const stop = MenuItem(text: 'Stop', icon: Icons.stop);
}

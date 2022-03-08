import 'package:flutter/material.dart';

class MenuItem {
  final String text;
  final IconData icon;

  const MenuItem({
    required this.text,
    required this.icon,
  });
}

class MenuItems {
  static const List<MenuItem> firstItems = [sftp, snippet, apt, docker];
  static const List<MenuItem> secondItems = [edit];

  static const sftp = MenuItem(text: 'SFTP', icon: Icons.insert_drive_file);
  static const snippet = MenuItem(text: 'Snippet', icon: Icons.label);
  static const apt = MenuItem(text: 'Apt', icon: Icons.system_security_update);
  static const docker = MenuItem(text: 'Docker', icon: Icons.view_agenda);
  static const edit = MenuItem(text: 'Edit', icon: Icons.edit);

  static Widget buildItem(MenuItem item) {
    return Row(
      children: [
        Icon(item.icon),
        const SizedBox(
          width: 10,
        ),
        Text(
          item.text,
        ),
      ],
    );
  }
}

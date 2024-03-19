import 'package:flutter/material.dart';

final class IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final void Function() onTap;

  const IconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 17,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

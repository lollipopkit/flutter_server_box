import 'package:flutter/material.dart';

abstract class PopMenu {
  static PopupMenuItem<T> build<T>(
    T t,
    IconData icon,
    String text, {
    double? iconSize,
  }) {
    return PopupMenuItem<T>(
      value: t,
      child: Row(
        children: [
          Icon(icon, size: iconSize),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}

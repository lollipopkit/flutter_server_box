import 'package:flutter/material.dart';

abstract class PopMenu {
  static PopupMenuItem<T> build<T>(T t, IconData icon, String text) {
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
}

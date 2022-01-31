import 'package:flutter/material.dart';

Widget buildInput(BuildContext context, TextEditingController controller,
    {int maxLines = 20, String? hint}) {
  return Card(
    child: TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
          fillColor: Theme.of(context).cardColor,
          hintText: hint,
          filled: true,
          border: InputBorder.none),
      controller: controller,
    ),
  );
}

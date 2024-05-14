import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

class PopupMenu<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T) builder;
  final void Function(T) onSelected;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final T? initialValue;

  const PopupMenu({
    super.key,
    required this.items,
    required this.builder,
    required this.onSelected,
    this.child = UIs.popMenuChild,
    this.padding = const EdgeInsets.all(7),
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      itemBuilder: (_) => items
          .map((e) => PopupMenuItem(value: e, child: builder(e)))
          .toList(),
      onSelected: onSelected,
      initialValue: initialValue,
      padding: padding,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: child,
    );
  }
}

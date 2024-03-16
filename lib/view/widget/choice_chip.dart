import 'package:choice/selection.dart';
import 'package:flutter/material.dart';

class ChoiceChipX<T> extends StatelessWidget {
  const ChoiceChipX({
    super.key,
    required this.label,
    required this.state,
    required this.value,
  });

  final String label;
  final ChoiceController<T> state;
  final T value;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
        label: Text(label),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        labelPadding: const EdgeInsets.symmetric(horizontal: 5),
        selected: state.selected(value),
        onSelected: state.onSelected(value),
      );
  }
}

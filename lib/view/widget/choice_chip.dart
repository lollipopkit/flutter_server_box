import 'package:choice/selection.dart';
import 'package:flutter/material.dart';

class ChoiceChipX<T> extends StatelessWidget {
  const ChoiceChipX({
    Key? key,
    required this.label,
    required this.state,
    required this.value,
  }) : super(key: key);

  final String label;
  final ChoiceController<T> state;
  final T value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: ChoiceChip(
        label: Text(label),
        side: BorderSide.none,
        selected: state.selected(value),
        onSelected: state.onSelected(value),
      ),
    );
  }
}

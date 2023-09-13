import 'package:flutter/material.dart';

import '../../core/persistant_store.dart';

class StoreSwitch extends StatelessWidget {
  final StorePropertyBase<bool> prop;
  final void Function(bool)? func;

  const StoreSwitch({super.key, required this.prop, this.func});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: prop.listenable(),
      builder: (context, bool value, widget) {
        return Switch(
          value: value,
          onChanged: (value) {
            func?.call(value);
            prop.put(value);
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/persistant_store.dart';

class StoreSwitch extends StatelessWidget {
  final StorePropertyBase<bool> prop;

  /// Exec before make change, after validator.
  final void Function(bool)? callback;

  /// If return false, the switch will not change.
  final bool Function(bool)? validator;

  const StoreSwitch({
    super.key,
    required this.prop,
    this.callback,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: prop.listenable(),
      builder: (context, bool value, widget) {
        return Switch(
          value: value,
          onChanged: (value) {
            if (validator != null && validator?.call(value) != true) return;
            callback?.call(value);
            prop.put(value);
          },
        );
      },
    );
  }
}

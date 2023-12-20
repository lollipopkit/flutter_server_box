import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/persistant_store.dart';

class StoreSwitch extends StatelessWidget {
  final StorePropertyBase<bool> prop;

  /// Exec before make change, after validator.
  final FutureOr<void> Function(bool)? callback;

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
          onChanged: (value) async {
            if (validator?.call(value) == false) return;
            await callback?.call(value);
            prop.put(value);
          },
        );
      },
    );
  }
}

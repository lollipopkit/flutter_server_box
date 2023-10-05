import 'package:choice/choice.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/view/widget/choice_chip.dart';

import '../../../data/res/ui.dart';
import '../../../view/widget/input_field.dart';

extension DialogX on BuildContext {
  Future<T?> showRoundDialog<T>({
    Widget? child,
    List<Widget>? actions,
    Widget? title,
    bool barrierDismiss = true,
  }) async {
    return await showDialog<T>(
      context: this,
      barrierDismissible: barrierDismiss,
      builder: (_) {
        return AlertDialog(
          title: title,
          content: child,
          actions: actions,
          actionsPadding: const EdgeInsets.all(17),
        );
      },
    );
  }

  void showLoadingDialog({bool barrierDismiss = false}) {
    showRoundDialog(
      child: UIs.centerSizedLoading,
      barrierDismiss: barrierDismiss,
    );
  }

  Future<String?> showPwdDialog(
    String? user,
  ) async {
    if (!mounted) return null;
    return await showRoundDialog<String>(
      title: Text(user ?? l10n.pwd),
      child: Input(
        autoFocus: true,
        type: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (val) => pop(val.trim()),
        label: l10n.pwd,
      ),
    );
  }

  Future<List<T>?> showPickDialog<T>({
    required List<T?> items,
    required String Function(T) name,
    bool multi = true,
  }) async {
    var vals = <T>[];
    final sure = await showRoundDialog<bool>(
      title: Text(l10n.choose),
      child: Choice<T>(
        onChanged: (value) => vals = value,
        multiple: multi,
        clearable: true,
        builder: (state, _) {
          return Wrap(
            children: List<Widget>.generate(
              items.length,
              (index) {
                final item = items[index];
                if (item == null) return UIs.placeholder;
                return ChoiceChipX<T>(
                  label: name(item),
                  state: state,
                  value: item,
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => pop(true),
          child: Text(l10n.ok),
        ),
      ],
    );
    if (sure == true && vals.isNotEmpty) {
      return vals;
    }
    return null;
  }

  Future<T?> showPickSingleDialog<T>({
    required List<T?> items,
    required String Function(T) name,
  }) async {
    final vals = await showPickDialog<T>(
      items: items,
      name: name,
      multi: false,
    );
    if (vals != null && vals.isNotEmpty) {
      return vals.first;
    }
    return null;
  }
}

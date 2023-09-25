import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/res/provider.dart';

import '../../../data/model/server/snippet.dart';
import '../../../data/res/ui.dart';
import '../../../view/widget/input_field.dart';
import '../../../view/widget/picker.dart';
import '../../route.dart';

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

  void showSnippetDialog(
    void Function(Snippet s) onSelected,
  ) {
    if (Pros.snippet.snippets.isEmpty) {
      showRoundDialog(
        child: Text(l10n.noSavedSnippet),
        actions: [
          TextButton(
            onPressed: () => pop(),
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () {
              pop();
              AppRoute.snippetEdit().go(this);
            },
            child: Text(l10n.add),
          )
        ],
      );
      return;
    }

    var snippet = Pros.snippet.snippets.first;
    showRoundDialog(
      title: Text(l10n.choose),
      child: Picker(
        items: Pros.snippet.snippets.map((e) => Text(e.name)).toList(),
        onSelected: (idx) => snippet = Pros.snippet.snippets[idx],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            pop();
            onSelected(snippet);
          },
          child: Text(l10n.ok),
        )
      ],
    );
  }
}

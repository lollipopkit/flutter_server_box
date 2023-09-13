import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/view/widget/rebuild.dart';

import '../../data/model/server/snippet.dart';
import '../../data/provider/snippet.dart';
import '../../data/res/ui.dart';
import '../../locator.dart';
import '../../view/widget/input_field.dart';
import '../../view/widget/picker.dart';
import '../route.dart';

extension ContextX on BuildContext {
  void pop<T extends Object?>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  bool get canPop => Navigator.of(this).canPop();

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

extension SnackBarX on BuildContext {
  void showSnackBar(String text) =>
      ScaffoldMessenger.of(this).showSnackBar(SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ));

  void showSnackBarWithAction(
    String content,
    String action,
    GestureTapCallback onTap,
  ) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content: Text(content),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: action,
        onPressed: onTap,
      ),
    ));
  }

  void showRestartSnackbar({String? btn, String? msg}) {
    showSnackBarWithAction(
      msg ?? 'Need restart to take effect',
      btn ?? 'Restart',
      () => RebuildWidget.restartApp(this),
    );
  }
}

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
      child: centerSizedLoading,
      barrierDismiss: barrierDismiss,
    );
  }

  Future<String?> showPwdDialog(
    String? user,
  ) async {
    if (!mounted) return null;
    final s = S.of(this)!;
    return await showRoundDialog<String>(
      title: Text(user ?? s.pwd),
      child: Input(
        autoFocus: true,
        type: TextInputType.visiblePassword,
        obscureText: true,
        onSubmitted: (val) => pop(val.trim()),
        label: s.pwd,
      ),
    );
  }

  void showSnippetDialog(
    S s,
    void Function(Snippet s) onSelected,
  ) {
    final provider = locator<SnippetProvider>();
    if (provider.snippets.isEmpty) {
      showRoundDialog(
        child: Text(s.noSavedSnippet),
        actions: [
          TextButton(
            onPressed: () => pop(),
            child: Text(s.ok),
          ),
          TextButton(
            onPressed: () {
              pop();
              AppRoute.snippetEdit().go(this);
            },
            child: Text(s.add),
          )
        ],
      );
      return;
    }

    var snippet = provider.snippets.first;
    showRoundDialog(
      title: Text(s.choose),
      child: Picker(
        items: provider.snippets.map((e) => Text(e.name)).toList(),
        onSelected: (idx) => snippet = provider.snippets[idx],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            pop();
            onSelected(snippet);
          },
          child: Text(s.ok),
        )
      ],
    );
  }
}

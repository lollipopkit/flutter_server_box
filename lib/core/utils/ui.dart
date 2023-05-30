import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/model/app/tab.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/server/snippet.dart';
import '../../data/provider/snippet.dart';
import '../../locator.dart';
import '../../view/page/snippet/edit.dart';
import '../../view/widget/card_dialog.dart';
import '../../view/widget/picker.dart';
import '../persistant_store.dart';
import '../route.dart';
import 'misc.dart';
import 'platform.dart';
import '../extension/stringx.dart';
import '../extension/uint8list.dart';

bool isDarkMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

void showSnackBar(BuildContext context, Widget child) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: child,
      behavior: SnackBarBehavior.floating,
    ));

void showSnackBarWithAction(
  BuildContext context,
  String content,
  String action,
  GestureTapCallback onTap,
) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(content),
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: action,
      onPressed: onTap,
    ),
  ));
}

Future<bool> openUrl(String url) async {
  return await launchUrl(url.uri, mode: LaunchMode.externalApplication);
}

Future<T?> showRoundDialog<T>({
  required BuildContext context,
  Widget? child,
  List<Widget>? actions,
  Widget? title,
  EdgeInsets? padding,
  bool barrierDismiss = true,
}) async {
  return await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismiss,
    builder: (_) {
      return CardDialog(
        title: title,
        content: child,
        actions: actions,
        padding: padding,
      );
    },
  );
}

Widget buildSwitch(
  BuildContext context,
  StoreProperty<bool> prop, {
  Function(bool)? func,
}) {
  return ValueListenableBuilder(
    valueListenable: prop.listenable(),
    builder: (context, bool value, widget) {
      return Switch(
          value: value,
          onChanged: (value) {
            if (func != null) func(value);
            prop.put(value);
          });
    },
  );
}

void setTransparentNavigationBar(BuildContext context) {
  if (isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: true),
    );
  }
}

String tabTitleName(BuildContext context, AppTab tab) {
  final s = S.of(context)!;
  switch (tab) {
    case AppTab.servers:
      return s.server;
    case AppTab.snippet:
      return s.convert;
    case AppTab.ping:
      return 'Ping';
  }
}

Future<void> loadFontFile(String? localPath) async {
  if (localPath == null) return;
  final name = getFileName(localPath);
  if (name == null) return;
  var fontLoader = FontLoader(name);
  fontLoader.addFont(File(localPath).readAsBytes().byteData);
  await fontLoader.load();
}

void showSnippetDialog(
  BuildContext context,
  S s,
  Function(Snippet s) onSelected,
) {
  final provider = locator<SnippetProvider>();
  if (provider.snippets.isEmpty) {
    showRoundDialog(
      context: context,
      child: Text(s.noSavedSnippet),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.ok),
        ),
        TextButton(
          onPressed: () {
            context.pop();
            AppRoute(const SnippetEditPage(), 'edit snippet').go(context);
          },
          child: Text(s.add),
        )
      ],
    );
    return;
  }

  var snippet = provider.snippets.first;
  showRoundDialog(
    context: context,
    title: Text(s.choose),
    child: Picker(
      items: provider.snippets.map((e) => Text(e.name)).toList(),
      onSelected: (idx) => snippet = provider.snippets[idx],
    ),
    actions: [
      TextButton(
        onPressed: () async {
          context.pop();
          onSelected(snippet);
        },
        child: Text(s.ok),
      )
    ],
  );
}

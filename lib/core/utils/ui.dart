import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/data/model/app/tab.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/server/snippet.dart';
import '../../data/provider/snippet.dart';
import '../../data/res/misc.dart';
import '../../data/res/ui.dart';
import '../../locator.dart';
import '../../view/widget/input_field.dart';
import '../../view/widget/picker.dart';
import '../persistant_store.dart';
import '../route.dart';
import 'misc.dart';
import 'platform.dart';
import '../extension/stringx.dart';
import '../extension/uint8list.dart';

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
  bool barrierDismiss = true,
}) async {
  return await showDialog<T>(
    context: context,
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

void showLoadingDialog(BuildContext context, {bool barrierDismiss = false}) {
  showRoundDialog(
    context: context,
    child: centerSizedLoading,
    barrierDismiss: barrierDismiss,
  );
}

Future<String?> showPwdDialog(
  BuildContext context,
  String? user,
) async {
  if (!context.mounted) return null;
  final s = S.of(context)!;
  return await showRoundDialog<String>(
    context: context,
    title: Text(user ?? s.pwd),
    child: Input(
      autoFocus: true,
      type: TextInputType.visiblePassword,
      obscureText: true,
      onSubmitted: (val) => context.pop(val.trim()),
      label: s.pwd,
    ),
  );
}

Future<void> onPwd(
  String event,
  StreamSink<Uint8List> stdin,
  PwdRequestFunc? onPwdReq,
) async {
  if (event.contains('[sudo] password for ')) {
    final user = pwdRequestWithUserReg.firstMatch(event)?.group(1);
    final pwd = await onPwdReq?.call(user);
    if (pwd == null || pwd.isEmpty) {
      return;
    }
    stdin.add('$pwd\n'.uint8List);
  }
}

Widget buildSwitch(
  BuildContext context,
  StorePropertyBase<bool> prop, {
  void Function(bool)? func,
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
    case AppTab.server:
      return s.server;
    case AppTab.snippet:
      return s.convert;
    case AppTab.ping:
      return 'Ping';
  }
}

Future<void> loadFontFile(String localPath) async {
  if (localPath.isEmpty) return;
  final name = getFileName(localPath);
  if (name == null) return;
  final file = File(localPath);
  if (!await file.exists()) return;
  var fontLoader = FontLoader(name);
  fontLoader.addFont(file.readAsBytes().byteData);
  await fontLoader.load();
}

void showSnippetDialog(
  BuildContext context,
  S s,
  void Function(Snippet s) onSelected,
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
            AppRoute.snippetEdit().go(context);
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

void switchStatusBar({required bool hide}) {
  if (hide) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: []);
  } else {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/view/widget/card_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:toolbox/core/extension/stringx.dart';

bool isDarkMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

void showSnackBar(BuildContext context, Widget child) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: child));

void showSnackBarWithAction(BuildContext context, String content, String action,
    GestureTapCallback onTap) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(content),
    action: SnackBarAction(
      label: action,
      onPressed: onTap,
    ),
  ));
}

Future<bool> openUrl(String url) async {
  return await launchUrl(url.uri, mode: LaunchMode.externalApplication);
}

Future<T?>? showRoundDialog<T>(
    BuildContext context, String title, Widget child, List<Widget> actions,
    {EdgeInsets? padding, bool barrierDismiss = true}) {
  return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismiss,
      builder: (ctx) {
        return CardDialog(
          title: Text(title),
          content: child,
          actions: actions,
          padding: padding,
        );
      });
}

Widget buildSwitch(BuildContext context, StoreProperty<bool> prop,
    {Function(bool)? func}) {
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
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: true));
  }
}

String tabTitleName(BuildContext context, int i) {
  final s = S.of(context);
  switch (i) {
    case 0:
      return s.server;
    case 1:
      return s.convert;
    case 2:
      return s.ping;
    default:
      return '';
  }
}

Future<bool> shareFiles(BuildContext context, List<String> filePaths) async {
  for (final filePath in filePaths) {
    if (!await File(filePath).exists()) {
      return false;
    }
  }
  var text = '';
  if (filePaths.length == 1) {
    text = filePaths.first.split('/').last;
  } else {
    text = '${filePaths.length} ${S.of(context).files}';
  }
  final xfiles = filePaths.map((e) => XFile(e)).toList();
  await Share.shareXFiles(xfiles, text: 'ServerBox -> $text');
  return filePaths.isNotEmpty;
}

Widget buildPopuopMenu(
    {required List<PopupMenuEntry> items,
    required Function(dynamic) onSelected}) {
  return PopupMenuButton(
    itemBuilder: (_) => items,
    onSelected: onSelected,
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: const Padding(
      padding: EdgeInsets.only(left: 7),
      child: Icon(
        Icons.more_vert,
        size: 21,
      ),
    ),
  );
}

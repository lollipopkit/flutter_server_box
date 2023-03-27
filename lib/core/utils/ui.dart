import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../view/widget/card_dialog.dart';
import '../persistant_store.dart';
import 'platform.dart';
import '../extension/stringx.dart';
import '../extension/uint8list.dart';

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
  if (isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: true));
  }
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

String tabTitleName(BuildContext context, int i) {
  final s = S.of(context)!;
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

Future<void> loadFontFile(String? localPath) async {
  if (localPath == null) return;
  final name = getFileName(localPath);
  if (name == null) return;
  var fontLoader = FontLoader(name);
  fontLoader.addFont(File(localPath).readAsBytes().byteData);
  await fontLoader.load();
}

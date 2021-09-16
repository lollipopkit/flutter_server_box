import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/view/widget/card_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

void unawaited(Future<void> future) {}

bool isDarkMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

void showSnackBar(BuildContext context, Widget child) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: child));

void showSnackBarWithAction(
    BuildContext context, String content, String action, Function onTap) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(content),
    action: SnackBarAction(
      label: action,
      onPressed: () => onTap,
    ),
  ));
}

Future<bool> openUrl(String url) async {
  print('openUrl $url');
  if (!await canLaunch(url)) {
    print('canLaunch false');
    return false;
  }
  final ok = await launch(url, forceSafariVC: false);
  if (ok == true) {
    return true;
  }
  print('launch $url failed');
  return false;
}

Future<T?>? showRoundDialog<T>(
    BuildContext context, String title, Widget child, List<Widget> actions,
    {EdgeInsets? padding}) {
  return showDialog<T>(
      context: context,
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

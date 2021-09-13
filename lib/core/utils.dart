import 'dart:async';

import 'package:flutter/material.dart';
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

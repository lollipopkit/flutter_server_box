import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:plain_notification_token/plain_notification_token.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/provider.dart';

Future<bool> shareFiles(List<String> filePaths) async {
  for (final filePath in filePaths) {
    if (!await File(filePath).exists()) {
      return false;
    }
  }
  var text = '';
  if (filePaths.length == 1) {
    text = filePaths.first.split('/').last;
  } else {
    text = '${filePaths.length} ${l10n.files}';
  }
  Providers.app.moveBg = false;
  // ignore: deprecated_member_use
  await Share.shareFiles(filePaths, subject: text);
  Providers.app.moveBg = true;
  return filePaths.isNotEmpty;
}

void copy2Clipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
}

Future<String?> pickOneFile() async {
  Providers.app.moveBg = false;
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  Providers.app.moveBg = true;
  return result?.files.single.path;
}

Future<String?> getToken() async {
  if (isIOS) {
    final plainNotificationToken = PlainNotificationToken();
    plainNotificationToken.requestPermission();

    // If you want to wait until Permission dialog close,
    // you need wait changing setting registered.
    await plainNotificationToken.onIosSettingsRegistered.first;
    return await plainNotificationToken.getToken();
  }
  return null;
}

String? getFileName(String? path) {
  if (path == null) {
    return null;
  }
  return path.split('/').last;
}

/// Join two path with `/`
String pathJoin(String path1, String path2) {
  return path1 + (path1.endsWith('/') ? '' : '/') + path2;
}

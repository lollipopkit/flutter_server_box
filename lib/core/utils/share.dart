import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/data/res/provider.dart';

class Shares {
  const Shares._();

  static Future<bool> files(List<String> filePaths) async {
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
    Pros.app.moveBg = false;
    // ignore: deprecated_member_use
    await Share.shareFiles(filePaths, subject: text);
    Pros.app.moveBg = true;
    return filePaths.isNotEmpty;
  }

  static Future<bool> text(String text) async {
    Pros.app.moveBg = false;
    await Share.share(text);
    Pros.app.moveBg = true;
    return true;
  }

  static void copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  static Future<String?> paste([String type = 'text/plain']) async {
    final data = await Clipboard.getData(type);
    return data?.text;
  }
}

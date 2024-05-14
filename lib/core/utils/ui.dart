import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openUrl(String url) async {
  return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

Future<void> loadFontFile(String localPath) async {
  if (localPath.isEmpty) return;
  final name = getFileName(localPath);
  if (name == null) return;
  final file = File(localPath);
  if (!await file.exists()) return;
  final fontLoader = FontLoader(name);
  fontLoader.addFont(file.readAsBytes().byteData);
  await fontLoader.load();
}

void switchStatusBar({required bool hide}) {
  if (hide) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  } else {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }
}

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/locator.dart';

Future<bool> isFileAvailable(String url) async {
  try {
    final resp = await Dio().head(url);
    return resp.statusCode == 200;
  } catch (e) {
    print('update file not available: $e');
    return false;
  }
}

Future<void> doUpdate(BuildContext context, {bool force = false}) async {
  final update = await locator<AppService>().getUpdate();

  locator<AppProvider>().setNewestBuild(update.newest);

  if (!force && update.newest <= BuildData.build) {
    print('Update ignored due to current: ${BuildData.build}, '
        'update: ${update.newest}');
    return;
  }
  print('Update available: ${update.newest}');

  if (Platform.isAndroid && !await isFileAvailable(update.android)) {
    return;
  }

  showSnackBarWithAction(
      context,
      update.min > BuildData.build
          ? 'Your version is too old. \nPlease update to v${update.newest}.'
          : 'Update: v${update.newest}available. \n${update.changelog}',
      'Update',
      () => openUrl(Platform.isAndroid ? update.android : update.ios));
}

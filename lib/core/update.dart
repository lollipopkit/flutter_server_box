import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';

final logger = Logger('UPDATE');

Future<bool> isFileAvailable(String url) async {
  try {
    final resp = await Dio().head(url);
    return resp.statusCode == 200;
  } catch (e) {
    logger.warning('update file not available: $e');
    return false;
  }
}

Future<void> doUpdate(BuildContext context, {bool force = false}) async {
  final update = await locator<AppService>().getUpdate();

  locator<AppProvider>().setNewestBuild(update.newest);

  final newest = () {
    if (Platform.isAndroid) {
      return update.androidbuild;
    } else if (Platform.isIOS) {
      return update.iosbuild;
    } else if (Platform.isMacOS) {
      return update.macbuild;
    }
    return update.newest;
  }();

  if (!force && newest <= BuildData.build) {
    logger.info('Update ignored due to current: ${BuildData.build}, '
        'update: $newest');
    return;
  }
  logger.info('Update available: $newest');

  if (Platform.isAndroid && !await isFileAvailable(update.android)) {
    return;
  }

  final s = S.of(context);

  showSnackBarWithAction(
      context,
      update.min > BuildData.build
          ? 'Your version is too old. \nPlease update to v1.0.$newest.'
          : 'Update: v1.0.$newest available. \n${update.changelog}',
      'Update', () async {
    if (Platform.isAndroid) {
      await RUpgrade.upgrade(update.android,
          fileName: update.android.split('/').last, isAutoRequestInstall: true);
    } else if (Platform.isIOS) {
      await RUpgrade.upgradeFromAppStore('1586449703');
    } else if (Platform.isMacOS) {
      await RUpgrade.upgradeFromUrl(update.mac);
    }
    showRoundDialog(context, s.attention, Text(s.platformNotSupportUpdate), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(), child: Text(s.ok))
    ]);
  });
}

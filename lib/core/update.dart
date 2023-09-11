import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:logging/logging.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/data/model/app/update.dart';
import 'package:toolbox/data/res/path.dart';

import '../data/provider/app.dart';
import '../data/res/build_data.dart';
import '../data/service/app.dart';
import '../locator.dart';
import 'utils/platform.dart';
import 'utils/ui.dart';

final _logger = Logger('UPDATE');

Future<bool> isFileAvailable(String url) async {
  try {
    final resp = await Dio().head(url);
    return resp.statusCode == 200;
  } catch (e) {
    _logger.warning('update file not available: $e');
    return false;
  }
}

Future<void> doUpdate(BuildContext context, {bool force = false}) async {
  await _rmDownloadApks();

  final update = await locator<AppService>().getUpdate();

  final newest = update.build.last.current;
  if (newest == null) {
    _logger.warning('Update not available on $platform');
    return;
  }

  locator<AppProvider>().newestBuild = newest;

  if (!force && newest <= BuildData.build) {
    _logger.info('Update ignored due to current: ${BuildData.build}, '
        'update: $newest');
    return;
  }
  _logger.info('Update available: $newest');

  final url = update.url.current!;

  if (isAndroid && !await isFileAvailable(url)) {
    _logger.warning('Android update file not available');
    return;
  }

  final s = S.of(context);
  if (s == null) {
    showSnackBar(context, const Text('Null l10n'));
    return;
  }

  final min = update.build.min.current;

  if (min != null && min > BuildData.build) {
    showRoundDialog(
      context: context,
      child: Text(s.updateTipTooLow(newest)),
      actions: [
        TextButton(
          onPressed: () => _doUpdate(update, context, s),
          child: Text(s.ok),
        )
      ],
    );
    return;
  }

  showSnackBarWithAction(
    context,
    '${s.updateTip(newest)} \n${update.changelog.current}',
    s.update,
    () => _doUpdate(update, context, s),
  );
}

Future<void> _doUpdate(AppUpdate update, BuildContext context, S s) async {
  final url = update.url.current;
  if (url == null) return;

  if (isAndroid) {
    final fileName = url.split('/').last;
    await RUpgrade.upgrade(url, fileName: fileName);
  } else if (isIOS) {
    await RUpgrade.upgradeFromAppStore('1586449703');
  } else if (isMacOS) {
    await openUrl(url);
  } else {
    showRoundDialog(
      context: context,
      child: Text(s.platformNotSupportUpdate),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(s.ok),
        )
      ],
    );
  }
}

// rmdir Download
Future<void> _rmDownloadApks() async {
  if (!isAndroid) return;
  final dlDir = Directory(await _dlDir);
  if (await dlDir.exists()) {
    await dlDir.delete(recursive: true);
  }
}

Future<String> get _dlDir async => joinPath(await docDir, 'Download');

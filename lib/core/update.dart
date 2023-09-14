import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/data/model/app/update.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/provider.dart';

import '../data/res/build_data.dart';
import '../data/service/app.dart';
import '../locator.dart';
import 'utils/platform.dart';
import 'utils/ui.dart';

Future<bool> isFileAvailable(String url) async {
  try {
    final resp = await Dio().head(url);
    return resp.statusCode == 200;
  } catch (e) {
    Loggers.app.warning('HEAD update file failed', e);
    return false;
  }
}

Future<void> doUpdate(BuildContext context, {bool force = false}) async {
  await _rmDownloadApks();

  final update = await locator<AppService>().getUpdate();

  final newest = update.build.last.current;
  if (newest == null) {
    Loggers.app.warning('Update not available on $platform');
    return;
  }

  Providers.app.newestBuild = newest;

  if (!force && newest <= BuildData.build) {
    Loggers.app.info('Update ignored: ${BuildData.build} >= $newest');
    return;
  }
  Loggers.app.info('Update available: $newest');

  final url = update.url.current!;

  if ((isAndroid || isMacOS) && !await isFileAvailable(url)) {
    Loggers.app.warning('Update file not available');
    return;
  }

  final s = S.of(context);

  final min = update.build.min.current;

  if (min != null && min > BuildData.build) {
    context.showRoundDialog(
      child: Text(s?.updateTipTooLow(newest) ?? 'Update: $newest'),
      actions: [
        TextButton(
          onPressed: () => _doUpdate(update, context, s),
          child: Text(s?.ok ?? 'Ok'),
        )
      ],
    );
    return;
  }

  context.showSnackBarWithAction(
    '${s?.updateTip(newest) ?? "Update: $newest"} \n${update.changelog.current}',
    s?.update ?? 'Update',
    () => _doUpdate(update, context, s),
  );
}

Future<void> _doUpdate(AppUpdate update, BuildContext context, S? s) async {
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
    context.showRoundDialog(
      child: Text(s?.platformNotSupportUpdate ?? 'Unsupported platform'),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(s?.ok ?? 'Ok'),
        )
      ],
    );
  }
}

// rmdir Download
Future<void> _rmDownloadApks() async {
  if (!isAndroid) return;
  final dlDir = Directory(await Paths.dl);
  if (await dlDir.exists()) {
    await dlDir.delete(recursive: true);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:logging/logging.dart';
import 'package:r_upgrade/r_upgrade.dart';

import '../data/model/app/update.dart';
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
  final update = await locator<AppService>().getUpdate();

  locator<AppProvider>().setNewestBuild(update.newest);

  final newest = () {
    if (isAndroid) {
      return update.androidbuild;
    } else if (isIOS) {
      return update.iosbuild;
    } else if (isMacOS) {
      return update.macbuild;
    }
    return update.newest;
  }();

  if (!force && newest <= BuildData.build) {
    _logger.info('Update ignored due to current: ${BuildData.build}, '
        'update: $newest');
    return;
  }
  _logger.info('Update available: $newest');

  if (isAndroid && !await isFileAvailable(update.android)) {
    _logger.warning('Android update file not available');
    return;
  }

  final s = S.of(context)!;

  if (update.min > BuildData.build) {
    showRoundDialog(
      context,
      s.attention,
      Text(s.updateTipTooLow(newest)),
      [
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
    '${s.updateTip(newest)} \n${update.changelog}',
    s.update,
    () => _doUpdate(update, context, s),
  );
}

Future<void> _doUpdate(AppUpdate update, BuildContext context, S s) async {
  if (isAndroid) {
    await RUpgrade.upgrade(
      update.android,
      fileName: update.android.split('/').last,
      isAutoRequestInstall: true,
    );
  } else if (isIOS) {
    await RUpgrade.upgradeFromAppStore('1586449703');
  } else {
    showRoundDialog(context, s.attention, Text(s.platformNotSupportUpdate), [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(s.ok),
      )
    ]);
  }
}

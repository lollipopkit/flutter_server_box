import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:logging/logging.dart';
import 'package:r_upgrade/r_upgrade.dart';

import '../data/provider/app.dart';
import '../data/res/build_data.dart';
import '../data/service/app.dart';
import '../locator.dart';
import 'utils/navigator.dart';
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

  final newest = update.build.last.current;
  if (newest == null) {
    _logger.warning('Update not available on $platform');
    return;
  }

  locator<AppProvider>().setNewestBuild(newest);

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

  final s = S.of(context)!;

  if (update.build.min.current! > BuildData.build) {
    showRoundDialog(
      context,
      s.attention,
      Text(s.updateTipTooLow(newest)),
      [
        TextButton(
          onPressed: () => _doUpdate(url, context, s),
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
    () => _doUpdate(url, context, s),
  );
}

Future<void> _doUpdate(String url, BuildContext context, S s) async {
  if (isAndroid) {
    await RUpgrade.upgrade(
      url,
      fileName: url.split('/').last,
      isAutoRequestInstall: true,
    );
  } else if (isIOS) {
    await RUpgrade.upgradeFromAppStore('1586449703');
  } else {
    showRoundDialog(context, s.attention, Text(s.platformNotSupportUpdate), [
      TextButton(
        onPressed: () => context.pop(),
        child: Text(s.ok),
      )
    ]);
  }
}

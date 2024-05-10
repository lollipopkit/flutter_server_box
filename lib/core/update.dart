
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/app/update.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/service/app.dart';
import 'package:toolbox/locator.dart';

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
  final update = await locator<AppService>().getUpdate();

  final newest = update.build.last.current; 
  if (newest == null) {
    Loggers.app.warning('Update not available on ${OS.type}');
    return;
  }

  Pros.app.newestBuild = newest;

  if (!force && newest <= BuildData.build) {
    Loggers.app.info('Update ignored: ${BuildData.build} >= $newest');
    return;
  }
  Loggers.app.info('Update available: $newest');

  final url = update.url.current!;

  if (isFileUrl(url) && !await isFileAvailable(url)) {
    Loggers.app.warning('Update file not available');
    return;
  }

  final min = update.build.min.current;

  if (min != null && min > BuildData.build) {
    context.showRoundDialog(
      child: Text(l10n.updateTipTooLow(newest)),
      actions: [
        TextButton(
          onPressed: () => _doUpdate(update, context),
          child: Text(l10n.ok),
        )
      ],
    );
    return;
  }

  context.showSnackBarWithAction(
    '${l10n.updateTip(newest)} \n${update.changelog.current}',
    l10n.update,
    () => _doUpdate(update, context),
  );
}

Future<void> _doUpdate(AppUpdate update, BuildContext context) async {
  final url = update.url.current;
  if (url == null) {
    Loggers.app.warning('Update url is null');
    context.showSnackBar(l10n.failed);
    return;
  }

  await openUrl(url);
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/misc.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/app/update.dart';
import 'package:toolbox/data/res/build_data.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
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
  await _rmDownloadApks();

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
    Loggers.app.warning('Update url not is null');
    return;
  }

  if (isAndroid) {
    final useBrowser = await _openUrlUpdate(context);
    final _ = switch (useBrowser) {
      1 => await RUpgrade.upgrade(url, fileName: url.split('/').last),
      2 => await openUrl(url),
      _ => null,
    };
  } else if (isIOS) {
    await RUpgrade.upgradeFromAppStore('1586449703');
  } else {
    await openUrl(url);
  }
}

Future<int?> _openUrlUpdate(BuildContext context) async {
  final inAppUpdate = Stores.setting.inAppUpdate;
  final val = inAppUpdate.fetch();
  if (val == 0) {
    var remember = true;
    final selection = await context.showRoundDialog<int>(
      title: Text(l10n.attention),
      child: StatefulBuilder(builder: (_, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.inAppUpdate, style: UIs.text15Bold),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: remember,
              onChanged: (v) => setState(() => remember = v ?? true),
              title: Text(l10n.rememberChoice),
            ),
          ],
        );
      }),
      actions: [
        TextButton(
          onPressed: () => context.pop(0),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (remember) {
              inAppUpdate.put(1);
            }
            context.pop(1);
          },
          child: const Text('App'),
        ),
        TextButton(
          onPressed: () {
            if (remember) {
              inAppUpdate.put(2);
            }
            context.pop(2);
          },
          child: Text(l10n.browser),
        ),
      ],
    );
    return selection;
  }
  return val;
}

// rmdir Download
Future<void> _rmDownloadApks() async {
  if (!isAndroid) return;
  final dlDir = Directory(await Paths.dl);
  if (await dlDir.exists()) {
    await dlDir.delete(recursive: true);
  }
}

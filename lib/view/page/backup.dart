import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../core/utils/misc.dart';
import '../../data/res/ui.dart';
import '../widget/custom_appbar.dart';
import '../widget/store_switch.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(s.backupAndRestore, style: UIs.textSize18),
      ),
      body: _buildBody(context, s),
    );
  }

  Widget _buildBody(BuildContext context, S s) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMacOS || isIOS) _buildIcloudSync(context, s),
        UIs.height13,
        Padding(
          padding: const EdgeInsets.all(37),
          child: Text(
            s.backupTip,
            textAlign: TextAlign.center,
          ),
        ),
        UIs.height77,
        _buildCard(
          s.restore,
          Icons.download,
          () => _onRestore(context, s),
        ),
        UIs.height13,
        const SizedBox(
          width: 37,
          child: Divider(),
        ),
        UIs.height13,
        _buildCard(
          s.backup,
          Icons.save,
          () async {
            await Backup.backup();
            await shareFiles(context, [await Paths.bak]);
          },
        )
      ],
    );
  }

  Widget _buildCard(
    String text,
    IconData icon,
    FutureOr Function() onTap,
  ) {
    return RoundRectCard(
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              UIs.width7,
              Text(text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcloudSync(BuildContext context, S s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'iCloud',
          textAlign: TextAlign.center,
        ),
        UIs.width13,
        // Hive db only save data into local file after app exit,
        // so this button is useless
        // IconButton(
        //     onPressed: () async {
        //       showLoadingDialog(context);
        //       await ICloud.syncDb();
        //       context.pop();
        //       showRestartSnackbar(context, btn: s.restart, msg: s.icloudSynced);
        //     },
        //     icon: const Icon(Icons.sync)),
        // width13,
        StoreSwitch(prop: Stores.setting.icloudSync)
      ],
    );
  }

  Future<void> _onRestore(BuildContext context, S s) async {
    final path = await pickOneFile();
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) {
      context.showSnackBar(s.fileNotExist(path));
      return;
    }

    final text = await file.readAsString();
    if (text.isEmpty) {
      context.showSnackBar(s.fieldMustNotEmpty);
      return;
    }

    try {
      context.showLoadingDialog();
      final backup = await compute(Backup.fromJsonString, text.trim());
      if (backupFormatVersion != backup.version) {
        context.showSnackBar(s.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: Text(s.restore),
        child: Text(s.restoreSureWithDate(backup.date)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () async {
              backup.restore();
              context.pop();
              context.showRestartSnackbar(btn: s.restart, msg: s.needRestart);
            },
            child: Text(s.ok),
          ),
        ],
      );
    } catch (e, trace) {
      Loggers.app.warning('Import backup failed', e, trace);
      context.showSnackBar(e.toString());
    } finally {
      context.pop();
    }
  }
}

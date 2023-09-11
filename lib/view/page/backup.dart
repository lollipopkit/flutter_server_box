import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/core/utils/backup.dart';
import 'package:toolbox/core/utils/platform.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../core/utils/misc.dart';
import '../../core/utils/ui.dart';
import '../../data/res/ui.dart';
import '../../data/store/setting.dart';
import '../../locator.dart';
import '../widget/custom_appbar.dart';

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final _setting = locator<SettingStore>();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(s.backupAndRestore, style: textSize18),
      ),
      body: _buildBody(context, s),
    );
  }

  Widget _buildBody(BuildContext context, S s) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMacOS || isIOS) _buildIcloudSync(context),
        height13,
        Padding(
          padding: const EdgeInsets.all(37),
          child: Text(
            s.backupTip,
            textAlign: TextAlign.center,
          ),
        ),
        height77,
        _buildCard(
          s.restore,
          Icons.download,
          () => _onRestore(context, s),
        ),
        height13,
        const SizedBox(
          width: 37,
          child: Divider(),
        ),
        height13,
        _buildCard(
          s.backup,
          Icons.save,
          () async {
            await backup();
            await shareFiles(context, [await backupPath]);
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
              width7,
              Text(text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcloudSync(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'iCloud',
          textAlign: TextAlign.center,
        ),
        width13,
        buildSwitch(context, _setting.icloudSync)
      ],
    );
  }

  Future<void> _onRestore(BuildContext context, S s) async {
    final path = await pickOneFile();
    if (path == null) {
      showSnackBar(context, Text(s.notSelected));
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      showSnackBar(context, Text(s.fileNotExist(path)));
      return;
    }
    final text = await file.readAsString();
    _import(text, context, s);
  }

  Future<void> _import(String text, BuildContext context, S s) async {
    if (text.isEmpty) {
      showSnackBar(context, Text(s.fieldMustNotEmpty));
      return;
    }
    await _importBackup(text, context, s);
  }

  Future<void> _importBackup(String raw, BuildContext context, S s) async {
    try {
      final backup = await decodeBackup(raw);
      if (backupFormatVersion != backup.version) {
        showSnackBar(context, Text(s.backupVersionNotMatch));
        return;
      }

      await showRoundDialog(
        context: context,
        title: Text(s.restore),
        child: Text(s.restoreSureWithDate(backup.date)),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () async {
              restore(backup);
              context.pop();
              showRestartSnackbar(context, btn: s.restart, msg: s.needRestart);
            },
            child: Text(s.ok),
          ),
        ],
      );
    } catch (e) {
      showSnackBar(context, Text(e.toString()));
      rethrow;
    }
  }
}

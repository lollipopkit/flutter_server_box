import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/core/utils/icloud.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/share.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/rebuild.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/expand_tile.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/store_switch.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

import '../../core/utils/misc.dart';
import '../../data/res/ui.dart';
import '../widget/custom_appbar.dart';

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final icloudLoading = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.backupAndRestore, style: UIs.textSize18),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        if (isMacOS || isIOS) _buildIcloud(context),
        _buildFile(context),
      ],
    );
  }

  Widget _buildFile(BuildContext context) {
    return CardX(
      ExpandTile(
        title: Text(l10n.files),
        initiallyExpanded: true,
        children: [
          ListTile(
            title: Text(l10n.backup),
            trailing: const Icon(Icons.save),
            subtitle: Text(
              l10n.backupTip,
              style: UIs.textGrey,
            ),
            onTap: _onBackup,
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(l10n.restore),
            onTap: () => _onRestore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildIcloud(BuildContext context) {
    return CardX(
      ExpandTile(
        title: const Text('iCloud'),
        initiallyExpanded: true,
        subtitle: Text(
          l10n.syncTip,
          style: UIs.textGrey,
        ),
        children: [
          ListTile(
            title: Text(l10n.auto),
            subtitle: const Text(
              'Unavailable, please wait for optimization :)',
              style: UIs.textGrey,
            ),
            trailing: StoreSwitch(
              prop: Stores.setting.icloudSync,
              func: (val) async {
                if (val) {
                  final relativePaths = await PersistentStore.getFileNames();
                  await ICloud.sync(relativePaths: relativePaths);
                }
              },
            ),
          ),
          ListTile(
            title: Text(l10n.manual),
            trailing: ValueBuilder(
              listenable: icloudLoading,
              build: () {
                if (icloudLoading.value) {
                  return UIs.centerSizedLoadingSmall;
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 137),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          icloudLoading.value = true;
                          final files = await PersistentStore.getFileNames();
                          for (final file in files) {
                            await ICloud.download(relativePath: file);
                          }
                          icloudLoading.value = false;
                        },
                        child: Text(l10n.download),
                      ),
                      UIs.width7,
                      TextButton(
                        onPressed: () async {
                          icloudLoading.value = true;
                          final files = await PersistentStore.getFileNames();
                          for (final file in files) {
                            await ICloud.upload(relativePath: file);
                          }
                          icloudLoading.value = false;
                        },
                        child: Text(l10n.upload),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onBackup() async {
    final path = await Backup.backup();

    /// Issue #188
    if (isWindows) {
      await Shares.text(await File(path).readAsString());
    } else {
      await Shares.files([path]);
    }
  }

  Future<void> _onRestore(BuildContext context) async {
    final path = await pickOneFile();
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) {
      context.showSnackBar(l10n.fileNotExist(path));
      return;
    }

    final text = await file.readAsString();
    if (text.isEmpty) {
      context.showSnackBar(l10n.fieldMustNotEmpty);
      return;
    }

    try {
      context.showLoadingDialog();
      final backup = await compute(Backup.fromJsonString, text.trim());
      if (backupFormatVersion != backup.version) {
        context.showSnackBar(l10n.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: Text(l10n.restore),
        child: Text(l10n.askContinue(
          '${l10n.restore} ${l10n.backup}(${backup.date})',
        )),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await backup.restore();
              Pros.reload();
              context.pop();
              RebuildNodes.app.rebuild();
            },
            child: Text(l10n.ok),
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

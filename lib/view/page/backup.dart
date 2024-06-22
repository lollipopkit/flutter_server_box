import 'dart:convert';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sync/icloud.dart';
import 'package:server_box/core/utils/sync/webdav.dart';
import 'package:server_box/data/model/app/backup.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';

class BackupPage extends StatelessWidget {
  BackupPage({super.key});

  final icloudLoading = ValueNotifier(false);
  final webdavLoading = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.backup, style: UIs.text18),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        _buildTip(),
        if (isMacOS || isIOS) _buildIcloud(context),
        _buildWebdav(context),
        _buildFile(context),
        _buildClipboard(context),
        _buildBulkImportServers(context),
      ],
    );
  }

  Widget _buildTip() {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.warning),
        title: Text(l10n.attention),
        subtitle: Text(l10n.backupTip, style: UIs.textGrey),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.file_open),
        title: Text(l10n.files),
        initiallyExpanded: true,
        children: [
          ListTile(
            title: Text(l10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () async {
              final path = await Backup.backup();
              await Pfs.share(path: path);
            },
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(l10n.restore),
            onTap: () async => _onTapFileRestore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildIcloud(BuildContext context) {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.cloud),
        title: const Text('iCloud'),
        trailing: StoreSwitch(
          prop: Stores.setting.icloudSync,
          validator: (p0) {
            if (p0 && Stores.setting.webdavSync.fetch()) {
              context.showSnackBar(l10n.autoBackupConflict);
              return false;
            }
            return true;
          },
          callback: (val) async {
            if (val) {
              icloudLoading.value = true;
              await ICloud.sync();
              icloudLoading.value = false;
            }
          },
        ),
      ),
    );
  }

  Widget _buildWebdav(BuildContext context) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.storage),
        title: const Text('WebDAV'),
        initiallyExpanded: true,
        children: [
          ListTile(
            title: Text(l10n.setting),
            trailing: const Icon(Icons.settings),
            onTap: () async => _onTapWebdavSetting(context),
          ),
          ListTile(
            title: Text(l10n.auto),
            trailing: StoreSwitch(
              prop: Stores.setting.webdavSync,
              validator: (p0) {
                if (p0) {
                  if (Stores.setting.webdavUrl.fetch().isEmpty ||
                      Stores.setting.webdavUser.fetch().isEmpty ||
                      Stores.setting.webdavPwd.fetch().isEmpty) {
                    context.showSnackBar(l10n.webdavSettingEmpty);
                    return false;
                  }
                }
                if (Stores.setting.icloudSync.fetch()) {
                  context.showSnackBar(l10n.autoBackupConflict);
                  return false;
                }
                return true;
              },
              callback: (val) async {
                if (val) {
                  webdavLoading.value = true;
                  await Webdav.sync();
                  webdavLoading.value = false;
                }
              },
            ),
          ),
          ListTile(
            title: Text(l10n.manual),
            trailing: ListenableBuilder(
              listenable: webdavLoading,
              builder: (_, __) {
                if (webdavLoading.value) {
                  return UIs.centerSizedLoadingSmall;
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async => _onTapWebdavDl(context),
                      child: Text(l10n.restore),
                    ),
                    UIs.width7,
                    TextButton(
                      onPressed: () async => _onTapWebdavUp(context),
                      child: Text(l10n.backup),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipboard(BuildContext context) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.content_paste),
        title: Text(l10n.clipboard),
        children: [
          ListTile(
            title: Text(l10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () async {
              final path = await Backup.backup();
              Pfs.copy(await File(path).readAsString());
              context.showSnackBar(l10n.success);
            },
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(l10n.restore),
            onTap: () async => _onTapClipboardRestore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkImportServers(BuildContext context) {
    return CardX(
      child: ListTile(
        title: Text(l10n.bulkImportServers),
        subtitle: SimpleMarkdown(
          data: l10n.bulkImportServersTip(Urls.appWiki),
          styleSheet: MarkdownStyleSheet(
            p: UIs.textGrey,
          ),
        ),
        leading: const Icon(Icons.import_export),
        onTap: () => _onBulkImportServers(context),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Future<void> _onTapFileRestore(BuildContext context) async {
    final text = await Pfs.pickFileString();
    if (text == null) return;

    try {
      final backup = await context.showLoadingDialog(
        fn: () => Computer.shared.start(Backup.fromJsonString, text.trim()),
      );
      if (backupFormatVersion != backup.version) {
        context.showSnackBar(l10n.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: l10n.restore,
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
              await backup.restore(force: true);
              context.pop();
            },
            child: Text(l10n.ok),
          ),
        ],
      );
    } catch (e, s) {
      Loggers.app.warning('Import backup failed', e, s);
      context.showErrDialog(e: e, s: s, operation: l10n.restore);
    }
  }

  Future<void> _onTapWebdavDl(BuildContext context) async {
    webdavLoading.value = true;
    try {
      final files = await Webdav.list();
      if (files.isEmpty) return context.showSnackBar(l10n.dirEmpty);

      final fileName = await context.showPickSingleDialog(
        title: l10n.restore,
        items: files,
      );
      if (fileName == null) return;

      final result = await Webdav.download(relativePath: fileName);
      if (result != null) {
        throw result;
      }
      final dlFile = await File('${Paths.doc}/$fileName').readAsString();
      final dlBak = await Computer.shared.start(Backup.fromJsonString, dlFile);
      await dlBak.restore(force: true);
    } catch (e, s) {
      context.showErrDialog(e: e, s: s, operation: l10n.restore);
      Loggers.app.warning('Download webdav backup failed', e, s);
    } finally {
      webdavLoading.value = false;
    }
  }

  Future<void> _onTapWebdavUp(BuildContext context) async {
    webdavLoading.value = true;
    final date = DateTime.now().ymdhms(ymdSep: "-", hmsSep: "-", sep: "-");
    final bakName = '$date-${Miscs.bakFileName}';
    try {
      await Backup.backup(bakName);
      final uploadResult = await Webdav.upload(relativePath: bakName);
      if (uploadResult != null) {
        throw uploadResult;
      }
      Loggers.app.info('Upload webdav backup success');
    } catch (e, s) {
      context.showErrDialog(e: e, s: s, operation: l10n.upload);
      Loggers.app.warning('Upload webdav backup failed', e, s);
    } finally {
      webdavLoading.value = false;
    }
  }

  Future<void> _onTapWebdavSetting(BuildContext context) async {
    final url = TextEditingController(text: Stores.setting.webdavUrl.fetch());
    final user = TextEditingController(text: Stores.setting.webdavUser.fetch());
    final pwd = TextEditingController(text: Stores.setting.webdavPwd.fetch());
    final result = await context.showRoundDialog<bool>(
      title: 'WebDAV',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            label: 'URL',
            hint: 'https://example.com/webdav/',
            controller: url,
          ),
          Input(
            label: l10n.user,
            controller: user,
          ),
          Input(
            label: l10n.pwd,
            controller: pwd,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.pop(true);
          },
          child: Text(l10n.ok),
        ),
      ],
    );
    if (result == true) {
      final result = await Webdav.test(url.text, user.text, pwd.text);
      if (result != null) {
        context.showSnackBar(result);
        return;
      }
      context.showSnackBar(l10n.success);
      Webdav.changeClient(url.text, user.text, pwd.text);
    }
  }

  void _onTapClipboardRestore(BuildContext context) async {
    final text = await Pfs.paste();
    if (text == null || text.isEmpty) {
      context.showSnackBar(l10n.fieldMustNotEmpty);
      return;
    }

    try {
      final backup = await context.showLoadingDialog(
        fn: () => Computer.shared.start(Backup.fromJsonString, text.trim()),
      );

      if (backupFormatVersion != backup.version) {
        context.showSnackBar(l10n.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: l10n.restore,
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
              await backup.restore(force: true);
              context.pop();
            },
            child: Text(l10n.ok),
          ),
        ],
      );
    } catch (e, s) {
      Loggers.app.warning('Import backup failed', e, s);
      context.showErrDialog(e: e, s: s, operation: l10n.restore);
    }
  }

  void _onBulkImportServers(BuildContext context) async {
    final text = await Pfs.pickFileString();
    if (text == null) return;

    try {
      final spis = await context.showLoadingDialog(
        fn: () => Computer.shared.start((val) {
          final list = json.decode(val) as List;
          return list.map((e) => ServerPrivateInfo.fromJson(e)).toList();
        }, text.trim()),
      );
      final sure = await context.showRoundDialog<bool>(
        title: l10n.import,
        child: Text(l10n.askContinue('${spis.length} ${l10n.server}')),
        actions: [
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(l10n.ok),
          ),
        ],
      );
      if (sure == true) {
        await context.showLoadingDialog(
          fn: () async {
            for (var spi in spis) {
              Stores.server.put(spi);
            }
          },
        );
        context.showSnackBar(l10n.success);
      }
    } catch (e, s) {
      context.showErrDialog(e: e, s: s, operation: l10n.import);
      Loggers.app.warning('Import servers failed', e, s);
    }
  }
}

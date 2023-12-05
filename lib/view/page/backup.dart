import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/utils/sync/icloud.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/share.dart';
import 'package:toolbox/core/utils/sync/webdav.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/expand_tile.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/store_switch.dart';
import 'package:toolbox/view/widget/value_notifier.dart';

import '../../core/utils/misc.dart';
import '../../data/res/ui.dart';
import '../widget/custom_appbar.dart';

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final icloudLoading = ValueNotifier(false);
  final webdavLoading = ValueNotifier(false);

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
        _buildTip(),
        if (isMacOS || isIOS) _buildIcloud(context),
        _buildWebdav(context),
        _buildFile(context),
      ],
    );
  }

  Widget _buildTip() {
    return CardX(
      ListTile(
        leading: const Icon(Icons.warning),
        title: Text(l10n.attention),
        subtitle: Text(l10n.backupTip, style: UIs.textGrey),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    return CardX(
      ExpandTile(
        leading: const Icon(Icons.file_open),
        title: Text(l10n.files),
        initiallyExpanded: true,
        children: [
          ListTile(
            title: Text(l10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () async {
              final path = await Backup.backup();

              /// Issue #188
              if (isWindows) {
                await Shares.text(await File(path).readAsString());
              } else {
                await Shares.files([path]);
              }
            },
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(l10n.restore),
            onTap: () async {
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
                final backup =
                    await compute(Backup.fromJsonString, text.trim());
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
                        await backup.restore(force: true);
                        context.pop();
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIcloud(BuildContext context) {
    return CardX(
      ExpandTile(
        leading: const Icon(Icons.cloud),
        title: const Text('iCloud'),
        initiallyExpanded: true,
        children: [
          ListTile(
            title: Text(l10n.auto),
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
          ListTile(
            title: Text(l10n.manual),
            trailing: ValueBuilder(
              listenable: icloudLoading,
              build: () {
                if (icloudLoading.value) {
                  return UIs.centerSizedLoadingSmall;
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        icloudLoading.value = true;
                        try {
                          final result = await ICloud.download(
                            relativePath: Paths.bakName,
                          );
                          if (result != null) {
                            Loggers.app
                                .warning('Download backup failed: $result');
                            return;
                          }
                        } catch (e, s) {
                          Loggers.app.warning('Download backup failed', e, s);
                          context.showSnackBar(e.toString());
                          icloudLoading.value = false;
                          return;
                        }
                        final dlFile =
                            await File(await Paths.bak).readAsString();
                        final dlBak =
                            await compute(Backup.fromJsonString, dlFile);
                        await dlBak.restore(force: true);
                        icloudLoading.value = false;
                      },
                      child: Text(l10n.download),
                    ),
                    UIs.width7,
                    TextButton(
                      onPressed: () async {
                        icloudLoading.value = true;
                        await Backup.backup();
                        final uploadResult =
                            await ICloud.upload(relativePath: Paths.bakName);
                        if (uploadResult != null) {
                          Loggers.app.warning(
                              'Upload iCloud backup failed: $uploadResult');
                        } else {
                          Loggers.app.info('Upload iCloud backup success');
                        }
                        icloudLoading.value = false;
                      },
                      child: Text(l10n.upload),
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

  Widget _buildWebdav(BuildContext context) {
    return CardX(
      ExpandTile(
        leading: const Icon(Icons.storage),
        title: const Text('WebDAV'),
        initiallyExpanded: !(isIOS || isMacOS),
        children: [
          ListTile(
            title: Text(l10n.setting),
            trailing: const Icon(Icons.settings),
            onTap: () async {
              final urlCtrl = TextEditingController(
                text: Stores.setting.webdavUrl.fetch(),
              );
              final userCtrl = TextEditingController(
                text: Stores.setting.webdavUser.fetch(),
              );
              final pwdCtrl = TextEditingController(
                text: Stores.setting.webdavPwd.fetch(),
              );
              final result = await context.showRoundDialog<bool>(
                title: const Text('WebDAV'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Input(
                      label: 'URL',
                      hint: 'https://example.com/webdav/',
                      controller: urlCtrl,
                    ),
                    Input(
                      label: l10n.user,
                      controller: userCtrl,
                    ),
                    Input(
                      label: l10n.pwd,
                      controller: pwdCtrl,
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
                final result = await Webdav.test(
                  urlCtrl.text,
                  userCtrl.text,
                  pwdCtrl.text,
                );
                if (result == null) {
                  context.showSnackBar(l10n.success);
                } else {
                  context.showSnackBar(result);
                  return;
                }
                Webdav.changeClient(
                  urlCtrl.text,
                  userCtrl.text,
                  pwdCtrl.text,
                );
                Stores.setting.webdavUrl.put(urlCtrl.text);
                Stores.setting.webdavUser.put(userCtrl.text);
                Stores.setting.webdavPwd.put(pwdCtrl.text);
              }
            },
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
            trailing: ValueBuilder(
              listenable: webdavLoading,
              build: () {
                if (webdavLoading.value) {
                  return UIs.centerSizedLoadingSmall;
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        webdavLoading.value = true;
                        try {
                          final result = await Webdav.download(
                            relativePath: Paths.bakName,
                          );
                          if (result != null) {
                            Loggers.app.warning(
                                'Download webdav backup failed: $result');
                            return;
                          }
                        } catch (e, s) {
                          Loggers.app
                              .warning('Download webdav backup failed', e, s);
                          context.showSnackBar(e.toString());
                          webdavLoading.value = false;
                          return;
                        }
                        final dlFile =
                            await File(await Paths.bak).readAsString();
                        final dlBak =
                            await compute(Backup.fromJsonString, dlFile);
                        await dlBak.restore(force: true);
                        webdavLoading.value = false;
                      },
                      child: Text(l10n.download),
                    ),
                    UIs.width7,
                    TextButton(
                      onPressed: () async {
                        webdavLoading.value = true;
                        await Backup.backup();
                        final uploadResult =
                            await Webdav.upload(relativePath: Paths.bakName);
                        if (uploadResult != null) {
                          Loggers.app.warning(
                              'Upload webdav backup failed: $uploadResult');
                        } else {
                          Loggers.app.info('Upload webdav backup success');
                        }
                        webdavLoading.value = false;
                      },
                      child: Text(l10n.upload),
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
}

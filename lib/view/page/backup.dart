import 'dart:convert';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/backup.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:webdav_client/webdav_client.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

final class _BackupPageState extends State<BackupPage>
    with AutomaticKeepAliveClientMixin {
  final icloudLoading = false.vn;
  final webdavLoading = false.vn;

  @override
  void dispose() {
    icloudLoading.dispose();
    webdavLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return MultiList(
      widthDivider: 2,
      children: [
        [
          CenterGreyTitle(libL10n.sync),
          _buildTip(),
          if (isMacOS || isIOS) _buildIcloud(context),
          _buildWebdav(context),
          _buildFile(context),
          _buildClipboard(context),
        ],
        [
          CenterGreyTitle(libL10n.import),
          _buildBulkImportServers(context),
          _buildImportSnippet(context),
        ],
      ],
    );
  }

  Widget _buildTip() {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.warning),
        title: Text(libL10n.attention),
        subtitle: Text(l10n.backupTip, style: UIs.textGrey),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.file_open),
        title: Text(libL10n.file),
        initiallyExpanded: false,
        children: [
          ListTile(
            title: Text(libL10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () async {
              final path = await Backup.backup();
              await Pfs.share(path: path);
            },
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(libL10n.restore),
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
          prop: PrefProps.icloudSync,
          validator: (p0) {
            if (p0 && PrefProps.webdavSync.get()) {
              context.showSnackBar(l10n.autoBackupConflict);
              return false;
            }
            return true;
          },
          callback: (val) async {
            if (val) {
              icloudLoading.value = true;
              await bakSync.sync(rs: icloud);
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
        initiallyExpanded: false,
        children: [
          ListTile(
            title: Text(libL10n.setting),
            trailing: const Icon(Icons.settings),
            onTap: () async => _onTapWebdavSetting(context),
          ),
          ListTile(
            title: Text(libL10n.auto),
            trailing: StoreSwitch(
              prop: PrefProps.webdavSync,
              validator: (p0) {
                if (p0) {
                  final url = PrefProps.webdavUrl.get();
                  final user = PrefProps.webdavUser.get();
                  final pwd = PrefProps.webdavPwd.get();

                  final anyNull = url == null || user == null || pwd == null;
                  if (anyNull) {
                    context.showSnackBar(l10n.webdavSettingEmpty);
                    return false;
                  }

                  final anyEmpty = url.isEmpty || user.isEmpty || pwd.isEmpty;
                  if (anyEmpty) {
                    context.showSnackBar(l10n.webdavSettingEmpty);
                    return false;
                  }
                }
                if (PrefProps.icloudSync.get()) {
                  context.showSnackBar(l10n.autoBackupConflict);
                  return false;
                }
                return true;
              },
              callback: (val) async {
                if (val) {
                  webdavLoading.value = true;
                  await bakSync.sync(rs: Webdav.shared);
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
                if (webdavLoading.value) return SizedLoading.small;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async => _onTapWebdavDl(context),
                      child: Text(libL10n.restore),
                    ),
                    UIs.width7,
                    TextButton(
                      onPressed: () async => _onTapWebdavUp(context),
                      child: Text(libL10n.backup),
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
        title: Text(libL10n.clipboard),
        children: [
          ListTile(
            title: Text(libL10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () async {
              final path = await Backup.backup();
              Pfs.copy(await File(path).readAsString());
              context.showSnackBar(libL10n.success);
            },
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(libL10n.restore),
            onTap: () async => _onTapClipboardRestore(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkImportServers(BuildContext context) {
    return CardX(
      child: ListTile(
        title: Text(l10n.server),
        leading: const Icon(BoxIcons.bx_server),
        onTap: () => _onBulkImportServers(context),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Widget _buildImportSnippet(BuildContext context) {
    return ListTile(
      title: Text(l10n.snippet),
      leading: const Icon(MingCute.code_line),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final data = await context.showImportDialog(
          title: l10n.snippet,
          modelDef: Snippet.example.toJson(),
        );
        if (data == null) return;
        final str = String.fromCharCodes(data);
        final (list, _) = await context.showLoadingDialog(
          fn: () => Computer.shared.start((s) {
            return json.decode(s) as List;
          }, str),
        );
        if (list == null || list.isEmpty) return;
        final snippets = <Snippet>[];
        final errs = <String>[];
        for (final item in list) {
          try {
            final snippet = Snippet.fromJson(item);
            snippets.add(snippet);
          } catch (e) {
            errs.add(e.toString());
          }
        }
        if (snippets.isEmpty) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        if (errs.isNotEmpty) {
          context.showRoundDialog(
            title: libL10n.error,
            child: SingleChildScrollView(child: Text(errs.join('\n'))),
          );
          return;
        }
        final snippetNames = snippets.map((e) => e.name).join(', ');
        context.showRoundDialog(
          title: libL10n.attention,
          child: SingleChildScrollView(
            child: Text(
              libL10n.askContinue('${libL10n.import} [$snippetNames]'),
            ),
          ),
          actions: Btn.ok(
            onTap: () {
              for (final snippet in snippets) {
                SnippetProvider.add(snippet);
              }
              context.pop();
              context.pop();
            },
          ).toList,
        );
      },
    ).cardx;
  }

  Future<void> _onTapFileRestore(BuildContext context) async {
    final text = await Pfs.pickFileString();
    if (text == null) return;

    try {
      final (backup, err) = await context.showLoadingDialog(
        fn: () => Computer.shared.start(Backup.fromJsonString, text.trim()),
      );
      if (err != null || backup == null) return;
      if (backupFormatVersion != backup.version) {
        context.showSnackBar(l10n.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: libL10n.restore,
        child: Text(libL10n.askContinue(
          '${libL10n.restore} ${libL10n.backup}(${backup.date})',
        )),
        actions: Btn.ok(
          onTap: () async {
            await backup.merge(force: true);
            context.pop();
          },
        ).toList,
      );
    } catch (e, s) {
      Loggers.app.warning('Import backup failed', e, s);
      context.showErrDialog(e, s, libL10n.restore);
    }
  }

  Future<void> _onTapWebdavDl(BuildContext context) async {
    webdavLoading.value = true;
    try {
      final files = await Webdav.shared.list();
      if (files.isEmpty) return context.showSnackBar(l10n.dirEmpty);

      final fileName = await context.showPickSingleDialog(
        title: libL10n.restore,
        items: files,
      );
      if (fileName == null) return;

      await Webdav.shared.download(relativePath: fileName);
      final dlFile = await File('${Paths.doc}/$fileName').readAsString();
      final dlBak = await Computer.shared.start(Backup.fromJsonString, dlFile);
      await dlBak.merge(force: true);
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.restore);
      Loggers.app.warning('Download webdav backup failed', e, s);
    } finally {
      webdavLoading.value = false;
    }
  }

  Future<void> _onTapWebdavUp(BuildContext context) async {
    webdavLoading.value = true;
    final date = DateTime.now().ymdhms(ymdSep: '-', hmsSep: '-', sep: '-');
    final bakName = '$date-${Miscs.bakFileName}';
    try {
      await Backup.backup(bakName);
      await Webdav.shared.upload(relativePath: bakName);
      Loggers.app.info('Upload webdav backup success');
    } catch (e, s) {
      context.showErrDialog(e, s, l10n.upload);
      Loggers.app.warning('Upload webdav backup failed', e, s);
    } finally {
      webdavLoading.value = false;
    }
  }

  Future<void> _onTapWebdavSetting(BuildContext context) async {
    final url = TextEditingController(text: PrefProps.webdavUrl.get());
    final user = TextEditingController(text: PrefProps.webdavUser.get());
    final pwd = TextEditingController(text: PrefProps.webdavPwd.get());
    final nodeUser = FocusNode();
    final nodePwd = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: 'WebDAV',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            label: 'URL',
            hint: 'https://example.com/sub/',
            controller: url,
            suggestion: false,
            onSubmitted: (p0) => FocusScope.of(context).requestFocus(nodeUser),
          ),
          Input(
            label: libL10n.user,
            controller: user,
            node: nodeUser,
            suggestion: false,
            onSubmitted: (p0) => FocusScope.of(context).requestFocus(nodePwd),
          ),
          Input(
            label: l10n.pwd,
            controller: pwd,
            node: nodePwd,
            suggestion: false,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );
    if (result == true) {
      try {
        final url_ = url.text;
        final user_ = user.text;
        final pwd_ = pwd.text;

        await Webdav.test(url_, user_, pwd_);
        context.showSnackBar(libL10n.success);

        Webdav.shared.client = WebdavClient(url: url_, user: user_, pwd: pwd_);
        PrefProps.webdavUrl.set(url_);
        PrefProps.webdavUser.set(user_);
        PrefProps.webdavPwd.set(pwd_);
      } catch (e, s) {
        context.showErrDialog(e, s, 'Webdav');
      }
    }
  }

  void _onTapClipboardRestore(BuildContext context) async {
    final text = await Pfs.paste();
    if (text == null || text.isEmpty) {
      context.showSnackBar(libL10n.empty);
      return;
    }

    try {
      final (backup, err) = await context.showLoadingDialog(
        fn: () => Computer.shared.start(Backup.fromJsonString, text.trim()),
      );
      if (err != null || backup == null) return;

      if (backupFormatVersion != backup.version) {
        context.showSnackBar(l10n.backupVersionNotMatch);
        return;
      }

      await context.showRoundDialog(
        title: libL10n.restore,
        child: Text(libL10n.askContinue(
          '${libL10n.restore} ${libL10n.backup}(${backup.date})',
        )),
        actions: Btn.ok(
          onTap: () async {
            await backup.merge(force: true);
            context.pop();
          },
        ).toList,
      );
    } catch (e, s) {
      Loggers.app.warning('Import backup failed', e, s);
      context.showErrDialog(e, s, libL10n.restore);
    }
  }

  void _onBulkImportServers(BuildContext context) async {
    final data = await context.showImportDialog(
      title: l10n.server,
      modelDef: Spix.example.toJson(),
    );
    if (data == null) return;
    final text = String.fromCharCodes(data);

    try {
      final (spis, err) = await context.showLoadingDialog(
        fn: () => Computer.shared.start((val) {
          final list = json.decode(val) as List;
          return list.map((e) => Spi.fromJson(e)).toList();
        }, text.trim()),
      );
      if (err != null || spis == null) return;
      final sure = await context.showRoundDialog<bool>(
        title: libL10n.import,
        child: Text(libL10n.askContinue('${spis.length} ${l10n.server}')),
        actions: Btnx.oks,
      );
      if (sure == true) {
        final (suc, err) = await context.showLoadingDialog(
          fn: () async {
            for (var spi in spis) {
              Stores.server.put(spi);
            }
            return true;
          },
        );
        if (err != null || suc != true) return;
        context.showSnackBar(libL10n.success);
      }
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.import);
      Loggers.app.warning('Import servers failed', e, s);
    }
  }

  @override
  bool get wantKeepAlive => true;
}

import 'dart:convert';
import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_service.dart';
import 'package:server_box/data/model/app/bak/backup_source.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:webdav_client_plus/webdav_client_plus.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();

  static const route = AppRouteNoArg(page: BackupPage.new, path: '/backup');
}

final class _BackupPageState extends State<BackupPage> with AutomaticKeepAliveClientMixin {
  final webdavLoading = false.vn;
  final gistLoading = false.vn;

  @override
  void dispose() {
    webdavLoading.dispose();
    gistLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(body: _buildBody);
  }

  Widget get _buildBody {
    return MultiList(
      widthDivider: 2,
      children: [
        [
          CenterGreyTitle(libL10n.sync),
          _buildTip,
          _buildBakPwd,
          if (isMacOS || isIOS) _buildIcloud,
          _buildWebdav,
          _buildGist,
          _buildFile,
          _buildClipboard,
        ],
        [CenterGreyTitle(libL10n.import), _buildBulkImportServers, _buildImportSnippet],
      ],
    );
  }

  Widget get _buildBakPwd {
    return FutureBuilder<String?>(
      future: SecureStoreProps.bakPwd.read(),
      builder: (context, snapshot) {
        final hasPwd = snapshot.data?.isNotEmpty == true;
        return CardX(
          child: ListTile(
            leading: const Icon(Icons.lock),
            title: Text(l10n.backupPassword),
            subtitle: Text(hasPwd ? l10n.backupEncrypted : l10n.backupNotEncrypted, style: UIs.textGrey),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () async => _onTapSetBakPwd(context), child: Text(libL10n.setting)),
                if (hasPwd) ...[
                  UIs.width7,
                  TextButton(
                    onPressed: () async {
                      await SecureStoreProps.bakPwd.write(null);
                      context.showSnackBar(l10n.backupPasswordRemoved);
                      setState(() {});
                    },
                    child: Text(libL10n.delete),
                  ),
                ],
              ],
            ),
            onTap: () async => _onTapSetBakPwd(context),
          ),
        );
      },
    );
  }

  Future<void> _onTapSetBakPwd(BuildContext context) async {
    final currentPwd = await SecureStoreProps.bakPwd.read();
    final controller = TextEditingController(text: currentPwd ?? '');
    final node = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: l10n.backupPassword,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.backupPasswordTip, style: UIs.textGrey),
          UIs.height13,
          Input(
            label: l10n.backupPassword,
            controller: controller,
            node: node,
            obscureText: true,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );
    if (result == true) {
      final pwd = controller.text.trim();
      if (pwd.isEmpty) {
        context.showSnackBar(libL10n.empty);
        return;
      }
      await SecureStoreProps.bakPwd.write(pwd);
      context.showSnackBar(l10n.backupPasswordSet);
      setState(() {});
    }
  }

  Future<bool> _ensureBakPwd(BuildContext context) async {
    final saved = await SecureStoreProps.bakPwd.read();
    if (saved != null && saved.isNotEmpty) return true;
    await _onTapSetBakPwd(context);
    final after = await SecureStoreProps.bakPwd.read();
    return after != null && after.isNotEmpty;
  }

  Widget get _buildTip {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.warning),
        title: Text(libL10n.attention),
        subtitle: Text(l10n.backupTip, style: UIs.textGrey),
      ),
    );
  }

  Widget get _buildFile {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.file_open),
        title: Text(libL10n.file),
        initiallyExpanded: false,
        children: [
          ListTile(
            title: Text(libL10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () => BackupService.backup(context, FileBackupSource()),
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(libL10n.restore),
            onTap: () => BackupService.restore(context, FileBackupSource()),
          ),
        ],
      ),
    );
  }

  Widget get _buildIcloud {
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.cloud),
        title: const Text('iCloud'),
        trailing: StoreSwitch(
          prop: PrefProps.icloudSync,
          validator: (p0) async {
            if (p0 && PrefProps.webdavSync.get()) {
              context.showSnackBar(l10n.autoBackupConflict);
              return false;
            }
            if (p0) {
              final ok = await _ensureBakPwd(context);
              if (!ok) return false;
            }
            if (p0) {
              await bakSync.sync(rs: icloud);
            }
            return true;
          },
        ),
      ),
    );
  }

  Widget get _buildWebdav {
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
              validator: (p0) async {
                if (p0 && PrefProps.icloudSync.get()) {
                  context.showSnackBar(l10n.autoBackupConflict);
                  return false;
                }
                if (p0) {
                  final ok = await _ensureBakPwd(context);
                  if (!ok) return false;
                }
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

                  webdavLoading.value = true;
                  await bakSync.sync(rs: Webdav.shared);
                  webdavLoading.value = false;
                }
                return true;
              },
            ),
          ),
          ListTile(
            title: Text(l10n.manual),
            trailing: webdavLoading.listenVal((loading) {
              if (loading) return SizedLoading.small;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () async => _onTapWebdavDl(context), child: Text(libL10n.restore)),
                  UIs.width7,
                  TextButton(onPressed: () async => _onTapWebdavUp(context), child: Text(libL10n.backup)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget get _buildGist {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.code),
        title: const Text('GitHub Gist'),
        initiallyExpanded: false,
        children: [
          ListTile(
            title: Text(libL10n.setting),
            trailing: const Icon(Icons.settings),
            onTap: () async => _onTapGistSetting(context),
          ),
          ListTile(
            title: Text(libL10n.auto),
            trailing: StoreSwitch(
              prop: PrefProps.gistSync,
              validator: (p0) async {
                if (p0 && (PrefProps.icloudSync.get() || PrefProps.webdavSync.get())) {
                  context.showSnackBar(l10n.autoBackupConflict);
                  return false;
                }
                if (p0) {
                  final ok = await _ensureBakPwd(context);
                  if (!ok) return false;
                }
                if (p0) {
                  final token = PrefProps.githubToken.get();
                  // Allow empty gistId (will create one on first upload)
                  final hasToken = token != null && token.isNotEmpty;
                  if (!hasToken) {
                    context.showSnackBar('Token or Gist ID is empty');
                    return false;
                  }
                  gistLoading.value = true;
                  await bakSync.sync(rs: GistRs.shared);
                  gistLoading.value = false;
                }
                return true;
              },
            ),
          ),
          ListTile(
            title: Text(l10n.manual),
            trailing: gistLoading.listenVal((loading) {
              if (loading) return SizedLoading.small;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () async => _onTapGistDl(context), child: Text(libL10n.restore)),
                  UIs.width7,
                  TextButton(onPressed: () async => _onTapGistUp(context), child: Text(libL10n.backup)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget get _buildClipboard {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.content_paste),
        title: Text(libL10n.clipboard),
        children: [
          ListTile(
            title: Text(libL10n.backup),
            trailing: const Icon(Icons.save),
            onTap: () => BackupService.backup(context, ClipboardBackupSource()),
          ),
          ListTile(
            trailing: const Icon(Icons.restore),
            title: Text(libL10n.restore),
            onTap: () => BackupService.restore(context, ClipboardBackupSource()),
          ),
        ],
      ),
    );
  }

  Widget get _buildBulkImportServers {
    return CardX(
      child: ListTile(
        title: Text(l10n.server),
        leading: const Icon(BoxIcons.bx_server),
        onTap: () => _onBulkImportServers(context),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  }

  Widget get _buildImportSnippet {
    return ListTile(
      title: Text(l10n.snippet),
      leading: const Icon(MingCute.code_line),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final data = await context.showImportDialog(title: l10n.snippet, modelDef: Snippet.example.toJson());
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
          child: SingleChildScrollView(child: Text(libL10n.askContinue('${libL10n.import} [$snippetNames]'))),
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

  Future<void> _onTapWebdavDl(BuildContext context) async {
    webdavLoading.value = true;
    try {
      final files = await Webdav.shared.list();
      if (files.isEmpty) return context.showSnackBar(l10n.dirEmpty);

      final fileName = await context.showPickSingleDialog(title: libL10n.restore, items: files);
      if (fileName == null) return;

      await Webdav.shared.download(relativePath: fileName);
      final dlFile = await File('${Paths.doc}/$fileName').readAsString();
      await BackupService.restoreFromText(context, dlFile);
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
      final ok = await _ensureBakPwd(context);
      if (!ok) return;
      final savedPassword = await SecureStoreProps.bakPwd.read();
      await BackupV2.backup(bakName, savedPassword);
      await Webdav.shared.upload(relativePath: bakName);
      Loggers.app.info('Upload webdav backup success');
    } catch (e, s) {
      context.showErrDialog(e, s, l10n.upload);
      Loggers.app.warning('Upload webdav backup failed', e, s);
    } finally {
      webdavLoading.value = false;
    }
  }

  Future<void> _onTapGistDl(BuildContext context) async {
    gistLoading.value = true;
    try {
      final files = await GistRs.shared.list();
      if (files.isEmpty) return context.showSnackBar(l10n.dirEmpty);

      final fileName = await context.showPickSingleDialog(title: libL10n.restore, items: files);
      if (fileName == null) return;

      await GistRs.shared.download(relativePath: fileName);
      final dlFile = await File('${Paths.doc}/$fileName').readAsString();
      await BackupService.restoreFromText(context, dlFile);
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.restore);
      Loggers.app.warning('Download gist backup failed', e, s);
    } finally {
      gistLoading.value = false;
    }
  }

  Future<void> _onTapGistUp(BuildContext context) async {
    gistLoading.value = true;
    final date = DateTime.now().ymdhms(ymdSep: '-', hmsSep: '-', sep: '-');
    final bakName = '$date-${Miscs.bakFileName}';
    try {
      final ok = await _ensureBakPwd(context);
      if (!ok) return;
      final savedPassword = await SecureStoreProps.bakPwd.read();
      await BackupV2.backup(bakName, savedPassword);
      await GistRs.shared.upload(relativePath: bakName);
      Loggers.app.info('Upload gist backup success');
    } catch (e, s) {
      context.showErrDialog(e, s, l10n.upload);
      Loggers.app.warning('Upload gist backup failed', e, s);
    } finally {
      gistLoading.value = false;
    }
  }

  Future<void> _onTapGistSetting(BuildContext context) async {
    final tokenCtrl = TextEditingController(text: PrefProps.githubToken.get());
    final gistIdCtrl = TextEditingController(text: PrefProps.gistId.get());
    final nodeToken = FocusNode();
    final result = await context.showRoundDialog<bool>(
      title: 'GitHub Gist',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(label: 'Token', controller: tokenCtrl, suggestion: false, node: nodeToken),
          Input(
            label: 'Gist ID (optional)',
            controller: gistIdCtrl,
            suggestion: false,
            onSubmitted: (_) => context.pop(true),
          ),
        ],
      ),
      actions: Btnx.oks,
    );
    if (result == true) {
      try {
        final token_ = tokenCtrl.text.trim();
        final gistId_ = gistIdCtrl.text.trim();

        await GistRs.test(token: token_, gistId: gistId_.isEmpty ? null : gistId_);
        context.showSnackBar(libL10n.success);

        await PrefProps.githubToken.set(token_);
        if (gistId_.isEmpty) {
          await PrefProps.gistId.remove();
        } else {
          await PrefProps.gistId.set(gistId_);
        }
      } catch (e, s) {
        context.showErrDialog(e, s, 'Gist');
      }
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
            label: libL10n.pwd,
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

        Webdav.shared.client = WebdavClient.basicAuth(url: url_, user: user_, pwd: pwd_);
        PrefProps.webdavUrl.set(url_);
        PrefProps.webdavUser.set(user_);
        PrefProps.webdavPwd.set(pwd_);
      } catch (e, s) {
        context.showErrDialog(e, s, 'Webdav');
      }
    }
  }

  void _onBulkImportServers(BuildContext context) async {
    final data = await context.showImportDialog(title: l10n.server, modelDef: Spix.example.toJson());
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

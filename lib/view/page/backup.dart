import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../core/utils/misc.dart';
import '../../core/utils/ui.dart';
import '../../data/model/app/backup.dart';
import '../../data/res/ui.dart';
import '../../data/store/docker.dart';
import '../../data/store/private_key.dart';
import '../../data/store/server.dart';
import '../../data/store/setting.dart';
import '../../data/store/snippet.dart';
import '../../locator.dart';
import '../widget/custom_appbar.dart';

const backupFormatVersion = 1;

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final _server = locator<ServerStore>();
  final _snippet = locator<SnippetStore>();
  final _privateKey = locator<PrivateKeyStore>();
  final _dockerHosts = locator<DockerStore>();
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
    final media = MediaQuery.of(context);
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
          media,
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
          media,
          () => _onBackup(context, s),
        )
      ],
    ));
  }

  Widget _buildCard(
    String text,
    IconData icon,
    MediaQueryData media,
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

  Future<void> _onBackup(BuildContext context, S s) async {
    final result = _diyEncrtpt(
      json.encode(
        Backup(
          version: backupFormatVersion,
          date: DateTime.now().toString().split('.').first,
          spis: _server.fetch(),
          snippets: _snippet.fetch(),
          keys: _privateKey.fetch(),
          dockerHosts: _dockerHosts.fetchAll(),
          settings: _setting.toJson(),
        ),
      ),
    );
    final path = '${(await docDir).path}/srvbox_bak.json';
    await File(path).writeAsString(result);
    await shareFiles(context, [path]);
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
      final backup = await compute(_decode, raw);
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
              for (final s in backup.snippets) {
                _snippet.put(s);
              }
              for (final s in backup.spis) {
                _server.put(s);
              }
              for (final s in backup.keys) {
                _privateKey.put(s);
              }
              for (final k in backup.dockerHosts.keys) {
                _dockerHosts.put(k, backup.dockerHosts[k]!);
              }
              context.pop();
              showRoundDialog(
                context: context,
                title: Text(s.restore),
                child: Text(s.restoreSuccess),
                actions: [
                  TextButton(
                    onPressed: () => rebuildAll(context),
                    child: Text(s.restart),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(s.cancel),
                  ),
                ],
              );
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

Backup _decode(String raw) {
  final decrypted = _diyDecrypt(raw);
  return Backup.fromJson(json.decode(decrypted));
}

String _diyEncrtpt(String raw) =>
    json.encode(raw.codeUnits.map((e) => e * 2 + 1).toList(growable: false));
String _diyDecrypt(String raw) {
  final list = json.decode(raw);
  final sb = StringBuffer();
  for (final e in list) {
    sb.writeCharCode((e - 1) ~/ 2);
  }
  return sb.toString();
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/res/path.dart';

import '../../core/extension/colorx.dart';
import '../../core/utils/misc.dart';
import '../../core/utils/ui.dart';
import '../../data/model/app/backup.dart';
import '../../data/res/color.dart';
import '../../data/res/ui.dart';
import '../../data/store/docker.dart';
import '../../data/store/private_key.dart';
import '../../data/store/server.dart';
import '../../data/store/snippet.dart';
import '../../locator.dart';

const backupFormatVersion = 1;

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final _server = locator<ServerStore>();
  final _snippet = locator<SnippetStore>();
  final _privateKey = locator<PrivateKeyStore>();
  final _dockerHosts = locator<DockerStore>();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(
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
        const SizedBox(height: 107),
        _buildCard(s.restore, Icons.download, media, () async {
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
        }),
        height13,
        const SizedBox(
          width: 37,
          child: Divider(),
        ),
        height13,
        _buildCard(
          s.backup,
          Icons.file_upload,
          media,
          () async {
            final result = _diyEncrtpt(
              json.encode(
                Backup(
                  backupFormatVersion,
                  DateTime.now().toString().split('.').first,
                  _server.fetch(),
                  _snippet.fetch(),
                  _privateKey.fetch(),
                  _dockerHosts.fetch(),
                ),
              ),
            );
            final path = '${(await docDir).path}/srvbox_bak.json';
            await File(path).writeAsString(result);
            await shareFiles(context, [path]);
          },
        )
      ],
    ));
  }

  Widget _buildCard(String text, IconData icon, MediaQueryData media,
      FutureOr Function() onTap) {
    final textColor = primaryColor.isBrightColor ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(37), color: primaryColor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: textColor,
              ),
              width7,
              Text(text, style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
    );
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
                _dockerHosts.setDockerHost(k, backup.dockerHosts[k]!);
              }
              context.pop();
              showRoundDialog(
                context: context,
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

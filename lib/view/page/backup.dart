import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toolbox/core/extension/colorx.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/data/store/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';

const backupFormatVersion = 1;

class BackupPage extends StatelessWidget {
  BackupPage({Key? key}) : super(key: key);

  final setting = locator<SettingStore>();
  final server = locator<ServerStore>();
  final snippet = locator<SnippetStore>();
  final privateKey = locator<PrivateKeyStore>();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.importAndExport, style: size18),
      ),
      body: Center(
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
          const SizedBox(
            height: 107,
          ),
          _buildCard(s.restore, Icons.download, media,
              () => _showImportDialog(context, s)),
          const SizedBox(height: 7),
          const Divider(),
          const SizedBox(height: 7),
          _buildCard(s.backup, Icons.file_upload, media,
              () => _showExportDialog(context, s))
        ],
      )),
    );
  }

  Widget _buildCard(String text, IconData icon, MediaQueryData media,
      FutureOr Function() onTap) {
    final priColor = primaryColor;
    final textColor = priColor.isBrightColor ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(37), color: priColor),
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
              const SizedBox(width: 7),
              Text(text, style: TextStyle(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context, S s) async {
    final exportFieldController = TextEditingController()
      ..text = _diyEncrtpt(json.encode(Backup(
        backupFormatVersion,
        DateTime.now().toString().split('.').first,
        server.fetch(),
        snippet.fetch(),
        privateKey.fetch(),
        setting.primaryColor.fetch() ?? Colors.pinkAccent.value,
        setting.serverStatusUpdateInterval.fetch() ?? 2,
        setting.launchPage.fetch() ?? 0,
      )));
    await showRoundDialog(
        context,
        s.export,
        TextField(
          decoration: const InputDecoration(
            labelText: 'JSON',
          ),
          maxLines: 7,
          controller: exportFieldController,
        ),
        [
          TextButton(
            child: Text(s.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: exportFieldController.text));
              Navigator.pop(context);
            },
          ),
        ]);
  }

  Future<void> _showImportDialog(BuildContext context, S s) async {
    final importFieldController = TextEditingController();
    await showRoundDialog(
        context,
        s.import,
        TextField(
          decoration: const InputDecoration(
            labelText: 'JSON',
          ),
          maxLines: 3,
          controller: importFieldController,
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.cancel)),
          TextButton(
            onPressed: () async =>
                await _import(importFieldController.text.trim(), context, s),
            child: const Text('GO'),
          )
        ]);
  }

  Future<void> _import(String text, BuildContext context, S s) async {
    if (text.isEmpty) {
      showSnackBar(context, Text(s.fieldMustNotEmpty));
      return;
    }
    _importBackup(text, context, s);
    Navigator.of(context).pop();
  }

  Future<void> _importBackup(String raw, BuildContext context, S s) async {
    try {
      final backup = await compute(_decode, raw);
      if (backupFormatVersion != backup.version) {
        showSnackBar(context, Text(s.backupVersionNotMatch));
        return;
      }

      await showRoundDialog(
          context, s.attention, Text(s.restoreSureWithDate(backup.date)), [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () async {
            for (final s in backup.snippets) {
              snippet.put(s);
            }
            for (final s in backup.spis) {
              server.put(s);
            }
            for (final s in backup.keys) {
              privateKey.put(s);
            }
            setting.primaryColor.put(backup.primaryColor);
            setting.serverStatusUpdateInterval
                .put(backup.serverStatusUpdateInterval);
            setting.launchPage.put(backup.launchPage);
            Navigator.of(context).pop();
            showSnackBar(context, Text(s.restoreSuccess));
          },
          child: Text(s.ok),
        ),
      ]);
    } catch (e) {
      showSnackBar(context, Text(s.invalidJson));
      return;
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

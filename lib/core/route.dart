import 'package:flutter/material.dart';
import 'package:toolbox/core/analysis.dart';
import 'package:toolbox/data/model/server/private_key_info.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/view/page/backup.dart';
import 'package:toolbox/view/page/docker.dart';
import 'package:toolbox/view/page/home.dart';
import 'package:toolbox/view/page/ping.dart';
import 'package:toolbox/view/page/private_key/edit.dart';
import 'package:toolbox/view/page/private_key/list.dart';
import 'package:toolbox/view/page/server/detail.dart';
import 'package:toolbox/view/page/setting/android.dart';
import 'package:toolbox/view/page/setting/ios.dart';
import 'package:toolbox/view/page/snippet/result.dart';
import 'package:toolbox/view/page/ssh/page.dart';
import 'package:toolbox/view/page/setting/virt_key.dart';
import 'package:toolbox/view/page/storage/local.dart';

import '../data/model/server/snippet.dart';
import '../view/page/debug.dart';
import '../view/page/editor.dart';
import '../view/page/full_screen.dart';
import '../view/page/process.dart';
import '../view/page/server/edit.dart';
import '../view/page/server/tab.dart';
import '../view/page/setting/entry.dart';
import '../view/page/setting/srv_detail_seq.dart';
import '../view/page/setting/srv_seq.dart';
import '../view/page/snippet/edit.dart';
import '../view/page/snippet/list.dart';
import '../view/page/storage/sftp.dart';
import '../view/page/storage/sftp_mission.dart';

class AppRoute {
  final Widget page;
  final String title;

  AppRoute(this.page, this.title);

  Future<T?> go<T>(BuildContext context) {
    Analysis.recordView(title);
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<T?> checkGo<T>({
    required BuildContext context,
    required bool Function() check,
  }) {
    if (check()) {
      return go(context);
    }
    return Future.value(null);
  }

  static AppRoute serverDetail({Key? key, required ServerPrivateInfo spi}) {
    return AppRoute(ServerDetailPage(key: key, spi: spi), 'server_detail');
  }

  static AppRoute serverTab({Key? key}) {
    return AppRoute(ServerPage(key: key), 'server_tab');
  }

  static AppRoute serverEdit({Key? key, ServerPrivateInfo? spi}) {
    return AppRoute(
      ServerEditPage(spi: spi),
      'server_${spi == null ? 'add' : 'edit'}',
    );
  }

  static AppRoute keyEdit({Key? key, PrivateKeyInfo? pki}) {
    return AppRoute(
      PrivateKeyEditPage(pki: pki),
      'key_${pki == null ? 'add' : 'edit'}',
    );
  }

  static AppRoute keyList({Key? key}) {
    return AppRoute(PrivateKeysListPage(key: key), 'key_detail');
  }

  static AppRoute snippetEdit({Key? key, Snippet? snippet}) {
    return AppRoute(
      SnippetEditPage(snippet: snippet),
      'snippet_${snippet == null ? 'add' : 'edit'}',
    );
  }

  static AppRoute snippetList({Key? key}) {
    return AppRoute(SnippetListPage(key: key), 'snippet_detail');
  }

  static AppRoute ssh({
    Key? key,
    required ServerPrivateInfo spi,
    String? initCmd,
  }) {
    return AppRoute(
      SSHPage(
        key: key,
        spi: spi,
        initCmd: initCmd,
      ),
      'ssh_term',
    );
  }

  static AppRoute sshVirtKeySetting({Key? key}) {
    return AppRoute(SSHVirtKeySettingPage(key: key), 'ssh_virt_key_setting');
  }

  static AppRoute localStorage(
      {Key? key, bool isPickFile = false, String? initDir}) {
    return AppRoute(
        LocalStoragePage(
          key: key,
          isPickFile: isPickFile,
          initDir: initDir,
        ),
        'local_storage');
  }

  static AppRoute sftpMission({Key? key}) {
    return AppRoute(SftpMissionPage(key: key), 'sftp_mission');
  }

  static AppRoute sftp(
      {Key? key,
      required ServerPrivateInfo spi,
      String? initPath,
      bool isSelect = false}) {
    return AppRoute(
        SftpPage(
          key: key,
          spi: spi,
          initPath: initPath,
          isSelect: isSelect,
        ),
        'sftp');
  }

  static AppRoute backup({Key? key}) {
    return AppRoute(BackupPage(key: key), 'backup');
  }

  static AppRoute debug({Key? key}) {
    return AppRoute(DebugPage(key: key), 'debug');
  }

  static AppRoute docker({Key? key, required ServerPrivateInfo spi}) {
    return AppRoute(DockerManagePage(key: key, spi: spi), 'docker');
  }

  /// - Pop true if the text is changed & [path] is not null
  /// - Pop text if [path] is null
  static AppRoute editor({
    Key? key,
    String? path,
    String? text,
    String? langCode,
    String? title,
  }) {
    return AppRoute(
        EditorPage(
          key: key,
          path: path,
          text: text,
          langCode: langCode,
          title: title,
        ),
        'editor');
  }

  static AppRoute fullscreen({Key? key}) {
    return AppRoute(FullScreenPage(key: key), 'fullscreen');
  }

  static AppRoute home({Key? key}) {
    return AppRoute(HomePage(key: key), 'home');
  }

  static AppRoute ping({Key? key}) {
    return AppRoute(PingPage(key: key), 'ping');
  }

  static AppRoute process({Key? key, required ServerPrivateInfo spi}) {
    return AppRoute(ProcessPage(key: key, spi: spi), 'process');
  }

  static AppRoute settings({Key? key}) {
    return AppRoute(SettingPage(key: key), 'setting');
  }

  static AppRoute serverOrder({Key? key}) {
    return AppRoute(ServerOrderPage(key: key), 'server_order');
  }

  static AppRoute serverDetailOrder({Key? key}) {
    return AppRoute(ServerDetailOrderPage(key: key), 'server_detail_order');
  }

  static AppRoute iosSettings({Key? key}) {
    return AppRoute(IOSSettingsPage(key: key), 'ios_setting');
  }

  static AppRoute androidSettings({Key? key}) {
    return AppRoute(AndroidSettingsPage(key: key), 'android_setting');
  }

  static AppRoute snippetResult(
      {Key? key, required List<SnippetResult?> results}) {
    return AppRoute(
        SnippetResultPage(
          key: key,
          results: results,
        ),
        'snippet_result');
  }
}

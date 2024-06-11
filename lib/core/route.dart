import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/container.dart';
import 'package:server_box/view/page/home/home.dart';
import 'package:server_box/view/page/iperf.dart';
import 'package:server_box/view/page/ping.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/private_key/list.dart';
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/setting/platform/android.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/snippet/result.dart';
import 'package:server_box/view/page/ssh/page.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';
import 'package:server_box/view/page/storage/local.dart';

import '../data/model/server/snippet.dart';
import '../view/page/editor.dart';
import '../view/page/process.dart';
import '../view/page/server/edit.dart';
import '../view/page/server/tab.dart';
import '../view/page/setting/entry.dart';
import '../view/page/setting/seq/srv_detail_seq.dart';
import '../view/page/setting/seq/srv_seq.dart';
import '../view/page/snippet/edit.dart';
import '../view/page/snippet/list.dart';
import '../view/page/storage/sftp.dart';
import '../view/page/storage/sftp_mission.dart';

class AppRoutes {
  final Widget page;
  final String title;

  AppRoutes(this.page, this.title);

  Future<T?> go<T>(BuildContext context) {
    return Navigator.push<T>(
      context,
      Stores.setting.cupertinoRoute.fetch()
          ? CupertinoPageRoute(builder: (context) => page)
          : MaterialPageRoute(builder: (context) => page),
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

  static AppRoutes serverDetail({Key? key, required ServerPrivateInfo spi}) {
    return AppRoutes(ServerDetailPage(key: key, spi: spi), 'server_detail');
  }

  static AppRoutes serverTab({Key? key}) {
    return AppRoutes(ServerPage(key: key), 'server_tab');
  }

  static AppRoutes serverEdit({Key? key, ServerPrivateInfo? spi}) {
    return AppRoutes(
      ServerEditPage(spi: spi),
      'server_${spi == null ? 'add' : 'edit'}',
    );
  }

  static AppRoutes keyEdit({Key? key, PrivateKeyInfo? pki}) {
    return AppRoutes(
      PrivateKeyEditPage(pki: pki),
      'key_${pki == null ? 'add' : 'edit'}',
    );
  }

  static AppRoutes keyList({Key? key}) {
    return AppRoutes(PrivateKeysListPage(key: key), 'key_detail');
  }

  static AppRoutes snippetEdit({Key? key, Snippet? snippet}) {
    return AppRoutes(
      SnippetEditPage(snippet: snippet),
      'snippet_${snippet == null ? 'add' : 'edit'}',
    );
  }

  static AppRoutes snippetList({Key? key}) {
    return AppRoutes(SnippetListPage(key: key), 'snippet_detail');
  }

  static AppRoutes ssh({
    Key? key,
    required ServerPrivateInfo spi,
    String? initCmd,
    Snippet? initSnippet,
  }) {
    return AppRoutes(
      SSHPage(
        key: key,
        spi: spi,
        initCmd: initCmd,
        initSnippet: initSnippet,
      ),
      'ssh_term',
    );
  }

  static AppRoutes sshVirtKeySetting({Key? key}) {
    return AppRoutes(SSHVirtKeySettingPage(key: key), 'ssh_virt_key_setting');
  }

  static AppRoutes localStorage(
      {Key? key, bool isPickFile = false, String? initDir}) {
    return AppRoutes(
        LocalStoragePage(
          key: key,
          isPickFile: isPickFile,
          initDir: initDir,
        ),
        'local_storage');
  }

  static AppRoutes sftpMission({Key? key}) {
    return AppRoutes(SftpMissionPage(key: key), 'sftp_mission');
  }

  static AppRoutes sftp(
      {Key? key,
      required ServerPrivateInfo spi,
      String? initPath,
      bool isSelect = false}) {
    return AppRoutes(
        SftpPage(
          key: key,
          spi: spi,
          initPath: initPath,
          isSelect: isSelect,
        ),
        'sftp');
  }

  static AppRoutes backup({Key? key}) {
    return AppRoutes(BackupPage(key: key), 'backup');
  }

  static AppRoutes debug({Key? key}) {
    return AppRoutes(
      DebugPage(
        key: key,
        args: DebugPageArgs(
          notifier: Pros.debug.widgets,
          onClear: Pros.debug.clear,
          title: 'Logs(${BuildData.build})',
        ),
      ),
      'debug',
    );
  }

  static AppRoutes docker({Key? key, required ServerPrivateInfo spi}) {
    return AppRoutes(ContainerPage(key: key, spi: spi), 'docker');
  }

  /// - Pop true if the text is changed & [path] is not null
  /// - Pop text if [path] is null
  static AppRoutes editor({
    Key? key,
    String? path,
    String? text,
    String? langCode,
    String? title,
  }) {
    return AppRoutes(
        EditorPage(
          key: key,
          path: path,
          text: text,
          langCode: langCode,
          title: title,
        ),
        'editor');
  }

  // static AppRoutes fullscreen({Key? key}) {
  //   return AppRoutes(FullScreenPage(key: key), 'fullscreen');
  // }

  static AppRoutes home({Key? key}) {
    return AppRoutes(HomePage(key: key), 'home');
  }

  static AppRoutes ping({Key? key}) {
    return AppRoutes(PingPage(key: key), 'ping');
  }

  static AppRoutes process({Key? key, required ServerPrivateInfo spi}) {
    return AppRoutes(ProcessPage(key: key, spi: spi), 'process');
  }

  static AppRoutes settings({Key? key}) {
    return AppRoutes(SettingPage(key: key), 'setting');
  }

  static AppRoutes serverOrder({Key? key}) {
    return AppRoutes(ServerOrderPage(key: key), 'server_order');
  }

  static AppRoutes serverDetailOrder({Key? key}) {
    return AppRoutes(ServerDetailOrderPage(key: key), 'server_detail_order');
  }

  static AppRoutes iosSettings({Key? key}) {
    return AppRoutes(IOSSettingsPage(key: key), 'ios_setting');
  }

  static AppRoutes androidSettings({Key? key}) {
    return AppRoutes(AndroidSettingsPage(key: key), 'android_setting');
  }

  static AppRoutes snippetResult(
      {Key? key, required List<SnippetResult?> results}) {
    return AppRoutes(
        SnippetResultPage(
          key: key,
          results: results,
        ),
        'snippet_result');
  }

  static AppRoutes iperf({Key? key, required ServerPrivateInfo spi}) {
    return AppRoutes(IPerfPage(key: key, spi: spi), 'iperf');
  }

  static AppRoutes serverFuncBtnsOrder({Key? key}) {
    return AppRoutes(ServerFuncBtnsOrderPage(key: key), 'server_func_btns_seq');
  }

  static AppRoutes pve({Key? key, required ServerPrivateInfo spi}) {
    return AppRoutes(PvePage(key: key, spi: spi), 'pve');
  }

  static AppRoutes kvEditor({Key? key, required Map<String, String> data}) {
    return AppRoutes(KvEditor(key: key, data: data), 'kv_editor');
  }
}

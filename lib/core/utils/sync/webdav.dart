import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/model/app/error.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/data/res/store.dart';
// ignore: implementation_imports
import 'package:webdav_client/src/client.dart';

abstract final class Webdav {
  static var _client = WebdavClient(
    url: Stores.setting.webdavUrl.fetch(),
    user: Stores.setting.webdavUser.fetch(),
    pwd: Stores.setting.webdavPwd.fetch(),
  );

  static Future<String?> test(String url, String user, String pwd) async {
    final client = WebdavClient(url: url, user: user, pwd: pwd);
    try {
      await client.ping();
      return null;
    } catch (e, s) {
      Loggers.app.warning('Webdav test failed', e, s);
      return e.toString();
    }
  }

  static Future<WebdavErr?> upload({
    required String relativePath,
    String? localPath,
  }) async {
    try {
      await _client.writeFile(
        localPath ?? '${await Paths.doc}/$relativePath',
        relativePath,
      );
    } catch (e, s) {
      Loggers.app.warning('Webdav upload failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> delete(String relativePath) async {
    try {
      await _client.remove(relativePath);
    } catch (e, s) {
      Loggers.app.warning('Webdav delete failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> download({
    required String relativePath,
    String? localPath,
  }) async {
    try {
      await _client.readFile(
        relativePath,
        localPath ?? '${await Paths.doc}/$relativePath',
      );
    } catch (e, s) {
      Loggers.app.warning('Webdav download failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static void changeClient(String url, String user, String pwd) {
    _client = WebdavClient(url: url, user: user, pwd: pwd);
  }

  static Future<void> sync() async {
    try {
      final result = await download(relativePath: Paths.bakName);
      if (result != null) {
        Loggers.app.warning('Download backup failed: $result');
        return;
      }
    } catch (e, s) {
      Loggers.app.warning('Download backup failed', e, s);
    }
    final dlFile = await File(await Paths.bak).readAsString();
    final dlBak = await compute(Backup.fromJsonString, dlFile);
    final restore = await dlBak.restore();
    switch (restore) {
      case true:
        Loggers.app.info('Restore from iCloud (${dlBak.lastModTime}) success');
        break;
      case false:
        await Backup.backup();
        final uploadResult = await upload(relativePath: Paths.bakName);
        if (uploadResult != null) {
          Loggers.app.warning('Upload iCloud backup failed: $uploadResult');
        } else {
          Loggers.app.info('Upload iCloud backup success');
        }
        break;
      case null:
        Loggers.app.info('Skip iCloud sync');
        break;
    }
  }
}

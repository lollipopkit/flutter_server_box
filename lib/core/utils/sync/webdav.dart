import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/data/model/app/backup.dart';
import 'package:toolbox/data/model/app/error.dart';
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

  static final _logger = Logger('Webdav');

  static Future<String?> test(String url, String user, String pwd) async {
    final client = WebdavClient(url: url, user: user, pwd: pwd);
    try {
      await client.ping();
      return null;
    } catch (e, s) {
      _logger.warning('Test failed', e, s);
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
      _logger.warning('Upload $relativePath failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> delete(String relativePath) async {
    try {
      await _client.remove(relativePath);
    } catch (e, s) {
      _logger.warning('Delete $relativePath failed', e, s);
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
    } catch (e) {
      _logger.warning('Download $relativePath failed');
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static void changeClient(String url, String user, String pwd) {
    _client = WebdavClient(url: url, user: user, pwd: pwd);
  }

  static Future<void> sync() async {
    final result = await download(relativePath: Paths.bakName);
    if (result != null) {
      await backup();
      return;
    }
    final dlFile = await compute(
      (message) async {
        try {
          final file = await File(message).readAsString();
          final bak = Backup.fromJsonString(file);
          return bak;
        } catch (_) {
          return null;
        }
      },
      await Paths.bak,
    );
    if (dlFile == null) {
      await backup();
      return;
    }
    final restore = await dlFile.restore();
    switch (restore) {
      case true:
        _logger.info('Restore from ${dlFile.lastModTime} success');
        break;
      case false:
        await backup();
        break;
      case null:
        _logger.info('Skip sync');
        break;
    }
  }

  /// Create a local backup and upload it to WebDAV
  static Future<void> backup() async {
    await Backup.backup();
    final uploadResult = await upload(relativePath: Paths.bakName);
    if (uploadResult != null) {
      _logger.warning('Upload failed: $uploadResult');
    } else {
      _logger.info('Upload success');
    }
  }
}

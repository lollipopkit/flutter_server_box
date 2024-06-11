import 'dart:io';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:logging/logging.dart';
import 'package:server_box/data/model/app/backup.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:webdav_client/webdav_client.dart';

abstract final class Webdav {
  /// Some WebDAV provider only support non-root path
  static const _prefix = 'srvbox/';

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
        localPath ?? '${Paths.doc}/$relativePath',
        _prefix + relativePath,
      );
    } catch (e, s) {
      _logger.warning('Upload $relativePath failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> delete(String relativePath) async {
    try {
      await _client.remove(_prefix + relativePath);
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
        _prefix + relativePath,
        localPath ?? '${Paths.doc}/$relativePath',
      );
    } catch (e) {
      _logger.warning('Download $relativePath failed');
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<List<String>> list() async {
    try {
      final list = await _client.readDir(_prefix);
      final names = <String>[];
      for (final item in list) {
        if ((item.isDir ?? true) || item.name == null) continue;
        names.add(item.name!);
      }
      return names;
    } catch (e, s) {
      _logger.warning('List failed', e, s);
      return [];
    }
  }

  static void changeClient(String url, String user, String pwd) {
    _client = WebdavClient(url: url, user: user, pwd: pwd);
    Stores.setting.webdavUrl.put(url);
    Stores.setting.webdavUser.put(user);
    Stores.setting.webdavPwd.put(pwd);
  }

  static Future<void> sync() async {
    final result = await download(relativePath: Miscs.bakFileName);
    if (result != null) {
      await backup();
      return;
    }

    try {
      final dlFile = await File(Paths.bak).readAsString();
      final dlBak = await Computer.shared.start(Backup.fromJsonString, dlFile);
      await dlBak.restore();
    } catch (e) {
      _logger.warning('Restore failed: $e');
    }

    await backup();
  }

  /// Create a local backup and upload it to WebDAV
  static Future<void> backup() async {
    await Backup.backup();
    final uploadResult = await upload(relativePath: Miscs.bakFileName);
    if (uploadResult != null) {
      _logger.warning('Upload failed: $uploadResult');
    } else {
      _logger.info('Upload success');
    }
  }
}

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/platform/path.dart';

class Paths {
  const Paths._();

  static String? _docDir;
  static String? _sftpDir;
  static String? _fontDir;

  static Future<String> get doc async {
    if (_docDir != null) {
      return _docDir!;
    }
    if (isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        _docDir = dir.path;
        return dir.path;
      }
      // fallthrough to getApplicationDocumentsDirectory
    }
    final dir = await getApplicationDocumentsDirectory();
    _docDir = dir.path;
    return dir.path;
  }

  static Future<String> get sftp async {
    if (_sftpDir != null) {
      return _sftpDir!;
    }
    _sftpDir = '${await doc}/sftp';
    final dir = Directory(_sftpDir!);
    await dir.create(recursive: true);
    return _sftpDir!;
  }

  static Future<String> get font async {
    if (_fontDir != null) {
      return _fontDir!;
    }
    _fontDir = '${await doc}/font';
    final dir = Directory(_fontDir!);
    await dir.create(recursive: true);
    return _fontDir!;
  }

  static Future<String> get bak async => '${await doc}/srvbox_bak.json';

  static Future<String> get dl async => joinPath(await doc, 'dl');
}

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:toolbox/core/utils/platform.dart';

String? _docDir;
String? _sftpDir;
String? _fontDir;

Future<String> get docDir async {
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

Future<String> get sftpDir async {
  if (_sftpDir != null) {
    return _sftpDir!;
  }
  _sftpDir = '${await docDir}/sftp';
  final dir = Directory(_sftpDir!);
  await dir.create(recursive: true);
  return _sftpDir!;
}

Future<String> get fontDir async {
  if (_fontDir != null) {
    return _fontDir!;
  }
  _fontDir = '${await docDir}/font';
  final dir = Directory(_fontDir!);
  await dir.create(recursive: true);
  return _fontDir!;
}

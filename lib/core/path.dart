import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> get sftpDownloadDir async {
  final docDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${docDir.path}/sftp');
  if (!dir.existsSync()) {
    dir.createSync();
  }
  return dir;
}

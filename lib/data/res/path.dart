import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> get docDir async => await getApplicationDocumentsDirectory();

Future<Directory> get sftpDownloadDir async {
  final dir = Directory('${(await docDir).path}/sftp');
  return dir.create(recursive: true);
}

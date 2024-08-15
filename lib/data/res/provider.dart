import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/provider/snippet.dart';

abstract final class Pros {
  static final key = PrivateKeyProvider();
  static final sftp = SftpProvider();
  static final snippet = SnippetProvider();

  static void reload() {
    key.load();
    ServerProvider.load();
    snippet.load();
  }
}

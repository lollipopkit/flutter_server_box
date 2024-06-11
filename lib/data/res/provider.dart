import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/provider/app.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/provider/snippet.dart';

abstract final class Pros {
  static final app = AppProvider();
  static final debug = DebugProvider(maxLines: 177);
  static final key = PrivateKeyProvider();
  static final server = ServerProvider();
  static final sftp = SftpProvider();
  static final snippet = SnippetProvider();

  static void reload() {
    key.load();
    server.load();
    snippet.load();
  }
}

import 'package:fl_lib/fl_lib.dart';
import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp.dart';
import 'package:toolbox/data/provider/snippet.dart';

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

import 'package:toolbox/data/provider/app.dart';
import 'package:toolbox/data/provider/debug.dart';
import 'package:toolbox/data/provider/docker.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/locator.dart';

class Pros {
  const Pros._();

  static final app = locator<AppProvider>();
  static final debug = locator<DebugProvider>();
  static final docker = locator<DockerProvider>();
  static final key = locator<PrivateKeyProvider>();
  static final server = locator<ServerProvider>();
  static final sftp = locator<SftpProvider>();
  static final snippet = locator<SnippetProvider>();

  static void reload() {
    key.load();
    server.load();
    snippet.load();
  }
}

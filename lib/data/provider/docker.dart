import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/docker/ps.dart';

final _dockerNotFound = RegExp(r'command not found|Unknown command');
final _versionReg = RegExp(r'(Version:)\s+([0-9]+\.[0-9]+\.[0-9]+)');
final _editionReg = RegExp(r'(Client:)\s+(.+-.+)');
final _userIdReg = RegExp(r'.+:(\d+:\d+):.+');

class DockerProvider extends BusyProvider {
  SSHClient? client;
  String? userName;
  List<DockerPsItem>? items;
  String? version;
  String? edition;
  String? error;

  void init(SSHClient client, String userName) {
    this.client = client;
    this.userName = userName;
  }

  void clear() {
    client = null;
    userName = null;
    error = null;
    items = null;
    version = null;
    edition = null;
  }

  Future<void> refresh() async {
    if (client == null) {
      error = 'no client';
      notifyListeners();
      return;
    }

    final verRaw = await client!.run('docker version'.withLangExport).string;
    if (verRaw.contains(_dockerNotFound)) {
      error = 'docker not found';
      notifyListeners();
      return;
    }

    version = _versionReg.firstMatch(verRaw)?.group(2);
    edition = _editionReg.firstMatch(verRaw)?.group(2);

    final passwd = await client!.run('cat /etc/passwd | grep $userName').string;
    final userId = _userIdReg.firstMatch(passwd)?.group(1)?.split(':').first;

    try {
      final cmd = 'docker ps -a'.withLangExport;
      final raw = await () async {
        final raw = await client!.run(cmd).string;
        if (raw.contains('permission denied')) {
          return await client!
              .run(
                  'export DOCKER_HOST=unix:///run/user/${userId ?? 1000}/docker.sock && $cmd')
              .string;
        }
        return raw;
      }();
      final lines = raw.split('\n');
      lines.removeAt(0);
      lines.removeWhere((element) => element.isEmpty);
      items = lines.map((e) => DockerPsItem.fromRawString(e)).toList();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _do(String id, String cmd) async {
    setBusyState();
    if (client == null) {
      error = 'no client';
      setBusyState(false);
      return false;
    }
    final result = await client!.run(cmd).string;
    await refresh();
    setBusyState(false);
    return result.contains(id);
  }

  Future<bool> stop(String id) async => await _do(id, 'docker stop $id');

  Future<bool> start(String id) async => await _do(id, 'docker start $id');

  Future<bool> delete(String id) async => await _do(id, 'docker rm $id');
}

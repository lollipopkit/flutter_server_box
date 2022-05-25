import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/docker/ps.dart';

final dockerNotFound = RegExp(r'command not found|Unknown command');

class DockerProvider extends BusyProvider {
  SSHClient? client;
  List<DockerPsItem>? items;
  String? version;
  String? edition;
  String? error;

  void init(SSHClient client) => this.client = client;

  void clear() {
    client = null;
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
    if (verRaw.contains(dockerNotFound)) {
      error = 'docker not found';
      notifyListeners();
      return;
    }
    final verSplit = verRaw.split('\n');
    if (verSplit.length < 3) {
      error = 'invalid version';
      notifyListeners();
      return;
    } else {
      try {
        version = verSplit[1].split(' ').last;
        edition = verSplit[0].split(': ')[1];
      } catch (e) {
        error = e.toString();
        return;
      }
    }

    final raw = await client!.run('docker ps -a'.withLangExport).string;
    final lines = raw.split('\n');
    lines.removeAt(0);
    lines.removeWhere((element) => element.isEmpty);

    try {
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

import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/docker/ps.dart';

class DockerProvider extends BusyProvider {
  SSHClient? client;
  List<DockerPsItem>? running;
  String? version;
  String? edition;
  String? error;

  void init(SSHClient client) => this.client = client;

  void clear() {
    client = null;
    error = null;
    running = null;
    version = null;
    edition = null;
  }

  Future<void> refresh() async {
    if (client == null) {
      error = 'no client';
      notifyListeners();
      return;
    }

    final verRaw = await client!.run('docker version').string;
    final verSplit = verRaw.split('\n');
    if (verSplit.length < 3) {
      error = 'invalid version';
      notifyListeners();
    } else {
      version = verSplit[1].split(' ').last;
      edition = verSplit[0].split(': ')[1];
    }

    final raw = await client!.run('docker ps -a').string;
    if (raw.contains('command not found')) {
      error = 'docker not found';
      notifyListeners();
      return;
    }
    final lines = raw.split('\n');
    lines.removeAt(0);
    lines.removeWhere((element) => element.isEmpty);
    running = lines.map((e) => DockerPsItem.fromRawString(e)).toList();
    notifyListeners();
  }

  Future<bool> stop(String id) async {
    setBusyState();
    if (client == null) {
      error = 'no client';
      setBusyState(false);
      return false;
    }
    final result = await client!.run('docker stop $id').string;
    await refresh();
    setBusyState(false);
    return result.contains(id);
  }

  Future<bool> start(String id) async {
    setBusyState();
    if (client == null) {
      error = 'no client';
      setBusyState(false);
      return false;
    }
    final result = await client!.run('docker start $id').string;
    await refresh();
    setBusyState(false);
    return result.contains(id);
  }

  Future<bool> delete(String id) async {
    setBusyState();
    if (client == null) {
      error = 'no client';
      setBusyState(false);
      return false;
    }
    final result = await client!.run('docker rm $id').string;
    await refresh();
    setBusyState(false);
    return result.contains(id);
  }
}

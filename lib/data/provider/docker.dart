import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/docker/ps.dart';
import 'package:toolbox/data/res/error.dart';
import 'package:toolbox/data/store/docker.dart';
import 'package:toolbox/locator.dart';

final _dockerNotFound = RegExp(r'command not found|Unknown command');
final _versionReg = RegExp(r'(Version:)\s+([0-9]+\.[0-9]+\.[0-9]+)');
final _editionReg = RegExp(r'(Client:)\s+(.+-.+)');
final _dockerPrefixReg = RegExp(r'(sudo )?docker ');

const _dockerPS = 'docker ps -a';

final _logger = Logger('DockerProvider');

class DockerProvider extends BusyProvider {
  SSHClient? client;
  String? userName;
  List<DockerPsItem>? items;
  String? version;
  String? edition;
  DockerErr? error;
  PwdRequestFunc? onPwdReq;
  String? hostId;
  String? runLog;
  bool isRequestingPwd = false;

  void init(SSHClient client, String userName, PwdRequestFunc onPwdReq,
      String hostId) {
    this.client = client;
    this.userName = userName;
    this.onPwdReq = onPwdReq;
    this.hostId = hostId;
  }

  void clear() {
    client = userName = error = items = version = edition = onPwdReq = null;
    isRequestingPwd = false;
    hostId = runLog = null;
  }

  Future<void> refresh() async {
    final verRaw = await client!.run('docker version'.withLangExport).string;
    if (verRaw.contains(_dockerNotFound)) {
      error = DockerErr(type: DockerErrType.notInstalled);
      notifyListeners();
      return;
    }

    try {
      version = _versionReg.firstMatch(verRaw)?.group(2);
      edition = _editionReg.firstMatch(verRaw)?.group(2);
    } catch (e) {
      rethrow;
    }

    try {
      // judge whether to use DOCKER_HOST / sudo
      final dockerHost = locator<DockerStore>().getDockerHost(hostId!);
      final cmd = () {
        if (dockerHost == null || dockerHost.isEmpty) {
          return 'sudo -S $_dockerPS'.withLangExport;
        }
        return 'export DOCKER_HOST=$dockerHost && $_dockerPS'.withLangExport;
      }();

      // run docker ps
      var raw = '';
      await client!.exec(
        cmd,
        onStderr: _onPwd,
        onStdout: (data, _) => raw = '$raw$data',
      );

      // parse result
      final lines = raw.split('\n');
      lines.removeAt(0);
      lines.removeWhere((element) => element.isEmpty);
      items = lines.map((e) => DockerPsItem.fromRawString(e)).toList();
    } catch (e) {
      error = DockerErr(type: DockerErrType.unknown, message: e.toString());
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _onPwd(String event, StreamSink<Uint8List> stdin) async {
    if (isRequestingPwd) return;
    isRequestingPwd = true;
    if (event.contains('[sudo] password for ')) {
      _logger.info('sudo password request for $userName');
      final pwd = await onPwdReq!();
      if (pwd.isEmpty) {
        _logger.info('sudo password request cancelled');
        return;
      }
      stdin.add('$pwd\n'.uint8List);
    }
    isRequestingPwd = false;
  }

  Future<DockerErr?> stop(String id) async => await run('docker stop $id');

  Future<DockerErr?> start(String id) async => await run('docker start $id');

  Future<DockerErr?> delete(String id) async => await run('docker rm $id');

  Future<DockerErr?> run(String cmd) async {
    if (!cmd.startsWith(_dockerPrefixReg)) {
      return DockerErr(type: DockerErrType.cmdNoPrefix);
    }
    setBusyState();

    final errs = <String>[];
    final code = await client!.exec(
      _wrapHost(cmd),
      onStderr: _onPwd,
      onStdout: (data, _) {
        runLog = '$runLog$data';
        notifyListeners();
      },
    );

    runLog = null;

    if (code != 0) {
      setBusyState(false);
      return DockerErr(type: DockerErrType.unknown, message: errs.join('\n'));
    }
    await refresh();
    setBusyState(false);
    return null;
  }

  String _wrapHost(String cmd) {
    final dockerHost = locator<DockerStore>().getDockerHost(hostId!);
    if (dockerHost == null || dockerHost.isEmpty) {
      return 'sudo $cmd';
    }
    return 'export DOCKER_HOST=$dockerHost && $cmd';
  }
}

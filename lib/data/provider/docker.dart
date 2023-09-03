import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/app/shell_func.dart';
import 'package:toolbox/data/model/docker/image.dart';
import 'package:toolbox/data/model/docker/ps.dart';
import 'package:toolbox/data/model/app/error.dart';
import 'package:toolbox/data/store/docker.dart';
import 'package:toolbox/locator.dart';

import '../res/server_cmd.dart';

final _dockerNotFound = RegExp(r'command not found|Unknown command');
final _versionReg = RegExp(r'(Version:)\s+([0-9]+\.[0-9]+\.[0-9]+)');
// eg: `Docker Engine - Community`
final _editionReg = RegExp(r'Docker Engine - [a-zA-Z]+');
final _dockerPrefixReg = RegExp(r'(sudo )?docker ');

final _logger = Logger('DOCKER');

class DockerProvider extends ChangeNotifier {
  final _dockerStore = locator<DockerStore>();

  SSHClient? client;
  String? userName;
  List<DockerPsItem>? items;
  List<DockerImage>? images;
  String? version;
  String? edition;
  DockerErr? error;
  PwdRequestFunc? onPwdReq;
  String? hostId;
  String? runLog;
  bool isRequestingPwd = false;

  void init(
    SSHClient client,
    String userName,
    PwdRequestFunc onPwdReq,
    String hostId,
  ) {
    this.client = client;
    this.userName = userName;
    this.onPwdReq = onPwdReq;
    this.hostId = hostId;
  }

  void clear() {
    client = userName = error = items = version = edition = onPwdReq = null;
    isRequestingPwd = false;
    hostId = runLog = images = null;
  }

  Future<void> refresh() async {
    var raw = '';
    await client!.exec(
      AppShellFuncType.docker.exec,
      onStderr: _onPwd,
      onStdout: (data, _) => raw = '$raw$data',
    );

    if (raw.contains(_dockerNotFound)) {
      error = DockerErr(type: DockerErrType.notInstalled);
      _logger.warning('Docker not installed: $raw');
      notifyListeners();
      return;
    }

    // Check result segments count
    final segments = raw.split(seperator);
    if (segments.length != DockerCmdType.values.length) {
      error = DockerErr(type: DockerErrType.segmentsNotMatch);
      _logger.warning('Docker segments not match: ${segments.length}');
      notifyListeners();
      return;
    }

    // Parse docker version
    final verRaw = DockerCmdType.version.find(segments);
    version = _versionReg.firstMatch(verRaw)?.group(2);
    edition = _editionReg.firstMatch(verRaw)?.group(0);

    // Parse docker ps
    final psRaw = DockerCmdType.ps.find(segments);
    try {
      final lines = psRaw.split('\n');
      lines.removeWhere((element) => element.isEmpty);
      if (lines.isNotEmpty) lines.removeAt(0);
      items = lines.map((e) => DockerPsItem.fromRawString(e)).toList();
    } catch (e) {
      error = DockerErr(
        type: DockerErrType.parsePsItem,
        message: '$psRaw\n-\n$e',
      );
      _logger.warning('Parse docker ps: $psRaw', e);
    } finally {
      notifyListeners();
    }

    // Parse docker images
    final imageRaw = DockerCmdType.images.find(segments);
    try {
      final imageLines = imageRaw.split('\n');
      imageLines.removeWhere((element) => element.isEmpty);
      if (imageLines.isNotEmpty) imageLines.removeAt(0);
      images = imageLines.map((e) => DockerImage.fromRawStr(e)).toList();
    } catch (e, trace) {
      error = DockerErr(
        type: DockerErrType.parseImages,
        message: '$imageRaw\n-\n$e',
      );
      _logger.warning('Parse docker images: $imageRaw', e, trace);
    } finally {
      notifyListeners();
    }

    // Parse docker stats
    // final statsRaw = DockerCmdType.stats.find(segments);
    // try {
    //   final statsLines = statsRaw.split('\n');
    //   statsLines.removeWhere((element) => element.isEmpty);
    //   if (statsLines.isNotEmpty) statsLines.removeAt(0);
    //   for (var item in items!) {
    //     final statsLine = statsLines.firstWhere(
    //       (element) => element.contains(item.containerId),
    //       orElse: () => '',
    //     );
    //     if (statsLine.isEmpty) continue;
    //     item.parseStats(statsLine);
    //   }
    // } catch (e, trace) {
    //   error = DockerErr(
    //     type: DockerErrType.parseStats,
    //     message: '$statsRaw\n-\n$e',
    //   );
    //   _logger.warning('Parse docker stats: $statsRaw', e, trace);
    // } finally {
    //   notifyListeners();
    // }
  }

  Future<void> _onPwd(String event, StreamSink<Uint8List> stdin) async {
    if (isRequestingPwd) return;
    isRequestingPwd = true;
    await onPwd(event, stdin, onPwdReq);
    isRequestingPwd = false;
  }

  Future<DockerErr?> stop(String id) async => await run('docker stop $id');

  Future<DockerErr?> start(String id) async => await run('docker start $id');

  Future<DockerErr?> delete(String id) async => await run('docker rm $id');

  Future<DockerErr?> restart(String id) async =>
      await run('docker restart $id');

  Future<DockerErr?> run(String cmd) async {
    if (!cmd.startsWith(_dockerPrefixReg)) {
      return DockerErr(type: DockerErrType.cmdNoPrefix);
    }

    runLog = '';
    final errs = <String>[];
    final code = await client!.exec(
      _wrap(cmd),
      onStderr: (data, sink) {
        _onPwd(data, sink);
        errs.add(data);
      },
      onStdout: (data, _) {
        runLog = '$runLog$data';
        notifyListeners();
      },
    );
    runLog = null;
    notifyListeners();

    if (code != 0) {
      return DockerErr(
        type: DockerErrType.unknown,
        message: errs.join('\n').trim(),
      );
    }
    await refresh();
    return null;
  }

  // judge whether to use DOCKER_HOST
  String _wrap(String cmd) {
    final dockerHost = _dockerStore.fetch(hostId!);
    if (dockerHost == null || dockerHost.isEmpty) {
      return cmd.withLangExport;
    }
    return 'export DOCKER_HOST=$dockerHost && $cmd'.withLangExport;
  }
}

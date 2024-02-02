import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/data/model/app/shell_func.dart';
import 'package:toolbox/data/model/container/image.dart';
import 'package:toolbox/data/model/container/ps.dart';
import 'package:toolbox/data/model/app/error.dart';
import 'package:toolbox/data/model/container/type.dart';
import 'package:toolbox/data/model/container/version.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/store.dart';

final _dockerNotFound = RegExp(r'command not found|Unknown command');

class ContainerProvider extends ChangeNotifier {
  SSHClient? client;
  String? userName;
  List<ContainerPs>? items;
  List<ContainerImg>? images;
  String? version;
  ContainerErr? error;
  String? hostId;
  String? runLog;
  BuildContext? context;
  ContainerType type;

  ContainerProvider({
    this.client,
    this.userName,
    this.hostId,
    this.context,
  }) : type = Stores.docker.getType(hostId) {
    refresh();
  }

  Future<void> setType(ContainerType type) async {
    this.type = type;
    Stores.docker.setType(hostId, type);
    error = runLog = items = images = version = null;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    var raw = '';
    await client?.execWithPwd(
      _wrap(ContainerCmdType.execAll(type)),
      context: context,
      onStdout: (data, _) => raw = '$raw$data',
    );

    if (raw.contains(_dockerNotFound)) {
      error = ContainerErr(type: ContainerErrType.notInstalled);
      notifyListeners();
      return;
    }

    // Check result segments count
    final segments = raw.split(seperator);
    if (segments.length != ContainerCmdType.values.length) {
      error = ContainerErr(
        type: ContainerErrType.segmentsNotMatch,
        message: 'Container segments: ${segments.length}',
      );
      Loggers.parse.warning('Container segments: ${segments.length}\n$raw');
      notifyListeners();
      return;
    }

    // Parse docker version
    final verRaw = ContainerCmdType.version.find(segments);
    try {
      final containerVersion = Containerd.fromRawJson(verRaw);
      version = containerVersion.client.version;
    } catch (e, trace) {
      error = ContainerErr(
        type: ContainerErrType.invalidVersion,
        message: '$e',
      );
      Loggers.parse.warning('Container version failed', e, trace);
    } finally {
      notifyListeners();
    }

    // Parse docker ps
    final psRaw = ContainerCmdType.ps.find(segments);

    final lines = psRaw.split('\n');
    lines.removeWhere((element) => element.isEmpty);
    items = lines.map((e) => ContainerPs.fromRawJson(e, type)).toList();

    // Parse docker images
    final imageRaw = ContainerCmdType.images.find(segments);
    try {
      final imgLines = imageRaw.split('\n');
      imgLines.removeWhere((element) => element.isEmpty);
      if (imgLines.isNotEmpty) imgLines.removeAt(0);
      images = imgLines.map((e) => ContainerImg.fromRawJson(e, type)).toList();
    } catch (e, trace) {
      error = ContainerErr(
        type: ContainerErrType.parseImages,
        message: '$e',
      );
      Loggers.parse.warning('Container images failed', e, trace);
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
    //     message: '$e',
    //   );
    //   _logger.warning('Parse docker stats: $statsRaw', e, trace);
    // } finally {
    //   notifyListeners();
    // }
  }

  Future<ContainerErr?> stop(String id) async => await run('stop $id');

  Future<ContainerErr?> start(String id) async => await run('start $id');

  Future<ContainerErr?> delete(String id, bool force) async {
    if (force) {
      return await run('rm -f $id');
    }
    return await run('rm $id');
  }

  Future<ContainerErr?> restart(String id) async => await run('restart $id');

  Future<ContainerErr?> run(String cmd) async {
    cmd = switch (type) {
      ContainerType.docker => 'docker $cmd',
      ContainerType.podman => 'podman $cmd',
    };

    runLog = '';
    final errs = <String>[];
    final code = await client?.execWithPwd(
      _wrap(cmd),
      context: context,
      onStdout: (data, _) {
        runLog = '$runLog$data';
        notifyListeners();
      },
      onStderr: (data, _) => errs.add(data),
    );
    runLog = null;
    notifyListeners();

    if (code != 0) {
      return ContainerErr(
        type: ContainerErrType.unknown,
        message: errs.join('\n').trim(),
      );
    }
    await refresh();
    return null;
  }

  /// wrap cmd with `docker host`
  String _wrap(String cmd) {
    final dockerHost = Stores.docker.fetch(hostId);
    cmd = 'export LANG=en_US.UTF-8 && $cmd';
    final noDockerHost = dockerHost?.isEmpty ?? true;
    if (!noDockerHost) {
      cmd = 'export DOCKER_HOST=$dockerHost && $cmd';
    }
    return cmd;
  }
}

const _jsonFmt = '--format "{{json .}}"';

enum ContainerCmdType {
  version,
  ps,
  //stats,
  images,
  ;

  String exec(ContainerType type) {
    final prefix = type.name;
    return switch (this) {
      ContainerCmdType.version => '$prefix version $_jsonFmt',
      ContainerCmdType.ps => '$prefix ps -a $_jsonFmt',
      // DockerCmdType.stats => '$prefix stats --no-stream';
      ContainerCmdType.images => '$prefix image ls $_jsonFmt',
    };
  }

  static String execAll(ContainerType type) =>
      values.map((e) => e.exec(type)).join(' && echo $seperator && ');
}

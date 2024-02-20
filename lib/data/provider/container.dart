import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/listx.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/data/model/app/shell_func.dart';
import 'package:toolbox/data/model/container/image.dart';
import 'package:toolbox/data/model/container/ps.dart';
import 'package:toolbox/data/model/app/error.dart';
import 'package:toolbox/data/model/container/type.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/core/extension/uint8list.dart';

final _dockerNotFound =
    RegExp(r"command not found|Unknown command|Command '\w+' not found");

class ContainerProvider extends ChangeNotifier {
  final SSHClient? client;
  final String userName;
  final String hostId;
  final BuildContext context;
  List<ContainerPs>? items;
  List<ContainerImg>? images;
  String? version;
  ContainerErr? error;
  String? runLog;
  ContainerType type;

  ContainerProvider({
    required this.client,
    required this.userName,
    required this.hostId,
    required this.context,
  }) : type = Stores.container.getType(hostId) {
    refresh();
  }

  Future<void> setType(ContainerType type) async {
    this.type = type;
    Stores.container.setType(type, hostId);
    error = runLog = items = images = version = null;
    notifyListeners();
    await refresh();
  }

  // Future<bool> _checkDockerInstalled(SSHClient client) async {
  //   final session = await client.execute("docker");
  //   await session.done;
  //   // debugPrint('docker code: ${session.exitCode}');
  //   return session.exitCode == 0;
  // }

  // String _removeSudoPrompts(String value) {
  //   final regex = RegExp(r"\[sudo\] password for \w+:");
  //   if (value.startsWith(regex)) {
  //     return value.replaceFirstMapped(regex, (match) => "");
  //   }
  //   return value;
  // }

  Future<bool> _requiresSudo() async {
    final psResult = await client?.run(_wrap(ContainerCmdType.ps.exec(type)));
    if (psResult == null) return true;
    if (psResult.string.toLowerCase().contains("permission denied")) {
      return true;
    }
    return false;
  }

  Future<void> refresh() async {
    var raw = '';

    final sudo =
        await _requiresSudo() && Stores.setting.containerTrySudo.fetch();
    final includeStats = Stores.setting.containerParseStat.fetch();

    final code = await client?.execWithPwd(
      _wrap(ContainerCmdType.execAll(
        type,
        sudo: sudo,
        includeStats: includeStats,
      )),
      context: context,
      onStdout: (data, _) => raw = '$raw$data',
    );

    /// Code 127 means command not found
    if (code == 127 || raw.contains(_dockerNotFound)) {
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

    // Parse version
    final verRaw = ContainerCmdType.version.find(segments);
    try {
      version = json.decode(verRaw)['Client']['Version'];
    } catch (e, trace) {
      error = ContainerErr(
        type: ContainerErrType.invalidVersion,
        message: '$e',
      );
      Loggers.parse.warning('Container version failed', e, trace);
    } finally {
      notifyListeners();
    }

    // Parse ps
    final psRaw = ContainerCmdType.ps.find(segments);
    try {
      final lines = psRaw.split('\n');
      lines.removeWhere((element) => element.isEmpty);
      items = lines.map((e) => ContainerPs.fromRawJson(e, type)).toList();
    } catch (e, trace) {
      error = ContainerErr(
        type: ContainerErrType.parsePs,
        message: '$e',
      );
      Loggers.parse.warning('Container ps failed', e, trace);
    } finally {
      notifyListeners();
    }

    // Parse images
    final imageRaw = ContainerCmdType.images.find(segments);
    try {
      final imgLines = imageRaw.split('\n');
      imgLines.removeWhere((element) => element.isEmpty);
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

    // Parse stats
    final statsRaw = ContainerCmdType.stats.find(segments);
    try {
      final statsLines = statsRaw.split('\n');
      statsLines.removeWhere((element) => element.isEmpty);
      for (var item in items!) {
        final id = item.id;
        if (id == null) continue;
        final statsLine = statsLines.firstWhereOrNull(
          /// Use 5 characters to match the container id, possibility of mismatch
          /// is very low.
          (element) => element.contains(id.substring(0, 5)),
        );
        if (statsLine == null) continue;
        item.parseStats(statsLine);
      }
    } catch (e, trace) {
      error = ContainerErr(
        type: ContainerErrType.parseStats,
        message: '$e',
      );
      Loggers.parse.warning('Parse docker stats: $statsRaw', e, trace);
    } finally {
      notifyListeners();
    }
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

  Future<ContainerErr?> run(String cmd, {bool autoRefresh = true}) async {
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
    if (autoRefresh) await refresh();
    return null;
  }

  /// wrap cmd with `docker host`
  String _wrap(String cmd) {
    final dockerHost = Stores.container.fetch(hostId);
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
  stats,
  images,
  ;

  String exec(
    ContainerType type, {
    bool sudo = false,
    bool includeStats = false,
  }) {
    final prefix = sudo ? 'sudo -S ${type.name}' : type.name;
    return switch (this) {
      ContainerCmdType.version => '$prefix version $_jsonFmt',
      ContainerCmdType.ps => '$prefix ps -a $_jsonFmt',
      ContainerCmdType.stats =>
        includeStats ? '$prefix stats --no-stream $_jsonFmt' : 'echo PASS',
      ContainerCmdType.images => '$prefix image ls $_jsonFmt',
    };
  }

  static String execAll(
    ContainerType type, {
    bool sudo = false,
    bool includeStats = false,
  }) {
    return ContainerCmdType.values
        .map((e) => e.exec(type, sudo: sudo))
        .join(' && echo $seperator && ');
  }
}

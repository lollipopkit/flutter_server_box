import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

part 'container.freezed.dart';
part 'container.g.dart';

final _dockerNotFound = RegExp(r"command not found|Unknown command|Command '\w+' not found");

@freezed
abstract class ContainerState with _$ContainerState {
  const factory ContainerState({
    @Default(null) List<ContainerPs>? items,
    @Default(null) List<ContainerImg>? images,
    @Default(null) String? version,
    @Default(null) ContainerErr? error,
    @Default(null) String? runLog,
    @Default(ContainerType.docker) ContainerType type,
    @Default(false) bool isBusy,
  }) = _ContainerState;
}

@riverpod
class ContainerNotifier extends _$ContainerNotifier {
  var sudoCompleter = Completer<bool>();

  @override
  ContainerState build(SSHClient? client, String userName, String hostId, BuildContext context) {
    final type = Stores.container.getType(hostId);
    final initialState = ContainerState(type: type);

    // Async initialization
    Future.microtask(() => refresh());

    return initialState;
  }

  Future<void> setType(ContainerType type) async {
    state = state.copyWith(type: type, error: null, runLog: null, items: null, images: null, version: null);
    Stores.container.setType(type, hostId);
    sudoCompleter = Completer<bool>();
    await refresh();
  }

  void _requiresSudo() async {
    /// Podman is rootless
    if (state.type == ContainerType.podman) return sudoCompleter.complete(false);
    if (!Stores.setting.containerTrySudo.fetch()) {
      return sudoCompleter.complete(false);
    }

    final res = await client?.run(_wrap(ContainerCmdType.images.exec(state.type)));
    if (res?.string.toLowerCase().contains('permission denied') ?? false) {
      return sudoCompleter.complete(true);
    }
    return sudoCompleter.complete(false);
  }

  Future<void> refresh({bool isAuto = false}) async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true);

    if (!sudoCompleter.isCompleted) _requiresSudo();

    final sudo = await sudoCompleter.future;

    /// If sudo is required and auto refresh is enabled, skip the refresh.
    /// Or this will ask for pwd again and again.
    if (sudo && isAuto) {
      state = state.copyWith(isBusy: false);
      return;
    }
    final includeStats = Stores.setting.containerParseStat.fetch();

    var raw = '';
    final cmd = _wrap(ContainerCmdType.execAll(state.type, sudo: sudo, includeStats: includeStats));
    final code = await client?.execWithPwd(
      cmd,
      context: context,
      onStdout: (data, _) => raw = '$raw$data',
      id: hostId,
    );

    state = state.copyWith(isBusy: false);

    if (!context.mounted) return;

    /// Code 127 means command not found
    if (code == 127 || raw.contains(_dockerNotFound)) {
      state = state.copyWith(error: ContainerErr(type: ContainerErrType.notInstalled));
      return;
    }

    // Check result segments count
    final segments = raw.split(ScriptConstants.separator);
    if (segments.length != ContainerCmdType.values.length) {
      state = state.copyWith(
        error: ContainerErr(
          type: ContainerErrType.segmentsNotMatch,
          message: 'Container segments: ${segments.length}',
        ),
      );
      Loggers.app.warning('Container segments: ${segments.length}\n$raw');
      return;
    }

    // Parse version
    final verRaw = ContainerCmdType.version.find(segments);
    try {
      final version = json.decode(verRaw)['Client']['Version'];
      state = state.copyWith(version: version, error: null);
    } catch (e, trace) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.invalidVersion, message: '$e'),
      );
      Loggers.app.warning('Container version failed', e, trace);
    }

    // Parse ps
    final psRaw = ContainerCmdType.ps.find(segments);
    try {
      final lines = psRaw.split('\n');
      if (state.type == ContainerType.docker) {
        /// Due to the fetched data is not in json format, skip table header
        lines.removeWhere((element) => element.contains('CONTAINER ID'));
      }
      lines.removeWhere((element) => element.isEmpty);
      final items = lines.map((e) => ContainerPs.fromRaw(e, state.type)).toList();
      state = state.copyWith(items: items);
    } catch (e, trace) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.parsePs, message: '$e'),
      );
      Loggers.app.warning('Container ps failed', e, trace);
    }

    // Parse images
    final imageRaw = ContainerCmdType.images.find(segments).trim();
    final isEntireJson = imageRaw.startsWith('[') && imageRaw.endsWith(']');
    try {
      List<ContainerImg> images;
      if (isEntireJson) {
        images = (json.decode(imageRaw) as List)
            .map((e) => ContainerImg.fromRawJson(json.encode(e), state.type))
            .toList();
      } else {
        final lines = imageRaw.split('\n');
        lines.removeWhere((element) => element.isEmpty);
        images = lines.map((e) => ContainerImg.fromRawJson(e, state.type)).toList();
      }
      state = state.copyWith(images: images);
    } catch (e, trace) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.parseImages, message: '$e'),
      );
      Loggers.app.warning('Container images failed', e, trace);
    }

    // Parse stats
    final statsRaw = ContainerCmdType.stats.find(segments);
    try {
      final statsLines = statsRaw.split('\n');
      statsLines.removeWhere((element) => element.isEmpty);
      final items = state.items;
      if (items == null) return;

      for (var item in items) {
        final id = item.id;
        if (id == null) continue;
        if (id.length < 5) continue;
        final statsLine = statsLines.firstWhereOrNull(
          /// Use 5 characters to match the container id, possibility of mismatch
          /// is very low.
          (element) => element.contains(id.substring(0, 5)),
        );
        if (statsLine == null) continue;
        item.parseStats(statsLine, state.version);
      }
    } catch (e, trace) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.parseStats, message: '$e'),
      );
      Loggers.app.warning('Parse docker stats: $statsRaw', e, trace);
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

  Future<ContainerErr?> pruneImages({bool all = true}) async {
    final cmd = 'image prune${all ? " -a" : ""} -f';
    return await run(cmd);
  }

  Future<ContainerErr?> pruneContainers() async {
    return await run('container prune -f');
  }

  Future<ContainerErr?> pruneVolumes() async {
    return await run('volume prune -f');
  }

  Future<ContainerErr?> pruneSystem() async {
    return await run('system prune -a -f --volumes');
  }

  Future<ContainerErr?> run(String cmd, {bool autoRefresh = true}) async {
    cmd = switch (state.type) {
      ContainerType.docker => 'docker $cmd',
      ContainerType.podman => 'podman $cmd',
    };

    state = state.copyWith(runLog: '');
    final errs = <String>[];
    final code = await client?.execWithPwd(
      _wrap((await sudoCompleter.future) ? 'sudo -S $cmd' : cmd),
      context: context,
      onStdout: (data, _) {
        state = state.copyWith(runLog: '${state.runLog}$data');
      },
      onStderr: (data, _) => errs.add(data),
      id: hostId,
    );
    state = state.copyWith(runLog: null);

    if (code != 0) {
      return ContainerErr(type: ContainerErrType.unknown, message: errs.join('\n').trim());
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
  images
  // No specific commands needed for prune actions as they are simple
  // and don't require splitting output with ScriptConstants.separator
  ;

  String exec(ContainerType type, {bool sudo = false, bool includeStats = false}) {
    final prefix = sudo ? 'sudo -S ${type.name}' : type.name;
    return switch (this) {
      ContainerCmdType.version => '$prefix version $_jsonFmt',
      ContainerCmdType.ps => switch (type) {
        /// TODO: Rollback to json format when performance recovers.
        /// Use [_jsonFmt] in Docker will cause the operation to slow down.
        ContainerType.docker =>
          '$prefix ps -a --format "table {{printf \\"'
              '%-15.15s '
              '%-30.30s '
              '${"%-50.50s " * 2}\\"'
              ' .ID .Status .Names .Image}}"',
        ContainerType.podman => '$prefix ps -a $_jsonFmt',
      },
      ContainerCmdType.stats => includeStats ? '$prefix stats --no-stream $_jsonFmt' : 'echo PASS',
      ContainerCmdType.images => '$prefix image ls $_jsonFmt',
    };
  }

  static String execAll(ContainerType type, {bool sudo = false, bool includeStats = false}) {
    return ContainerCmdType.values
        .map((e) => e.exec(type, sudo: sudo, includeStats: includeStats))
        .join('\necho ${ScriptConstants.separator}\n');
  }

  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

part 'container.freezed.dart';
part 'container.g.dart';

final _dockerNotFound = RegExp(
  r"command not found|Unknown command|Command '\w+' not found",
);
final _podmanEmulationMsg = 'Emulate Docker CLI using podman';

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
  String? _cachedPassword;
  var _refreshGeneration = 0;
  var _pendingRefresh = false;

  @override
  ContainerState build(
    SSHClient? client,
    String userName,
    String hostId,
    BuildContext context,
  ) {
    final type = Stores.container.getType(hostId);
    final initialState = ContainerState(type: type);

    // Async initialization
    Future.microtask(() => refresh());

    return initialState;
  }

  Future<String?> _getSudoPassword() async {
    if (_cachedPassword != null) return _cachedPassword;

    if (!context.mounted) return null;
    final pwd = await context.showPwdDialog(title: userName, id: hostId);

    if (pwd != null && pwd.isNotEmpty) {
      _cachedPassword = pwd;
    }
    return pwd;
  }

  Future<void> setType(ContainerType type) async {
    final refreshGeneration = _resetSudoProbe();
    state = state.copyWith(
      type: type,
      error: null,
      runLog: null,
      items: null,
      images: null,
      version: null,
      isBusy: false,
    );
    Stores.container.setType(type, hostId);
    await refresh(generation: refreshGeneration);
  }

  void resetSudoProbe() {
    _resetSudoProbe();
    state = state.copyWith(isBusy: false);
  }

  int _resetSudoProbe() {
    sudoCompleter = Completer<bool>();
    return ++_refreshGeneration;
  }

  bool _isStaleRefresh(int generation) {
    return generation != _refreshGeneration || !ref.mounted;
  }

  Future<void> _requiresSudo(
    Completer<bool> completer,
    ContainerType type,
  ) async {
    /// Podman is rootless
    if (type == ContainerType.podman) {
      return completer.complete(false);
    }
    if (!Stores.setting.containerTrySudo.fetch()) {
      return completer.complete(false);
    }

    try {
      final res = await client?.run(
        _wrap(ContainerCmdType.images.exec(type)),
      );
      if (res?.string.toLowerCase().contains('permission denied') ?? false) {
        return completer.complete(true);
      }
      return completer.complete(false);
    } catch (e, trace) {
      Loggers.app.warning('Container sudo check failed', e, trace);
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
  }

  Future<void> refresh({bool isAuto = false, int? generation}) async {
    if (state.isBusy) {
      _pendingRefresh = true;
      return;
    }
    final refreshGeneration = generation ?? _refreshGeneration;
    final type = state.type;
    state = state.copyWith(isBusy: true);

    final sudo = sudoCompleter;
    if (!sudo.isCompleted) unawaited(_requiresSudo(sudo, type));

    final needSudo = await sudo.future;
    if (_isStaleRefresh(refreshGeneration)) return;

    /// If sudo is required and auto refresh is enabled, skip the refresh.
    /// Or this will ask for pwd again and again.
    if (needSudo && isAuto) {
      state = state.copyWith(isBusy: false);
      return;
    }

    String? password;
    if (needSudo) {
      password = await _getSudoPassword();
      if (_isStaleRefresh(refreshGeneration)) return;
      if (password == null) {
        state = state.copyWith(
          isBusy: false,
          error: ContainerErr(
            type: ContainerErrType.sudoPasswordRequired,
            message: l10n.containerSudoPasswordRequired,
          ),
        );
        return;
      }
    }

    final includeStats = Stores.setting.containerParseStat.fetch();

    final cmd = _wrap(
      ContainerCmdType.execAll(
        type,
        sudo: needSudo,
        includeStats: includeStats,
        password: password,
      ),
    );
    int? code;
    String raw = '';
    var isPodmanEmulation = false;
    if (client != null) {
      (code, raw) = await client!.execWithPwd(
        cmd,
        context: context,
        id: hostId,
        onStderr: (data, _) {
          if (data.contains(_podmanEmulationMsg)) {
            isPodmanEmulation = true;
          }
        },
      );
    } else {
      if (_isStaleRefresh(refreshGeneration)) return;
      state = state.copyWith(
        isBusy: false,
        error: ContainerErr(type: ContainerErrType.noClient),
      );
      return;
    }

    if (_isStaleRefresh(refreshGeneration)) return;
    state = state.copyWith(isBusy: false);

    if (!context.mounted) return;

    /// Code 127 means command not found
    if (code == 127 || raw.contains(_dockerNotFound)) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.notInstalled),
      );
      return;
    }

    /// Sudo password error (exitCode = 2)
    if (code == 2) {
      _cachedPassword = null;
      state = state.copyWith(
        error: ContainerErr(
          type: ContainerErrType.sudoPasswordIncorrect,
          message: l10n.containerSudoPasswordIncorrect,
        ),
      );
      return;
    }

    /// Pre-parse Podman detection
    if (isPodmanEmulation) {
      state = state.copyWith(
        error: ContainerErr(
          type: ContainerErrType.podmanDetected,
          message: l10n.podmanDockerEmulationDetected,
        ),
      );
      return;
    }

    /// Detect Podman not installed when using Podman mode
    if (state.type == ContainerType.podman &&
        raw.contains('podman: not found')) {
      state = state.copyWith(
        error: ContainerErr(type: ContainerErrType.notInstalled),
      );
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
      if (state.error == null) {
        state = state.copyWith(
          error: ContainerErr(
            type: ContainerErrType.invalidVersion,
            message: '$e',
          ),
        );
      }
      Loggers.app.warning('Container version failed', e, trace);
    }

    // Parse ps
    final psRaw = ContainerCmdType.ps.find(segments);
    try {
      final lines = psRaw.split('\n');
      if (type == ContainerType.docker) {
        /// Due to the fetched data is not in json format, skip table header
        final headerIdx = lines.indexWhere((element) {
          return element.trimLeft().startsWith('CONTAINER ID');
        });
        if (headerIdx != -1) lines.removeAt(headerIdx);
      }
      lines.removeWhere((element) => element.isEmpty);
      final items = <ContainerPs>[];
      for (final line in lines) {
        try {
          items.add(ContainerPs.fromRaw(line, type));
        } on FormatException catch (e, trace) {
          Loggers.app.warning('Skip malformed container ps row', e, trace);
        }
      }
      state = state.copyWith(items: items);
    } catch (e, trace) {
      if (state.error == null) {
        state = state.copyWith(
          error: ContainerErr(type: ContainerErrType.parsePs, message: '$e'),
        );
      }
      Loggers.app.warning('Container ps failed', e, trace);
    }

    // Parse images
    final imageRaw = ContainerCmdType.images.find(segments).trim();
    final isEntireJson = imageRaw.startsWith('[') && imageRaw.endsWith(']');
    try {
      List<ContainerImg> images;
      if (isEntireJson) {
        images = (json.decode(imageRaw) as List)
            .map((e) => ContainerImg.fromRawJson(json.encode(e), type))
            .toList();
      } else {
        final lines = imageRaw.split('\n');
        lines.removeWhere((element) => element.isEmpty);
        images = lines
            .map((e) => ContainerImg.fromRawJson(e, type))
            .toList();
      }
      state = state.copyWith(images: images);
    } catch (e, trace) {
      if (state.error == null) {
        state = state.copyWith(
          error: ContainerErr(
            type: ContainerErrType.parseImages,
            message: '$e',
          ),
        );
      }
      Loggers.app.warning('Container images failed', e, trace);
    }

    // Parse stats
    final statsRaw = ContainerCmdType.stats.find(segments);
    try {
      final statsLines = statsRaw.split('\n');
      statsLines.removeWhere((element) => element.isEmpty);
      final items = state.items;
      if (items == null) {
        await _refreshPendingIfNeeded(refreshGeneration);
        return;
      }

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
      if (state.error == null) {
        state = state.copyWith(
          error: ContainerErr(type: ContainerErrType.parseStats, message: '$e'),
        );
      }
      Loggers.app.warning('Parse docker stats: $statsRaw', e, trace);
    }
    await _refreshPendingIfNeeded(refreshGeneration);
  }

  Future<void> _refreshPendingIfNeeded(int generation) async {
    if (_isStaleRefresh(generation) || !_pendingRefresh || state.isBusy) return;
    _pendingRefresh = false;
    await refresh(generation: generation);
  }

  Future<ContainerErr?> stop(String id) async => await run('stop ${shellSingleQuote(id)}');

  Future<ContainerErr?> start(String id) async => await run('start ${shellSingleQuote(id)}');

  Future<ContainerErr?> delete(String id, bool force) async {
    if (force) {
      return await run('rm -f ${shellSingleQuote(id)}');
    }
    return await run('rm ${shellSingleQuote(id)}');
  }

  Future<ContainerErr?> restart(String id) async =>
      await run('restart ${shellSingleQuote(id)}');

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

  Future<ContainerErr?> run(String cmd) async {
    if (client == null) {
      return ContainerErr(type: ContainerErrType.noClient);
    }

    cmd = switch (state.type) {
      ContainerType.docker => 'docker $cmd',
      ContainerType.podman => 'podman $cmd',
    };

    final needSudo = await sudoCompleter.future;
    String? password;
    if (needSudo) {
      password = await _getSudoPassword();
      if (password == null) {
        return ContainerErr(
          type: ContainerErrType.sudoPasswordRequired,
          message: l10n.containerSudoPasswordRequired,
        );
      }
    }

    if (needSudo) {
      cmd = _buildSudoCmd(cmd, password!);
    }

    state = state.copyWith(runLog: '');
    final (code, _) = await client!.execWithPwd(
      _wrap(cmd),
      context: context,
      onStdout: (data, _) {
        state = state.copyWith(runLog: '${state.runLog}$data');
      },
      id: hostId,
    );

    state = state.copyWith(runLog: null);

    if (code == 2) {
      _cachedPassword = null;
      return ContainerErr(
        type: ContainerErrType.sudoPasswordIncorrect,
        message: l10n.containerSudoPasswordIncorrect,
      );
    }
    if (code != 0) {
      return ContainerErr(
        type: ContainerErrType.unknown,
        message: 'Command execution failed',
      );
    }
    await refresh();
    return null;
  }

  /// wrap cmd with `docker host`
  String _wrap(String cmd) {
    final dockerHost = Stores.container.fetch(hostId);
    cmd = 'export LANG=en_US.UTF-8 && $cmd';
    final noDockerHost = dockerHost?.isEmpty ?? true;
    if (!noDockerHost) {
      cmd = 'export DOCKER_HOST=${_shellQuote(dockerHost!)} && $cmd';
    }
    return cmd;
  }
}

const _jsonFmt = '--format "{{json .}}"';

String _buildSudoCmd(String baseCmd, String password) {
  final pwdBase64 = base64Encode(utf8.encode(password));
  return 'echo "$pwdBase64" | base64 -d | sudo -S $baseCmd';
}

String shellSingleQuote(String value) => "'${value.replaceAll("'", "'\\''")}'";

String _shellQuote(String value) => shellSingleQuote(value);

enum ContainerCmdType {
  version,
  ps,
  stats,
  images
  // No specific commands needed for prune actions as they are simple
  // and don't require splitting output with ScriptConstants.separator
  ;

  String exec(ContainerType type, {bool includeStats = false}) {
    final baseCmd = switch (this) {
      ContainerCmdType.version => '${type.name} version $_jsonFmt',
      ContainerCmdType.ps => switch (type) {
        ContainerType.docker =>
          '${type.name} ps -a --format "{{.ID}}\\t{{.Status}}\\t{{.Names}}\\t{{.Image}}"',
        ContainerType.podman => '${type.name} ps -a $_jsonFmt',
      },
      ContainerCmdType.stats =>
        includeStats ? '${type.name} stats --no-stream $_jsonFmt' : 'echo PASS',
      ContainerCmdType.images => '${type.name} image ls $_jsonFmt',
    };

    return baseCmd;
  }

  static String execAll(
    ContainerType type, {
    bool sudo = false,
    bool includeStats = false,
    String? password,
  }) {
    final commands = ContainerCmdType.values
        .map((e) => e.exec(type, includeStats: includeStats))
        .join('\necho ${ScriptConstants.separator}\n');

    final wrappedCommands = 'sh -c \'${commands.replaceAll("'", "'\\''")}\'';

    if (sudo && password != null) {
      return _buildSudoCmd(wrappedCommands, password);
    }
    if (sudo) {
      return 'sudo -S $wrappedCommands';
    }
    return wrappedCommands;
  }

  /// Find out the required segment from [segments]
  String find(List<String> segments) {
    return segments[index];
  }
}

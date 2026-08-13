import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/shell_quote.dart' as sh;
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

part 'container.freezed.dart';
part 'container.g.dart';

final _dockerNotFound = RegExp(
  r"command not found|Unknown command|Command '\w+' not found",
);
final _podmanEmulationMsg = 'Emulate Docker CLI using podman';

// Forwarder to the canonical quoter so part files can reference it inside
// extension method bodies (imported top-level names are not visible there).
String shellSingleQuote(String value) => sh.shellSingleQuote(value);

/// Build a single command that acts on multiple containers, e.g.
/// `start 'id1' 'id2'`. Returns null when [ids] is empty.
String? buildContainerBulkCmd(String action, Iterable<String> ids) {
  final args = ids.map(shellSingleQuote).join(' ');
  if (args.isEmpty) return null;
  return '$action $args';
}

String buildContainerRunCmd({
  required String image,
  required String name,
  required Iterable<String> extraArgs,
}) {
  final imageArg = shellSingleQuote(image);
  final args = extraArgs.map(shellSingleQuote).join(' ');
  final suffix = args.isEmpty ? imageArg : '$args $imageArg';
  final nameArg = name.isEmpty ? '' : ' --name ${shellSingleQuote(name)}';
  return 'run -itd$nameArg $suffix';
}

List<String> parseContainerRunArgs(String raw) {
  final args = <String>[];
  final current = StringBuffer();
  String? quote;
  var escaping = false;
  var tokenStarted = false;

  void finishToken() {
    if (!tokenStarted) return;
    args.add(current.toString());
    current.clear();
    tokenStarted = false;
  }

  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    if (escaping) {
      current.write(char);
      tokenStarted = true;
      escaping = false;
      continue;
    }
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else if (char == r'\' && quote == '"') {
        escaping = true;
      } else {
        current.write(char);
      }
      tokenStarted = true;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      tokenStarted = true;
    } else if (char == r'\') {
      escaping = true;
      tokenStarted = true;
    } else if (RegExp(r'\s').hasMatch(char)) {
      finishToken();
    } else {
      current.write(char);
      tokenStarted = true;
    }
  }
  if (quote != null || escaping) {
    throw const FormatException('Unterminated quoted container argument');
  }
  finishToken();
  return args.toList(growable: false);
}

List<ContainerImg> parseContainerImagesOutput(
  String raw,
  ContainerType type,
) {
  final trimmed = raw.trim();
  final images = <ContainerImg>[];
  for (final row in _containerImageRows(trimmed)) {
    if (row.trim().isEmpty) continue;
    try {
      images.add(ContainerImg.fromRawJson(row, type));
    } catch (e, trace) {
      Loggers.app.warning('Skip malformed container image row', e, trace);
    }
  }
  return images.toList(growable: false);
}

Iterable<String> _containerImageRows(String raw) sync* {
  if (!raw.startsWith('[')) {
    yield* raw.split('\n');
    return;
  }
  try {
    final decoded = json.decode(raw);
    if (decoded is List) {
      for (final row in decoded) {
        yield json.encode(row);
      }
      return;
    }
  } catch (e, trace) {
    Loggers.app.warning('Recover malformed container image array', e, trace);
  }
  yield* _completeJsonObjects(raw);
}

Iterable<String> _completeJsonObjects(String raw) sync* {
  var start = -1;
  var depth = 0;
  var inString = false;
  var escaping = false;
  for (var index = 0; index < raw.length; index++) {
    final char = raw[index];
    if (inString) {
      if (escaping) {
        escaping = false;
      } else if (char == r'\') {
        escaping = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      if (depth == 0) start = index;
      depth++;
    } else if (char == '}' && depth > 0) {
      depth--;
      if (depth == 0 && start >= 0) {
        yield raw.substring(start, index + 1);
        start = -1;
      }
    }
  }
}

List<({String id, String raw})> parseContainerStatsRows(
  Iterable<String> rows,
) {
  final parsed = <({String id, String raw})>[];
  for (final row in rows) {
    if (row.trim().isEmpty) continue;
    try {
      final data = json.decode(row) as Map<String, dynamic>;
      final statsId = (data['ID'] ?? data['Id'] ?? data['ContainerID'])
          ?.toString()
          .trim();
      if (statsId == null || statsId.isEmpty) continue;
      parsed.add((id: statsId, raw: row));
    } catch (e, trace) {
      Loggers.app.warning('Skip malformed container stats row', e, trace);
    }
  }
  return parsed.toList(growable: false);
}

String? findContainerStatsRow(
  Iterable<({String id, String raw})> rows,
  String? containerId,
) {
  final id = containerId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final row in rows) {
    final prefixMatch = id.length >= 12 &&
        row.id.length >= 12 &&
        (id.startsWith(row.id) || row.id.startsWith(id));
    if (id == row.id || prefixMatch) return row.raw;
  }
  return null;
}

/// Build a non-interactive image prune command.
///
/// Without [allUnused], only dangling images are removed. `-f` is always
/// included because an interactive confirmation cannot be answered reliably
/// through the remote execution flow.
String buildContainerImagePruneCmd({bool allUnused = false}) {
  final flags = [if (allUnused) '-a', '-f'].join(' ');
  return 'image prune $flags';
}

/// Build a non-interactive system prune command with an explicit scope.
String buildContainerSystemPruneCmd({
  bool allUnusedImages = false,
  bool includeVolumes = false,
}) {
  final flags = [
    if (allUnusedImages) '-a',
    if (includeVolumes) '--volumes',
    '-f',
  ].join(' ');
  return 'system prune $flags';
}

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

enum ContainerRefreshTarget { containers, images }

@riverpod
class ContainerNotifier extends _$ContainerNotifier {
  var sudoCompleter = Completer<bool>();
  String? _cachedPassword;
  var _refreshGeneration = 0;
  ({ContainerRefreshTarget target, bool isAuto})? _pendingRefresh;

  @override
  ContainerState build(
    String userName,
    String hostId,
    BuildContext context,
  ) {
    final type = Stores.container.getType(hostId);
    return ContainerState(type: type);
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

  bool setType(ContainerType type) {
    if (state.runLog != null) return false;
    _resetSudoProbe();
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
    return true;
  }

  void resetSudoProbe() {
    _resetSudoProbe();
    state = state.copyWith(isBusy: false);
  }

  int _resetSudoProbe() {
    sudoCompleter = Completer<bool>();
    _pendingRefresh = null;
    return ++_refreshGeneration;
  }

  void _queueRefresh(ContainerRefreshTarget target, bool isAuto) {
    final pending = _pendingRefresh;
    _pendingRefresh = (
      target: target,
      isAuto: pending?.target == target
          ? isAuto && pending!.isAuto
          : isAuto,
    );
  }

  bool _isStaleRefresh(int generation) {
    return generation != _refreshGeneration || !ref.mounted;
  }

  Future<void> _requiresSudo(
    Completer<bool> completer,
    ContainerType type,
    ContainerRefreshTarget target,
  ) async {
    /// Podman is rootless
    if (type == ContainerType.podman) {
      return completer.complete(false);
    }
    if (!Stores.setting.containerTrySudo.fetch()) {
      return completer.complete(false);
    }

    try {
      final probe = switch (target) {
        ContainerRefreshTarget.containers => ContainerCmdType.ps,
        ContainerRefreshTarget.images => ContainerCmdType.images,
      };
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      final res = await exec.run(_wrap(probe.exec(type)));
      if (res.combined.toLowerCase().contains('permission denied')) {
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

  Future<void> refreshContainers({bool isAuto = false}) => refresh(
    ContainerRefreshTarget.containers,
    isAuto: isAuto,
  );

  Future<void> refreshImages({bool isAuto = false}) => refresh(
    ContainerRefreshTarget.images,
    isAuto: isAuto,
  );

  Future<void> refresh(
    ContainerRefreshTarget target, {
    bool isAuto = false,
    int? generation,
  }) async {
    if (state.isBusy || state.runLog != null) {
      _queueRefresh(target, isAuto);
      return;
    }
    final refreshGeneration = generation ?? _refreshGeneration;
    final type = state.type;
    state = state.copyWith(isBusy: true, error: null);

    final sudo = sudoCompleter;
    if (!sudo.isCompleted) unawaited(_requiresSudo(sudo, type, target));

    final needSudo = await sudo.future;
    if (_isStaleRefresh(refreshGeneration)) return;

    /// If sudo is required and auto refresh is enabled, skip the refresh.
    /// Or this will ask for pwd again and again.
    if (needSudo && isAuto) {
      await _finishRefresh(refreshGeneration);
      return;
    }

    String? password;
    if (needSudo) {
      password = await _getSudoPassword();
      if (_isStaleRefresh(refreshGeneration)) return;
      if (password == null) {
        _setRefreshError(
          target,
          ContainerErr(
            type: ContainerErrType.sudoPasswordRequired,
            message: l10n.containerSudoPasswordRequired,
          ),
        );
        await _finishRefresh(refreshGeneration);
        return;
      }
    }

    final includeStats = Stores.setting.containerParseStat.fetch();
    final commands = switch (target) {
      ContainerRefreshTarget.containers => [
        if (state.version == null) ContainerCmdType.version,
        ContainerCmdType.ps,
        if (includeStats) ContainerCmdType.stats,
      ],
      ContainerRefreshTarget.images => [
        if (state.version == null) ContainerCmdType.version,
        ContainerCmdType.images,
      ],
    };

    final separator = '${ScriptConstants.separator}_'
        '${DateTime.now().microsecondsSinceEpoch}_$refreshGeneration';
    final cmd = _wrap(
      ContainerCmdType.execSelected(
        commands,
        type,
        separator: separator,
      ),
      sudo: needSudo,
    );
    int? code;
    String raw = '';
    var isPodmanEmulation = false;
    try {
      // Asked for rather than held: a server reached over its monitor agent
      // has no connection sitting there until something needs one, and a
      // failure to open one is reported below like any other.
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      final result = await exec.runWithSudo(
        cmd,
        password: password,
        onStderr: (data) {
          if (data.contains(_podmanEmulationMsg)) {
            isPodmanEmulation = true;
          }
        },
      );
      (code, raw) = (result.exitCode, result.stdout);
    } catch (e, trace) {
      if (_isStaleRefresh(refreshGeneration)) return;
      Loggers.app.warning('Container refresh execution failed', e, trace);
      _setRefreshError(
        target,
        ContainerErr(type: ContainerErrType.unknown, message: '$e'),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    if (_isStaleRefresh(refreshGeneration)) return;
    if (!context.mounted) {
      _pendingRefresh = null;
      state = state.copyWith(isBusy: false);
      return;
    }

    /// Code 127 means command not found
    if (code == 127 || raw.contains(_dockerNotFound)) {
      _setRefreshError(
        target,
        // Carries what the shell said: "not installed" is a reading of that
        // output, and it is wrong often enough — a runtime installed for
        // another account, a `DOCKER_HOST` pointing nowhere — that the user
        // should be able to see what it was.
        ContainerErr(type: ContainerErrType.notInstalled, message: raw.trim()),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    /// Sudo password error (exitCode = 2)
    if (needSudo && code == 2) {
      _cachedPassword = null;
      _setRefreshError(
        target,
        ContainerErr(
          type: ContainerErrType.sudoPasswordIncorrect,
          message: l10n.containerSudoPasswordIncorrect,
        ),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }
    if (code != 0) {
      _setRefreshError(
        target,
        ContainerErr(
          type: ContainerErrType.unknown,
          message: raw.trim().isEmpty ? libL10n.fail : raw.trim(),
        ),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    /// Pre-parse Podman detection
    if (isPodmanEmulation) {
      _setRefreshError(
        target,
        ContainerErr(
          type: ContainerErrType.podmanDetected,
          message: l10n.podmanDockerEmulationDetected,
        ),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    /// Detect Podman not installed when using Podman mode
    if (state.type == ContainerType.podman &&
        raw.contains('podman: not found')) {
      _setRefreshError(
        target,
        ContainerErr(type: ContainerErrType.notInstalled, message: raw.trim()),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    // Check result segments count
    final segments = raw.split(separator);
    if (segments.length != commands.length) {
      _setRefreshError(
        target,
        ContainerErr(
          type: ContainerErrType.segmentsNotMatch,
          message: l10n.containerSegmentsMismatch(segments.length),
        ),
      );
      Loggers.app.warning('Container segments: ${segments.length}\n$raw');
      await _finishRefresh(refreshGeneration);
      return;
    }
    final output = <ContainerCmdType, String>{
      for (var index = 0; index < commands.length; index++)
        commands[index]: segments[index],
    };

    // Parse version only until it has been cached for the selected runtime.
    final verRaw = output[ContainerCmdType.version];
    if (verRaw != null) {
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
    }

    if (target == ContainerRefreshTarget.containers) {
      // Parse ps
      final psRaw = output[ContainerCmdType.ps]!;
      try {
        if (type == ContainerType.docker) {
          final lines = psRaw.split('\n');
          /// Due to the fetched data is not in json format, skip table header
          final headerIdx = lines.indexWhere((element) {
            return element.trimLeft().startsWith('CONTAINER ID');
          });
          if (headerIdx != -1) lines.removeAt(headerIdx);
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
        } else {
          state = state.copyWith(items: parsePodmanPsOutput(psRaw));
        }
      } catch (e, trace) {
        if (state.error == null) {
          state = state.copyWith(
            items: null,
            error: ContainerErr(type: ContainerErrType.parsePs, message: '$e'),
          );
        }
        Loggers.app.warning('Container ps failed', e, trace);
      }

      // Parse stats
      final statsRaw = output[ContainerCmdType.stats];
      if (statsRaw != null) {
        try {
          final statsRows = parseContainerStatsRows(statsRaw.split('\n'));
          final items = state.items;
          if (items == null) {
            await _finishRefresh(refreshGeneration);
            return;
          }

          for (var item in items) {
            final statsLine = findContainerStatsRow(statsRows, item.id);
            if (statsLine == null) continue;
            try {
              item.parseStats(statsLine, state.version);
            } catch (e, trace) {
              Loggers.app.warning('Skip malformed container stats', e, trace);
            }
          }
        } catch (e, trace) {
          if (state.error == null) {
            state = state.copyWith(
              error: ContainerErr(
                type: ContainerErrType.parseStats,
                message: '$e',
              ),
            );
          }
          Loggers.app.warning('Parse container stats: $statsRaw', e, trace);
        }
      }
    } else {
      // Parse images
      final imageRaw = output[ContainerCmdType.images]!;
      try {
        final images = parseContainerImagesOutput(imageRaw, type);
        state = state.copyWith(images: images);
      } catch (e, trace) {
        if (state.error == null) {
          state = state.copyWith(
            images: null,
            error: ContainerErr(
              type: ContainerErrType.parseImages,
              message: '$e',
            ),
          );
        }
        Loggers.app.warning('Container images failed', e, trace);
      }
    }
    await _finishRefresh(refreshGeneration);
  }

  Future<void> _finishRefresh(int generation) async {
    if (_isStaleRefresh(generation)) return;
    state = state.copyWith(isBusy: false);
    await _refreshPendingIfNeeded(generation);
  }

  void _setRefreshError(ContainerRefreshTarget target, ContainerErr error) {
    state = switch (target) {
      ContainerRefreshTarget.containers => state.copyWith(
          items: null,
          error: error,
        ),
      ContainerRefreshTarget.images => state.copyWith(
          images: null,
          error: error,
        ),
    };
  }

  Future<void> _refreshPendingIfNeeded(int generation) async {
    final pending = _pendingRefresh;
    if (_isStaleRefresh(generation) ||
        pending == null ||
        state.isBusy ||
        state.runLog != null) {
      return;
    }
    _pendingRefresh = null;
    await refresh(
      pending.target,
      isAuto: pending.isAuto,
      generation: generation,
    );
  }

  Future<ContainerErr?> stop(String id) async =>
      await run(
        'stop ${shellSingleQuote(id)}',
        refreshTarget: ContainerRefreshTarget.containers,
      );

  Future<ContainerErr?> start(String id) async =>
      await run(
        'start ${shellSingleQuote(id)}',
        refreshTarget: ContainerRefreshTarget.containers,
      );

  Future<ContainerErr?> delete(String id, bool force) async {
    if (force) {
      return await run(
        'rm -f ${shellSingleQuote(id)}',
        refreshTarget: ContainerRefreshTarget.containers,
      );
    }
    return await run(
      'rm ${shellSingleQuote(id)}',
      refreshTarget: ContainerRefreshTarget.containers,
    );
  }

  Future<ContainerErr?> restart(String id) async =>
      await run(
        'restart ${shellSingleQuote(id)}',
        refreshTarget: ContainerRefreshTarget.containers,
      );

  Future<ContainerErr?> startAll(Iterable<String> ids) async =>
      await _runBulk('start', ids);

  Future<ContainerErr?> stopAll(Iterable<String> ids) async =>
      await _runBulk('stop', ids);

  Future<ContainerErr?> restartAll(Iterable<String> ids) async =>
      await _runBulk('restart', ids);

  Future<ContainerErr?> _runBulk(String action, Iterable<String> ids) async {
    final cmd = buildContainerBulkCmd(action, ids);
    if (cmd == null) return null;
    return await run(
      cmd,
      refreshTarget: ContainerRefreshTarget.containers,
    );
  }

  Future<ContainerErr?> pruneImages({bool allUnused = false}) async =>
      await run(
        buildContainerImagePruneCmd(allUnused: allUnused),
        refreshTarget: ContainerRefreshTarget.images,
      );

  Future<ContainerErr?> pruneContainers() async {
    return await run(
      'container prune -f',
      refreshTarget: ContainerRefreshTarget.containers,
    );
  }

  Future<ContainerErr?> pruneVolumes() async {
    return await run('volume prune -f', refreshTarget: null);
  }

  Future<ContainerErr?> pruneSystem({
    bool allUnusedImages = false,
    bool includeVolumes = false,
  }) async {
    final result = await run(
      buildContainerSystemPruneCmd(
        allUnusedImages: allUnusedImages,
        includeVolumes: includeVolumes,
      ),
      refreshTarget: null,
    );
    if (result != null) return result;
    await refreshContainers();
    await refreshImages();
    return null;
  }

  Future<ContainerErr?> run(
    String cmd, {
    ContainerRefreshTarget? refreshTarget = ContainerRefreshTarget.containers,
  }) async {
    if (state.isBusy || state.runLog != null) {
      return ContainerErr(
        type: ContainerErrType.unknown,
        message: l10n.containerOperationInProgress,
      );
    }
    state = state.copyWith(runLog: '');

    final type = state.type;
    cmd = switch (type) {
      ContainerType.docker => 'docker $cmd',
      ContainerType.podman => 'podman $cmd',
    };

    final sudo = sudoCompleter;
    if (!sudo.isCompleted) {
      unawaited(
        _requiresSudo(
          sudo,
          type,
          refreshTarget ?? ContainerRefreshTarget.containers,
        ),
      );
    }
    final needSudo = await sudo.future;
    if (!ref.mounted) return null;
    String? password;
    if (needSudo) {
      password = await _getSudoPassword();
      if (!ref.mounted) return null;
      if (password == null) {
        await _finishRun();
        return ContainerErr(
          type: ContainerErrType.sudoPasswordRequired,
          message: l10n.containerSudoPasswordRequired,
        );
      }
    }

    int? code;
    try {
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      final result = await exec.runWithSudo(
        _wrap(cmd, sudo: needSudo),
        password: password,
        onStdout: (data) {
          if (ref.mounted) {
            state = state.copyWith(runLog: '${state.runLog}$data');
          }
        },
      );
      code = result.exitCode;
    } catch (e, trace) {
      Loggers.app.warning('Container command execution failed', e, trace);
      if (ref.mounted) await _finishRun();
      return ContainerErr(type: ContainerErrType.unknown, message: '$e');
    }

    if (!ref.mounted) return null;

    if (needSudo && code == 2) {
      _cachedPassword = null;
      await _finishRun();
      return ContainerErr(
        type: ContainerErrType.sudoPasswordIncorrect,
        message: l10n.containerSudoPasswordIncorrect,
      );
    }
    if (code != 0) {
      await _finishRun();
      return ContainerErr(
        type: ContainerErrType.unknown,
        message: libL10n.fail,
      );
    }
    await _finishRun(refreshTarget: refreshTarget);
    return null;
  }

  Future<void> _finishRun({ContainerRefreshTarget? refreshTarget}) async {
    if (!ref.mounted) return;
    state = state.copyWith(runLog: null);
    if (refreshTarget != null) {
      if (_pendingRefresh?.target == refreshTarget) {
        _pendingRefresh = null;
      }
      await refresh(refreshTarget);
    } else {
      await _refreshPendingIfNeeded(_refreshGeneration);
    }
  }

  Future<String?> prepareInteractiveCommand(
    String cmd, {
    ContainerRefreshTarget target = ContainerRefreshTarget.containers,
  }) async {
    final generation = _refreshGeneration;
    final type = state.type;
    final sudo = sudoCompleter;
    if (!sudo.isCompleted) unawaited(_requiresSudo(sudo, type, target));
    final needSudo = await sudo.future;
    if (_isStaleRefresh(generation)) return null;
    return _wrap(cmd, sudo: needSudo);
  }

  /// Wrap commands with the container runtime host environment variable.
  String _wrap(
    String cmd, {
    bool sudo = false,
  }) => buildContainerRuntimeCommand(
    command: cmd,
    type: state.type,
    containerHost: Stores.container.fetch(hostId, state.type),
    sudo: sudo,
  );
}

const _jsonFmt = '--format "{{json .}}"';

/// The command line for one container-runtime call.
///
/// Carries no password: `sudo -S` reads one from stdin, and `ServerExec`'s
/// `runWithSudo` puts it there. Written into the command instead it would end
/// up in the agent's audit log and the machine's process list.
String buildContainerRuntimeCommand({
  required String command,
  required ContainerType type,
  String? containerHost,
  bool sudo = false,
}) {
  final environment = <String>['LANG=en_US.UTF-8'];
  if (containerHost?.isNotEmpty ?? false) {
    final hostVariable = type == ContainerType.podman
        ? 'CONTAINER_HOST'
        : 'DOCKER_HOST';
    environment.add('$hostVariable=${shellSingleQuote(containerHost!)}');
  }
  if (sudo) {
    return 'sudo -S env ${environment.join(' ')} $command';
  }
  final exports = environment.map((value) => 'export $value').join(' && ');
  return '$exports && $command';
}

enum ContainerCmdType {
  version,
  ps,
  stats,
  images;

  String exec(ContainerType type) {
    final baseCmd = switch (this) {
      ContainerCmdType.version => '${type.name} version $_jsonFmt',
      ContainerCmdType.ps => switch (type) {
        ContainerType.docker => '${type.name} ps -a --format '
            '"{{.ID}}\\t{{.Status}}\\t{{.Names}}\\t{{.Image}}\\t'
            '{{.Label \\"com.docker.compose.project\\"}}\\t'
            '{{.Label \\"com.docker.compose.project.working_dir\\"}}"',
        ContainerType.podman => '${type.name} ps -a --format '
            '"{{json .}}\\t{{.Status}}"',
      },
      ContainerCmdType.stats => '${type.name} stats --no-stream $_jsonFmt',
      ContainerCmdType.images => '${type.name} image ls --digests $_jsonFmt',
    };

    return baseCmd;
  }

  /// Several commands as one, their outputs told apart by [separator].
  ///
  /// Privilege is not this function's business: the caller wraps the result
  /// with `_wrap(sudo: ...)`, and the password reaches `sudo -S` on stdin.
  static String execSelected(
    Iterable<ContainerCmdType> types,
    ContainerType type, {
    String separator = ScriptConstants.separator,
  }) {
    final commands = types
        .map((e) => e.exec(type))
        .join('\necho $separator\n');

    return 'sh -c \'${commands.replaceAll("'", "'\\''")}\'';
  }
}

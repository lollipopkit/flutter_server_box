import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/shell_quote.dart' as sh;
import 'package:server_box/data/model/app/error.dart';
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
const _containerSeparatorPrefix = 'SrvBoxContainerSep';

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
  var escapingInDoubleQuotes = false;
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
      if (escapingInDoubleQuotes &&
          char != r'$' &&
          char != '`' &&
          char != '"' &&
          char != r'\' &&
          char != '\n') {
        current.write(r'\');
      }
      if (char != '\n' || !escapingInDoubleQuotes) current.write(char);
      tokenStarted = true;
      escaping = false;
      escapingInDoubleQuotes = false;
      continue;
    }
    if (quote != null) {
      if (char == quote) {
        quote = null;
      } else if (char == r'\' && quote == '"') {
        escaping = true;
        escapingInDoubleQuotes = true;
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

List<ContainerImg> parseContainerImagesOutput(String raw, ContainerType type) {
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

List<({String id, String raw})> parseContainerStatsRows(Iterable<String> rows) {
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
    final prefixMatch =
        id.length >= 12 &&
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

enum ContainerRefreshTarget { containers, images }

@freezed
abstract class ContainerState with _$ContainerState {
  const factory ContainerState({
    @Default(null) List<ContainerPs>? items,
    @Default(null) List<ContainerImg>? images,
    @Default(null) String? version,
    @Default(null) ContainerErr? containersError,
    @Default(null) ContainerErr? imagesError,
    @Default(null) String? runLog,
    @Default(ContainerType.docker) ContainerType type,
    @Default(false) bool isBusy,
  }) = _ContainerState;
}

@riverpod
class ContainerNotifier extends _$ContainerNotifier {
  final _sudoCompleters = <ContainerRefreshTarget, Completer<bool>>{
    for (final t in ContainerRefreshTarget.values) t: Completer<bool>(),
  };
  String? _cachedPassword;
  var _refreshGeneration = 0;

  /// The concurrency guard, kept off the state.
  ///
  /// `isBusy` used to serve both purposes, which meant an automatic refresh
  /// published two state changes per tick — busy, then not — and rebuilt the
  /// page each time, disabling and re-enabling every button on it, whether or
  /// not anything had actually changed.
  var _refreshing = false;
  ({ContainerRefreshTarget target, bool isAuto})? _pendingRefresh;

  @override
  ContainerState build(String userName, String hostId, BuildContext context) {
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
      containersError: null,
      imagesError: null,
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
    state = state.copyWith(isBusy: false, runLog: null);
  }

  int _resetSudoProbe() {
    for (final t in ContainerRefreshTarget.values) {
      final previous = _sudoCompleters[t];
      if (previous != null && !previous.isCompleted) previous.complete(false);
      _sudoCompleters[t] = Completer<bool>();
    }
    _pendingRefresh = null;
    // Whatever was running is now stale and will return without finishing, so
    // the guard has to be lifted here or nothing could ever refresh again.
    _refreshing = false;
    return ++_refreshGeneration;
  }

  void _queueRefresh(ContainerRefreshTarget target, bool isAuto) {
    final pending = _pendingRefresh;
    _pendingRefresh = (
      target: target,
      isAuto: pending?.target == target ? isAuto && pending!.isAuto : isAuto,
    );
  }

  bool _isStaleRefresh(int generation) {
    return generation != _refreshGeneration || !ref.mounted;
  }

  Future<void> _restartAfterServerChange(
    ContainerRefreshTarget target,
    bool isAuto,
  ) async {
    _resetSudoProbe();
    if (!ref.mounted) return;
    state = state.copyWith(isBusy: false);
    await refresh(target, isAuto: isAuto, generation: _refreshGeneration);
  }

  Future<void> _requiresSudo(
    Completer<bool> completer,
    ContainerType type,
    ContainerRefreshTarget target,
    String? containerHost,
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
      final res = await exec.run(
        _wrap(probe.exec(type), type: type, containerHost: containerHost),
      );
      if (completer.isCompleted) return;
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

  Future<void> refreshContainers({bool isAuto = false}) =>
      refresh(ContainerRefreshTarget.containers, isAuto: isAuto);

  Future<void> refreshImages({bool isAuto = false}) =>
      refresh(ContainerRefreshTarget.images, isAuto: isAuto);

  Future<void> refresh(
    ContainerRefreshTarget target, {
    bool isAuto = false,
    int? generation,
  }) async {
    if (_refreshing || state.runLog != null) {
      _queueRefresh(target, isAuto);
      return;
    }
    _refreshing = true;
    final refreshGeneration = generation ?? _refreshGeneration;
    final serverNotifier = ref.read(serverProvider(hostId).notifier);
    final spi = ref.read(serverProvider(hostId)).spi;
    bool serverChanged() => ref.read(serverProvider(hostId)).spi != spi;
    final type = state.type;
    final containerHost = Stores.container.fetch(hostId, type);
    // The error is left alone until something replaces it. Clearing it here
    // put the page back to a full-screen spinner for the length of every
    // refresh — and with auto-refresh on, a server with no runtime flashed
    // between spinner and explanation on every tick.
    //
    // An automatic refresh says nothing about being busy either: nobody asked
    // for it, so there is nobody to tell, and saying so is a state change in
    // itself.
    if (!isAuto) state = state.copyWith(isBusy: true);

    final sudo = _sudoCompleters[target]!;
    if (!sudo.isCompleted) {
      unawaited(_requiresSudo(sudo, type, target, containerHost));
    }

    final needSudo = await sudo.future;
    if (_isStaleRefresh(refreshGeneration)) return;
    if (serverChanged()) {
      await _restartAfterServerChange(target, isAuto);
      return;
    }

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

    final separator =
        '${_containerSeparatorPrefix}_'
        '${DateTime.now().microsecondsSinceEpoch}_$refreshGeneration';
    final cmd = _wrap(
      ContainerCmdType.execSelected(commands, type, separator: separator),
      sudo: needSudo,
      type: type,
      containerHost: containerHost,
    );
    late final ExecResult result;
    String raw = '';
    // Kept apart from [raw]: parsing wants stdout only, but everything that
    // explains a failure — `sh: docker: not found`, a permission denial — is
    // on stderr, and dropping it left the page quoting the separators the
    // script echoes between commands.
    String errOut = '';
    var isPodmanEmulation = false;
    final podmanBuffer = StringBuffer();
    try {
      // Asked for rather than held: a server reached over its monitor agent
      // has no connection sitting there until something needs one, and a
      // failure to open one is reported below like any other.
      final exec = await serverNotifier.ensureExec();
      if (serverChanged() || !serverNotifier.isExecCurrent(exec, spi)) {
        await _restartAfterServerChange(target, isAuto);
        return;
      }
      result = await exec.runWithSudo(
        cmd,
        password: password,
        onStderr: (data) {
          podmanBuffer.write(data);
          if (podmanBuffer.toString().contains(_podmanEmulationMsg)) {
            isPodmanEmulation = true;
          }
        },
      );
      if (serverChanged() || !serverNotifier.isExecCurrent(exec, spi)) {
        await _restartAfterServerChange(target, isAuto);
        return;
      }
      (raw, errOut) = (result.stdout, result.stderr);
      if (result.outputIncomplete) {
        if (_isStaleRefresh(refreshGeneration)) return;
        Loggers.app.warning(
          'Container refresh output incomplete '
          '(exit ${result.exitCode}, stdout ${raw.length} code units, '
          'stderr ${errOut.length} code units)',
          result.streamError,
          result.streamErrorStackTrace,
        );
        _setRefreshError(
          target,
          ContainerErr(
            type: ContainerErrType.unknown,
            message: containerExecErrorDetail(result),
          ),
        );
        await _finishRefresh(refreshGeneration);
        return;
      }
    } catch (e, trace) {
      if (_isStaleRefresh(refreshGeneration)) return;
      if (serverChanged()) {
        await _restartAfterServerChange(target, isAuto);
        return;
      }
      Loggers.app.warning('Container refresh execution failed', e, trace);
      _setRefreshError(
        target,
        // Nothing ran at all — a connection that could not be opened, an agent
        // that refused. Told apart from a command that ran and failed, which
        // is what `unknown` is for.
        ContainerErr(type: ContainerErrType.noClient, message: '$e'),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    if (_isStaleRefresh(refreshGeneration)) return;
    if (!context.mounted) {
      _pendingRefresh = null;
      _refreshing = false;
      state = state.copyWith(isBusy: false);
      return;
    }

    /// Code 127 means command not found
    if (result.exitCode == 127 ||
        errOut.contains(_dockerNotFound) ||
        raw.contains(_dockerNotFound)) {
      _setRefreshError(
        target,
        // Carries what the shell said: "not installed" is a reading of that
        // output, and it is wrong often enough — a runtime installed for
        // another account, a `DOCKER_HOST` pointing nowhere — that the user
        // should be able to see what it was.
        ContainerErr(
          type: ContainerErrType.notInstalled,
          message: containerExecErrorDetail(result),
        ),
      );
      await _finishRefresh(refreshGeneration);
      return;
    }

    /// Sudo password error
    if (needSudo && result.exitCode == kSudoPasswordRejected) {
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
    if (!result.succeeded) {
      final detail = containerExecErrorDetail(result);
      Loggers.app.warning(
        'Container refresh command failed (exit ${result.exitCode}): $detail',
        result.streamError,
        result.streamErrorStackTrace,
      );
      _setRefreshError(
        target,
        ContainerErr(type: ContainerErrType.unknown, message: detail),
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
    if (type == ContainerType.podman &&
        (errOut.contains('podman: not found') ||
            raw.contains('podman: not found'))) {
      _setRefreshError(
        target,
        ContainerErr(
          type: ContainerErrType.notInstalled,
          message: containerExecErrorDetail(result),
        ),
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

    // The runtime answered in full, so whatever was wrong last time is over.
    // Cleared here rather than at the start of a refresh, which is what kept a
    // failure on screen through a retry that only reproduced it — and here
    // rather than in the version branch below, which is skipped once the
    // version is cached, so a recovered server kept showing a dead daemon.
    _clearRefreshError(target);

    // Parse version only until it has been cached for the selected runtime.
    final verRaw = output[ContainerCmdType.version];
    if (verRaw != null) {
      try {
        final version = json.decode(verRaw)['Client']['Version'];
        state = state.copyWith(version: version);
      } catch (e, trace) {
        if (_refreshError(target) == null) {
          _setRefreshError(
            target,
            ContainerErr(type: ContainerErrType.invalidVersion, message: '$e'),
            clearData: false,
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
        if (_refreshError(target) == null) {
          _setRefreshError(
            target,
            ContainerErr(type: ContainerErrType.parsePs, message: '$e'),
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
          if (_refreshError(target) == null) {
            _setRefreshError(
              target,
              ContainerErr(type: ContainerErrType.parseStats, message: '$e'),
              clearData: false,
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
        if (_refreshError(target) == null) {
          _setRefreshError(
            target,
            ContainerErr(type: ContainerErrType.parseImages, message: '$e'),
          );
        }
        Loggers.app.warning('Container images failed', e, trace);
      }
    }
    await _finishRefresh(refreshGeneration);
  }

  Future<void> _finishRefresh(int generation) async {
    // Cleared before the staleness check: a refresh that was superseded still
    // has to let the next one start.
    _refreshing = false;
    if (_isStaleRefresh(generation)) return;
    state = state.copyWith(isBusy: false);
    await _refreshPendingIfNeeded(generation);
  }

  ContainerErr? _refreshError(ContainerRefreshTarget target) =>
      switch (target) {
        ContainerRefreshTarget.containers => state.containersError,
        ContainerRefreshTarget.images => state.imagesError,
      };

  void _clearRefreshError(ContainerRefreshTarget target) {
    state = switch (target) {
      ContainerRefreshTarget.containers => state.copyWith(
        containersError: null,
      ),
      ContainerRefreshTarget.images => state.copyWith(imagesError: null),
    };
  }

  void _setRefreshError(
    ContainerRefreshTarget target,
    ContainerErr error, {
    bool clearData = true,
  }) {
    state = switch (target) {
      ContainerRefreshTarget.containers => state.copyWith(
        items: clearData ? null : state.items,
        containersError: error,
      ),
      ContainerRefreshTarget.images => state.copyWith(
        images: clearData ? null : state.images,
        imagesError: error,
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

  Future<ContainerErr?> stop(String id) async => await run(
    'stop ${shellSingleQuote(id)}',
    refreshTarget: ContainerRefreshTarget.containers,
  );

  Future<ContainerErr?> start(String id) async => await run(
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

  Future<ContainerErr?> restart(String id) async => await run(
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
    return await run(cmd, refreshTarget: ContainerRefreshTarget.containers);
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

  /// Runs one container command, and records how it went.
  ///
  /// The pair of crumbs is here rather than inside [_run], which has seven
  /// exits — four kinds of failure, a success, and two that return early
  /// because a newer refresh has replaced this one. Recording at each would be
  /// seven call sites to keep in step; recording here is one, at the cost of
  /// reading a superseded run as a success. That case needs the user to act
  /// twice inside one round trip and is rare enough to be worth the trade,
  /// where getting six of seven right would not be.
  Future<ContainerErr?> run(
    String cmd, {
    ContainerRefreshTarget? refreshTarget = ContainerRefreshTarget.containers,
  }) async {
    // Read before the engine prefix is prepended, so the verb is what it says
    // rather than something sliced back off by the length of `type.name`.
    // `Redact.command` keeps the verb and drops the argument, which is a
    // container the user named.
    final engine = state.type.name;
    final verb = Diag.enabled ? Redact.command(cmd) : '';
    if (Diag.enabled) {
      Diag.crumb(
        SbDiag.container,
        'run',
        data: {'engine': engine, 'cmd': verb},
      );
    }

    final err = await _run(cmd, refreshTarget: refreshTarget);

    if (Diag.enabled) {
      Diag.crumb(
        SbDiag.container,
        err == null ? 'run ok' : 'run failed',
        level: err == null ? DiagLevel.info : DiagLevel.warning,
        data: {
          'engine': engine,
          'cmd': verb,
          // The kind, which is what separates "this host has no docker" from
          // "sudo was refused" from a command that simply did not work.
          if (err != null) 'reason': err.type.name,
        },
      );
    }
    return err;
  }

  Future<ContainerErr?> _run(
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

    final generation = _refreshGeneration;
    final type = state.type;
    final containerHost = Stores.container.fetch(hostId, type);

    cmd = switch (type) {
      ContainerType.docker => 'docker $cmd',
      ContainerType.podman => 'podman $cmd',
    };

    final target = refreshTarget ?? ContainerRefreshTarget.containers;
    final sudo = _sudoCompleters[target]!;
    if (!sudo.isCompleted) {
      unawaited(_requiresSudo(sudo, type, target, containerHost));
    }
    final needSudo = await sudo.future;
    if (_isStaleRefresh(generation)) return null;
    String? password;
    if (needSudo) {
      password = await _getSudoPassword();
      if (_isStaleRefresh(generation)) return null;
      if (password == null) {
        await _finishRun();
        return ContainerErr(
          type: ContainerErrType.sudoPasswordRequired,
          message: l10n.containerSudoPasswordRequired,
        );
      }
    }

    late final ExecResult result;
    void appendOutput(String data) {
      if (!_isStaleRefresh(generation)) {
        state = state.copyWith(runLog: '${state.runLog}$data');
      }
    }

    try {
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      if (_isStaleRefresh(generation)) return null;
      result = await exec.runWithSudo(
        _wrap(cmd, sudo: needSudo, type: type, containerHost: containerHost),
        password: password,
        onStdout: appendOutput,
        onStderr: appendOutput,
      );
    } catch (e, trace) {
      if (_isStaleRefresh(generation)) return null;
      Loggers.app.warning('Container command execution failed', e, trace);
      await _finishRun();
      return ContainerErr(type: ContainerErrType.unknown, message: '$e');
    }

    if (_isStaleRefresh(generation)) return null;

    if (needSudo && result.exitCode == kSudoPasswordRejected) {
      _cachedPassword = null;
      await _finishRun();
      return ContainerErr(
        type: ContainerErrType.sudoPasswordIncorrect,
        message: l10n.containerSudoPasswordIncorrect,
      );
    }
    final detail = containerExecErrorDetail(result);
    if (result.outputIncomplete) {
      await _finishRun();
      return ContainerErr(type: ContainerErrType.unknown, message: detail);
    }
    if (!result.succeeded) {
      if (result.exitCode == 127 || detail.contains(_dockerNotFound)) {
        await _finishRun();
        return ContainerErr(
          type: ContainerErrType.notInstalled,
          message: detail,
        );
      }
      await _finishRun();
      return ContainerErr(type: ContainerErrType.unknown, message: detail);
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
    final containerHost = Stores.container.fetch(hostId, type);
    final sudo = _sudoCompleters[target]!;
    if (!sudo.isCompleted) {
      unawaited(_requiresSudo(sudo, type, target, containerHost));
    }
    final needSudo = await sudo.future;
    if (_isStaleRefresh(generation)) return null;
    return _wrap(cmd, sudo: needSudo, type: type, containerHost: containerHost);
  }

  /// Wrap commands with the container runtime host environment variable.
  String _wrap(
    String cmd, {
    bool sudo = false,
    required ContainerType type,
    required String? containerHost,
  }) => buildContainerRuntimeCommand(
    command: cmd,
    type: type,
    containerHost: containerHost,
    sudo: sudo,
  );
}

const _jsonFmt = '--format "{{json .}}"';

/// What the machine said, for a user reading why a page is empty.
///
/// stderr first, since that is where a shell puts the reason. The separators
/// the script echoes between its commands are dropped: they are this app's own
/// scaffolding, and a page whose entire explanation was
/// `SrvBoxContainerSep_1786614816321254_0` twice over told the user nothing.
String? userFacingOutput(String stderr, String stdout) {
  for (final stream in [stderr, stdout]) {
    final lines = <String>[];
    // Deduplicated through a set rather than by scanning the list: several
    // commands are batched into one call, so a missing runtime says
    // `sh: docker: not found` once per command — three identical lines are
    // three attempts at the same thing, not three problems — and the stream
    // this walks can be a megabyte of distinct lines.
    final seen = <String>{};
    for (final line in stream.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith(_containerSeparatorPrefix)) continue;
      if (!seen.add(trimmed)) continue;
      lines.add(trimmed);
    }
    if (lines.isNotEmpty) return lines.join('\n');
  }
  return null;
}

/// An execution failure ready to show in the container page.
///
/// Incomplete output or a stream error means stdout may end in the middle of
/// an otherwise valid response, so it must not be presented as the reason for
/// the failure.
String containerExecErrorDetail(ExecResult result) =>
    userFacingOutput(
      result.stderr,
      !result.outputIncomplete && result.streamError == null
          ? result.stdout
          : '',
    ) ??
    '${result.streamError ?? libL10n.fail}';

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
        ContainerType.docker =>
          '${type.name} ps -a --format '
              '"{{.ID}}\\t{{.Status}}\\t{{.Names}}\\t{{.Image}}\\t'
              '{{.Label \\"com.docker.compose.project\\"}}\\t'
              '{{.Label \\"com.docker.compose.project.working_dir\\"}}"',
        ContainerType.podman =>
          '${type.name} ps -a --format '
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
    String separator = _containerSeparatorPrefix,
  }) {
    final commands = types.map((e) => e.exec(type)).join('\necho $separator\n');

    return 'sh -c \'${commands.replaceAll("'", "'\\''")}\'';
  }
}

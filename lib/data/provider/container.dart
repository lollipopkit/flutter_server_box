import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sudo_password.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/container/disk_usage.dart';
import 'package:server_box/data/model/container/image.dart';
import 'package:server_box/data/model/container/ps.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/container.dart' as ffi;

part 'container.freezed.dart';
part 'container.g.dart';

/// What a user typed as `docker run` arguments, split the way a shell would
/// without evaluating anything (`sbm_parser::container::parse_run_args`).
///
/// Throws a [FormatException] for an unterminated quote.
List<String> parseContainerRunArgs(String raw) {
  try {
    return ffi.containerParseRunArgs(raw: raw);
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('$e', raw);
  }
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
    @Default(null) ContainerDiskUsage? diskUsage,
    @Default(ContainerType.docker) ContainerType type,
    @Default(false) bool isBusy,
  }) = _ContainerState;
}

@riverpod
class ContainerNotifier extends _$ContainerNotifier {
  final _sudoCompleters = <ContainerRefreshTarget, Completer<bool>>{
    for (final t in ContainerRefreshTarget.values) t: Completer<bool>(),
  };
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

  /// The server's sudo password: the one already known (`SudoPassword`,
  /// shared with the rest of the app), else asked for — as [userName]'s, the
  /// label under the field.
  Future<String?> _getSudoPassword() async {
    if (await SudoPassword.known(hostId) case final pwd?) return pwd;
    if (!context.mounted) return null;
    return SudoPassword.ask(context, hostId, label: userName);
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
        ContainerRefreshTarget.containers => 'ps',
        ContainerRefreshTarget.images => 'images',
      };
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      final res = await exec.run(
        _wrap(
          ffi.containerCommand(runtimeName: type.name, kind: probe),
          type: type,
          containerHost: containerHost,
        ),
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

  /// Fetches `system df` on its own connection turn, outside [refresh].
  ///
  /// It feeds two numbers in the overview and nothing else, while on a host
  /// with a large image store the command walks all of it — several hundred
  /// milliseconds that has no business sitting in front of the container
  /// list. So it neither sets [ContainerState.isBusy] nor records a refresh
  /// error: a failure here leaves two slots undrawn and the page working.
  ///
  /// It also never asks for a sudo password. The dialog belongs to an action
  /// the user took, and this runs by itself on first open; where a password is
  /// already cached from a refresh it is reused, and where it is not the fetch
  /// is skipped rather than escalated.
  Future<void> refreshDiskUsage() async {
    final type = state.type;
    final containerHost = Stores.container.fetch(hostId, type);
    final sudo = _sudoCompleters[ContainerRefreshTarget.containers]!;
    final needSudo = sudo.isCompleted && await sudo.future;
    final password = needSudo ? SudoPassword.typed(hostId) : null;
    if (needSudo && password == null) return;

    try {
      final exec = await ref.read(serverProvider(hostId).notifier).ensureExec();
      final result = await exec.runWithSudo(
        _wrap(
          ffi.containerCommand(runtimeName: type.name, kind: 'df'),
          sudo: needSudo,
          type: type,
          containerHost: containerHost,
        ),
        password: password,
      );
      final usage = ffi.containerParseDiskUsage(raw: result.stdout);
      if (usage != null) {
        state = state.copyWith(diskUsage: ContainerDiskUsage.fromFfi(usage));
      }
    } catch (e, trace) {
      Loggers.app.warning('Container disk usage failed', e, trace);
    }
  }

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

    /// If sudo is required and auto refresh is enabled, skip the refresh
    /// unless a password was typed this session: it would ask again and
    /// again. The typed one is dropped on a refusal, so this does not keep
    /// sending a wrong one.
    if (needSudo && isAuto && SudoPassword.typed(hostId) == null) {
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
        if (state.version == null) 'version',
        'ps',
        if (includeStats) 'stats',
      ],
      ContainerRefreshTarget.images => [
        if (state.version == null) 'version',
        'images',
      ],
    };

    // Fresh per refresh, so an answer to the previous one cannot be read as
    // an answer to this one.
    final separator =
        '${ffi.containerSeparatorPrefix()}_'
        '${DateTime.now().microsecondsSinceEpoch}_$refreshGeneration';
    final cmd = _wrap(
      ffi.containerBatchCommand(
        runtimeName: type.name,
        kinds: commands,
        separator: separator,
      ),
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
    try {
      // Asked for rather than held: a server reached over its monitor agent
      // has no connection sitting there until something needs one, and a
      // failure to open one is reported below like any other.
      final exec = await serverNotifier.ensureExec();
      if (serverChanged() || !serverNotifier.isExecCurrent(exec, spi)) {
        await _restartAfterServerChange(target, isAuto);
        return;
      }
      result = await exec.runWithSudo(cmd, password: password);
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

    // Exit 127, a shell's "command not found", or Podman's own "not found".
    if (ffi.containerIsNotInstalled(
      runtimeName: type.name,
      stdout: raw,
      stderr: errOut,
      exitCode: result.exitCode ?? -1,
    )) {
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
      SudoPassword.forget(hostId);
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

    // Before parsing: a `podman` answering as `docker` answers every command
    // successfully, so nothing downstream would notice.
    if (ffi.containerIsPodmanEmulation(stderr: errOut)) {
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

    // Every command must contribute one segment; otherwise results cannot be
    // matched safely to command types.
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
    final output = <String, String>{
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
    final verRaw = output['version'];
    if (verRaw != null) {
      final version = ffi.containerParseVersion(raw: verRaw);
      if (version != null) {
        state = state.copyWith(version: version);
      } else {
        if (_refreshError(target) == null) {
          _setRefreshError(
            target,
            ContainerErr(
              type: ContainerErrType.invalidVersion,
              message: verRaw.trim().isEmpty ? libL10n.empty : verRaw.trim(),
            ),
            clearData: false,
          );
        }
        Loggers.app.warning('Container version unreadable: $verRaw');
      }
    }

    if (target == ContainerRefreshTarget.containers) {
      // ps, with each container's stats row when they were asked for. Rows
      // either cannot read are skipped rather than emptying the list.
      try {
        final items = await ffi.containerParsePs(
          runtimeName: type.name,
          ps: output['ps']!,
          stats: output['stats'],
          version: state.version,
        );
        state = state.copyWith(items: items.map(ContainerPs.fromFfi).toList());
      } catch (e, trace) {
        if (_refreshError(target) == null) {
          _setRefreshError(
            target,
            ContainerErr(type: ContainerErrType.parsePs, message: '$e'),
          );
        }
        Loggers.app.warning('Container ps failed', e, trace);
      }
    } else {
      // Parse images
      try {
        final images = await ffi.containerParseImages(
          runtimeName: type.name,
          raw: output['images']!,
        );
        state = state.copyWith(
          images: images.map(ContainerImg.fromFfi).toList(),
        );
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

  String get _runtime => state.type.name;

  Future<ContainerErr?> _action(
    String action, {
    String? id,
    bool force = false,
    ContainerRefreshTarget? refreshTarget = ContainerRefreshTarget.containers,
  }) => run(
    ffi.containerActionCommand(
      runtimeName: _runtime,
      action: action,
      id: id,
      force: force,
    ),
    refreshTarget: refreshTarget,
  );

  Future<ContainerErr?> stop(String id) => _action('stop', id: id);

  Future<ContainerErr?> start(String id) => _action('start', id: id);

  Future<ContainerErr?> delete(String id, bool force) =>
      _action('remove', id: id, force: force);

  Future<ContainerErr?> restart(String id) => _action('restart', id: id);

  Future<ContainerErr?> pruneContainers() => _action('prune_containers');

  Future<ContainerErr?> pruneVolumes() =>
      _action('prune_volumes', refreshTarget: null);

  Future<ContainerErr?> removeImage(String id) => run(
    ffi.containerImageRemoveCommand(runtimeName: _runtime, id: id),
    refreshTarget: ContainerRefreshTarget.images,
  );

  Future<ContainerErr?> pullImage(String reference) => run(
    ffi.containerImagePullCommand(runtimeName: _runtime, reference: reference),
    refreshTarget: ContainerRefreshTarget.images,
  );

  /// The command [pruneImages] runs, for the dialog that asks first.
  String imagePruneCommand({bool allUnused = false}) =>
      ffi.containerImagePruneCommand(
        runtimeName: _runtime,
        allUnused: allUnused,
      );

  /// The command [pruneSystem] runs, for the dialog that asks first.
  String systemPruneCommand({
    bool allUnusedImages = false,
    bool includeVolumes = false,
  }) => ffi.containerSystemPruneCommand(
    runtimeName: _runtime,
    allUnusedImages: allUnusedImages,
    includeVolumes: includeVolumes,
  );

  /// `run -itd`, every part quoted; [extraArgs] from [parseContainerRunArgs].
  String runCommand({
    required String image,
    required String name,
    required List<String> extraArgs,
  }) => ffi.containerRunCommand(
    runtimeName: _runtime,
    image: image,
    name: name,
    extraArgs: extraArgs,
  );

  String logsCommand(String id) =>
      ffi.containerLogsCommand(runtimeName: _runtime, id: id);

  String shellCommand(String id) =>
      ffi.containerShellCommand(runtimeName: _runtime, id: id);

  Future<ContainerErr?> pruneImages({bool allUnused = false}) => run(
    imagePruneCommand(allUnused: allUnused),
    refreshTarget: ContainerRefreshTarget.images,
  );

  Future<ContainerErr?> pruneSystem({
    bool allUnusedImages = false,
    bool includeVolumes = false,
  }) async {
    final result = await run(
      systemPruneCommand(
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
    // The runtime's name is cut off first, so the verb is what
    // `Redact.command` keeps; it drops the argument, which is a container the
    // user named.
    final engine = state.type.name;
    final verb = Diag.enabled
        ? Redact.command(
            cmd.startsWith('$engine ') ? cmd.substring(engine.length + 1) : cmd,
          )
        : '';
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
      SudoPassword.forget(hostId);
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
      if (ffi.containerIsNotInstalled(
        runtimeName: type.name,
        stdout: '',
        stderr: detail,
        exitCode: result.exitCode ?? -1,
      )) {
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
  }) => ffi.containerRuntimeCommand(
    command: cmd,
    runtimeName: type.name,
    containerHost: containerHost,
    sudo: sudo,
  );
}

/// An execution failure ready to show in the container page: what the machine
/// said, stderr first, without the batch's markers.
///
/// Incomplete output or a stream error means stdout may end in the middle of
/// an otherwise valid response, so it must not be presented as the reason for
/// the failure.
String containerExecErrorDetail(ExecResult result) =>
    ffi.containerUserFacingOutput(
      stderr: result.stderr,
      stdout: !result.outputIncomplete && result.streamError == null
          ? result.stdout
          : '',
    ) ??
    '${result.streamError ?? libL10n.fail}';

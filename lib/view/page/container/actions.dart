part of 'container.dart';

extension on _ContainerPageState {
  /// The notifier for the container state.
  ContainerNotifier get _containerNotifier => ref.read(_provider.notifier);

  /// Watch the current state of the container.
  ContainerState get _containerState => ref.watch(_provider);

  bool get _containerActionsBusy =>
      _containerState.isBusy || _containerState.runLog != null;

  String _errorMessage(String? message) {
    final trimmed = message?.trim();
    return trimmed?.isNotEmpty == true ? trimmed! : libL10n.fail;
  }

  /// Execute a container action with loading dialog and error handling.
  Future<void> _execContainerAction(
    Future<ContainerErr?> Function() action,
  ) async {
    final (result, err) = await context.showLoadingDialog(fn: action);
    if (!mounted) return;
    if (err != null || result != null) {
      final e = result?.message ?? err?.toString();
      context.showRoundDialog(
        title: libL10n.error,
        child: Text(_errorMessage(e)),
      );
    } else {
      context.showSnackBar(libL10n.success);
    }
  }

  Future<void> _showAddFAB() async {
    final imageCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final argsCtrl = TextEditingController();
    await context.showRoundDialog(
      title: l10n.newContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Input(
            autoFocus: true,
            type: TextInputType.text,
            label: l10n.image,
            hint: 'xxx:1.1',
            controller: imageCtrl,
            suggestion: false,
          ),
          Input(
            type: TextInputType.text,
            controller: nameCtrl,
            label: libL10n.name,
            hint: 'xxx',
            suggestion: false,
          ),
          Input(
            type: TextInputType.text,
            controller: argsCtrl,
            label: l10n.extraArgs,
            hint: '-p 2222:22 -v ~/.xxx/:/xxx',
            suggestion: false,
          ),
        ],
      ),
      actions: Btn.ok(
        onTap: () async {
          try {
            final extraArgs = parseContainerRunArgs(argsCtrl.text.trim());
            context.popDialog();
            await _showAddCmdPreview(
              buildContainerRunCmd(
                image: imageCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                extraArgs: extraArgs,
              ),
            );
          } on FormatException {
            context.showSnackBar(libL10n.invalid);
          }
        },
      ).toList,
    );
    imageCtrl.dispose();
    nameCtrl.dispose();
    argsCtrl.dispose();
  }

  Future<void> _showPruneDialog({
    required String title,
    String? message,
    required Future<ContainerErr?> Function() onConfirm,
  }) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: title,
      child: Text(message ?? libL10n.askContinue('${libL10n.prune} $title')),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed == true && mounted) await _execContainerAction(onConfirm);
  }

  Future<void> _showImagePruneDialog() async {
    final images = _containerState.images ?? const <ContainerImg>[];
    final danglingCount = images.where((image) => image.isDangling).length;
    final containerImages = _containerState.items?.map((item) => item.image);
    final unusedTaggedCount = containerImages == null
        ? null
        : countUnusedTaggedImages(images, containerImages);
    var allUnused = false;
    final confirmed = await context.showRoundDialog<bool>(
      title: l10n.pruneImages,
      child: StatefulBuilder(
        builder: (_, setState) {
          return SingleChildScrollView(
            child: ContainerImagePruneOptionsView(
              danglingCount: danglingCount,
              unusedTaggedCount: unusedTaggedCount,
              allUnused: allUnused,
              onAllUnusedChanged: (value) =>
                  setState(() => allUnused = value),
              commandPreview: _runtimePruneCommand(
                buildContainerImagePruneCmd(allUnused: allUnused),
              ),
            ),
          );
        },
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed == true && mounted) {
      await _execContainerAction(
        () => _containerNotifier.pruneImages(allUnused: allUnused),
      );
    }
  }

  Future<void> _showSystemPruneDialog() async {
    var allUnusedImages = false;
    var includeVolumes = false;
    final confirmed = await context.showRoundDialog<bool>(
      title: l10n.pruneUnusedData,
      child: StatefulBuilder(
        builder: (_, setState) {
          return SingleChildScrollView(
            child: ContainerSystemPruneOptionsView(
              allUnusedImages: allUnusedImages,
              includeVolumes: includeVolumes,
              onAllUnusedImagesChanged: (value) =>
                  setState(() => allUnusedImages = value),
              onIncludeVolumesChanged: (value) =>
                  setState(() => includeVolumes = value),
              commandPreview: _runtimePruneCommand(
                buildContainerSystemPruneCmd(
                  allUnusedImages: allUnusedImages,
                  includeVolumes: includeVolumes,
                ),
              ),
            ),
          );
        },
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed == true && mounted) {
      await _execContainerAction(
        () => _containerNotifier.pruneSystem(
          allUnusedImages: allUnusedImages,
          includeVolumes: includeVolumes,
        ),
      );
    }
  }

  String _runtimePruneCommand(String command) {
    return '${_containerState.type.name} $command';
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await context.showRoundDialog(
      title: libL10n.preview,
      child: Text(cmd),
      actions: [
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.popDialog();
            await _execContainerAction(() => _containerNotifier.run(cmd));
          },
          child: Text(libL10n.run),
        ),
      ],
    );
  }

  Future<void> _showEditHostDialog() async {
    final id = widget.args.spi.id;
    final host = Stores.container.fetch(id, _containerState.type);
    final hostVariable = _containerState.type == ContainerType.podman
        ? 'CONTAINER_HOST'
        : 'DOCKER_HOST';
    final ctrl = TextEditingController(text: host);
    try {
      await context.showRoundDialog(
        title: libL10n.edit,
        child: Input(
          maxLines: 2,
          controller: ctrl,
          onSubmitted: _onSaveContainerHost,
          hint: hostVariable == 'CONTAINER_HOST'
              ? r'$XDG_RUNTIME_DIR/podman/podman.sock'
              : 'unix:///run/user/1000/docker.sock',
          suggestion: false,
        ),
        actions: Btn.ok(onTap: () => _onSaveContainerHost(ctrl.text)).toList,
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _onSaveContainerHost(String val) {
    context.pop();
    Stores.container.put(widget.args.spi.id, _containerState.type, val.trim());
    _containerNotifier.resetSudoProbe();
    unawaited(_refreshContainerTab(_lastResourceTab));
  }

  void _showImageRmDialog(ContainerImg e) {
    final id = e.id;
    if (id == null || id.isEmpty) {
      context.showSnackBar(libL10n.empty);
      return;
    }
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} Image(${e.repository})'),
      ),
      actions: Btn.ok(
        onTap: () async {
          context.popDialog();
          final result = await _containerNotifier.run(
            'rmi ${shellSingleQuote(id)} -f',
            refreshTarget: ContainerRefreshTarget.images,
          );
          if (result != null) {
            if (mounted) context.showSnackBar(_errorMessage(result.message));
          }
        },
        red: true,
      ).toList,
    );
  }

  void _onTapImageMenu(ImageMenu item, ContainerImg e) {
    switch (item) {
      case ImageMenu.pull:
        final repo = e.repository;
        final tag = e.tag;
        if (e.isDangling ||
            repo == null ||
            repo.trim().isEmpty ||
            repo == '<none>' ||
            tag == null ||
            tag.trim().isEmpty ||
            tag == '<none>') {
          context.showSnackBar(libL10n.empty);
          return;
        }
        final imageRef = '$repo:$tag';
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue('${l10n.pull} ${l10n.image}($imageRef)'),
          ),
          actions: Btn.ok(
            onTap: () async {
              context.popDialog();
              await _execContainerAction(
                () => _containerNotifier.run(
                  'pull ${shellSingleQuote(imageRef)}',
                  refreshTarget: ContainerRefreshTarget.images,
                ),
              );
            },
          ).toList,
        );
        break;
      case ImageMenu.rm:
        _showImageRmDialog(e);
        break;
    }
  }

  void _onTapMoreBtn(ContainerMenu item, ContainerPs dItem) async {
    final id = dItem.id;
    if (id == null) {
      context.showSnackBar('Id is null');
      return;
    }
    switch (item) {
      case ContainerMenu.rm:
        var force = false;
        context.showRoundDialog(
          title: libL10n.attention,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                libL10n.askContinue(
                  '${libL10n.delete} Container(${dItem.name})',
                ),
              ),
              UIs.height13,
              Row(
                children: [
                  StatefulBuilder(
                    builder: (_, setState) {
                      return Checkbox(
                        value: force,
                        onChanged: (val) =>
                            setState(() => force = val ?? false),
                      );
                    },
                  ),
                  Text(libL10n.force),
                ],
              ),
            ],
          ),
          actions: Btn.ok(
            onTap: () async {
              context.popDialog();
              await _execContainerAction(
                () => _containerNotifier.delete(id, force),
              );
            },
          ).toList,
        );
        break;
      case ContainerMenu.start:
        await _execContainerAction(() => _containerNotifier.start(id));
        break;
      case ContainerMenu.stop:
        await _execContainerAction(() => _containerNotifier.stop(id));
        break;
      case ContainerMenu.restart:
        await _execContainerAction(() => _containerNotifier.restart(id));
        break;
      case ContainerMenu.logs:
        final cmd =
            '${_containerState.type.name} logs -f --tail 100 ${shellSingleQuote(id)}';
        final initCmd = await _containerNotifier.prepareInteractiveCommand(cmd);
        if (!mounted || initCmd == null) return;
        final args = SshPageArgs(
          spi: widget.args.spi,
          initCmd: initCmd,
        );
        SSHPage.route.go(context, args);
        break;
      case ContainerMenu.terminal:
        final cmd =
            '${_containerState.type.name} exec -it ${shellSingleQuote(id)} sh -c "command -v bash && exec bash || command -v ash && exec ash || exec sh"';
        final initCmd = await _containerNotifier.prepareInteractiveCommand(cmd);
        if (!mounted || initCmd == null) return;
        final args = SshPageArgs(
          spi: widget.args.spi,
          initCmd: initCmd,
        );
        SSHPage.route.go(context, args);
        break;
    }
  }

  Future<void> _openMergedLogs(String project, String? workingDir) async {
    if (workingDir == null || workingDir.isEmpty) return;
    final runtime = _containerState.type.name;
    final projectQuoted = shellSingleQuote(project);
    final cmd = '$runtime compose -p $projectQuoted logs --follow --tail 300';
    final prepared = await _containerNotifier.prepareInteractiveCommand(cmd);
    if (!mounted || prepared == null) return;
    final initCmd = 'cd ${shellSingleQuote(workingDir)} && $prepared';
    SSHPage.route.go(
      context,
      SshPageArgs(spi: widget.args.spi, initCmd: initCmd),
    );
  }

  void _initAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (!Stores.setting.containerAutoRefresh.fetch()) return;
    final duration = serverStatusRefreshInterval();
    if (duration == null) return;
    _autoRefreshTimer = Timer.periodic(duration, (timer) {
      if (mounted) {
        unawaited(_refreshCurrentContainerTab(isAuto: true));
      } else {
        timer.cancel();
      }
    });
  }

  void _onContainerTabChanged() {
    final index = _tabCtrl.index;
    if (index == _lastTabIndex) return;
    _lastTabIndex = index;
    final tab = _ContainerTabs.values[index];
    if (tab != _ContainerTabs.settings) _lastResourceTab = tab;
    unawaited(_refreshContainerTab(tab));
  }

  Future<void> _refreshCurrentContainerTab({bool isAuto = false}) {
    return _refreshContainerTab(
      _ContainerTabs.values[_tabCtrl.index],
      isAuto: isAuto,
    );
  }

  Future<void> _refreshContainerTab(
    _ContainerTabs tab, {
    bool isAuto = false,
    bool showLoading = false,
  }) async {
    final Future<void> Function()? action = switch (tab) {
      _ContainerTabs.ps => () =>
          _containerNotifier.refreshContainers(isAuto: isAuto),
      _ContainerTabs.images => () =>
          _containerNotifier.refreshImages(isAuto: isAuto),
      _ContainerTabs.settings => null,
    };
    if (action == null) return;
    if (showLoading) {
      await context.showLoadingDialog(fn: action);
    } else {
      await action();
    }
  }
}

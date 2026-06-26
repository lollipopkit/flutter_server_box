part of 'container.dart';

extension on _ContainerPageState {
  /// The notifier for the container state.
  ContainerNotifier get _containerNotifier => ref.read(_provider.notifier);

  /// Watch the current state of the container.
  ContainerState get _containerState => ref.watch(_provider);

  String _errorMessage(String? message) {
    final trimmed = message?.trim();
    return trimmed?.isNotEmpty == true ? trimmed! : libL10n.fail;
  }

  /// Execute a container action with loading dialog and error handling.
  Future<void> _execContainerAction(Future<ContainerErr?> Function() action) async {
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
          context.pop();
          await _showAddCmdPreview(
            _buildAddCmd(
              imageCtrl.text.trim(),
              nameCtrl.text.trim(),
              argsCtrl.text.trim(),
            ),
          );
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
    await context.showRoundDialog(
      title: title,
      child: Text(message ?? libL10n.askContinue('${libL10n.prune} $title')),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          await _execContainerAction(onConfirm);
        },
        red: true,
      ).toList,
    );
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await context.showRoundDialog(
      title: libL10n.preview,
      child: Text(cmd),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.pop();
            await _execContainerAction(() => _containerNotifier.run(cmd));
          },
          child: Text(libL10n.run),
        ),
      ],
    );
  }

  Future<void> _showEditHostDialog() async {
    final id = widget.args.spi.id;
    final host = Stores.container.fetch(id);
    final ctrl = TextEditingController(text: host);
    await context.showRoundDialog(
      title: libL10n.edit,
      child: Input(
        maxLines: 2,
        controller: ctrl,
        onSubmitted: _onSaveDockerHost,
        hint: 'unix:///run/user/1000/docker.sock',
        suggestion: false,
      ),
      actions: Btn.ok(onTap: () => _onSaveDockerHost(ctrl.text)).toList,
    );
  }

  void _onSaveDockerHost(String val) {
    context.pop();
    Stores.container.put(widget.args.spi.id, val.trim());
    _containerNotifier.refresh();
  }

  void _showImageRmDialog(ContainerImg e) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} Image(${e.repository})'),
      ),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          final result = await _containerNotifier.run('rmi ${e.id} -f');
          if (result != null) {
            context.showSnackBar(_errorMessage(result.message));
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
        if (repo == null) {
          context.showSnackBar(libL10n.empty);
          return;
        }
        final tag = e.tag ?? 'latest';
        final imageRef = '$repo:$tag';
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue('${l10n.pull} ${l10n.image}($imageRef)'),
          ),
          actions: Btn.ok(
            onTap: () async {
              context.pop();
              await _execContainerAction(() => _containerNotifier.run('pull $imageRef'));
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
              context.pop();
              await _execContainerAction(() => _containerNotifier.delete(id, force));
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
        final args = SshPageArgs(
          spi: widget.args.spi,
          initCmd:
              '${switch (_containerState.type) {
                ContainerType.podman => 'podman',
                ContainerType.docker => 'docker',
              }} logs -f --tail 100 ${dItem.id}',
        );
        SSHPage.route.go(context, args);
        break;
      case ContainerMenu.terminal:
        final args = SshPageArgs(
          spi: widget.args.spi,
          initCmd:
              '${switch (_containerState.type) {
                ContainerType.podman => 'podman',
                ContainerType.docker => 'docker',
              }} exec -it ${dItem.id} sh -c "command -v bash && exec bash || command -v ash && exec ash || exec sh"',
        );
        SSHPage.route.go(context, args);
        break;
    }
  }

  void _initAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (!Stores.setting.containerAutoRefresh.fetch()) return;
    final duration = serverStatusRefreshInterval();
    if (duration == null) return;
    _autoRefreshTimer = Timer.periodic(duration, (timer) {
      if (mounted) {
        _containerNotifier.refresh(isAuto: true);
      } else {
        timer.cancel();
      }
    });
  }
}

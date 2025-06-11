part of 'container.dart';

extension on _ContainerPageState {
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
            _buildAddCmd(imageCtrl.text.trim(), nameCtrl.text.trim(), argsCtrl.text.trim()),
          );
        },
      ).toList,
    );
  }

  Future<void> _showPruneDialog({
    required String title,
    String? message,
    required Future<ContainerErr?> Function() onConfirm,
  }) async {
    await context.showRoundDialog(
      title: title,
      child: Text(message ?? libL10n.askContinue('${l10n.prune} $title')),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          final (result, err) = await context.showLoadingDialog(fn: onConfirm);
          if (err != null || result != null) {
            final e = result?.message ?? err?.toString();
            context.showRoundDialog(title: libL10n.error, child: Text(e.toString()));
          } else {
            context.showSnackBar(libL10n.success);
          }
        },
        red: true,
      ).toList,
    );
  }

  Future<void> _showAddCmdPreview(String cmd) async {
    await context.showRoundDialog(
      title: l10n.preview,
      child: Text(cmd),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.pop();

            final (result, err) = await context.showLoadingDialog(fn: () => _container.run(cmd));
            if (err != null || result != null) {
              final e = result?.message ?? err?.toString();
              context.showRoundDialog(title: libL10n.error, child: Text(e.toString()));
            }
          },
          child: Text(l10n.run),
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
    _container.refresh();
  }

  void _showImageRmDialog(ContainerImg e) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('${libL10n.delete} Image(${e.repository})')),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          final result = await _container.run('rmi ${e.id} -f');
          if (result != null) {
            context.showSnackBar(result.message ?? 'null');
          }
        },
        red: true,
      ).toList,
    );
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
              Text(libL10n.askContinue('${libL10n.delete} Container(${dItem.name})')),
              UIs.height13,
              Row(
                children: [
                  StatefulBuilder(
                    builder: (_, setState) {
                      return Checkbox(value: force, onChanged: (val) => setState(() => force = val ?? false));
                    },
                  ),
                  Text(l10n.force),
                ],
              ),
            ],
          ),
          actions: Btn.ok(
            onTap: () async {
              context.pop();

              final (result, err) = await context.showLoadingDialog(fn: () => _container.delete(id, force));
              if (err != null || result != null) {
                final e = result?.message ?? err?.toString();
                context.showRoundDialog(title: libL10n.error, child: Text(e ?? 'null'));
              }
            },
          ).toList,
        );
        break;
      case ContainerMenu.start:
        final (result, err) = await context.showLoadingDialog(fn: () => _container.start(id));
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(title: libL10n.error, child: Text(e ?? 'null'));
        }
        break;
      case ContainerMenu.stop:
        final (result, err) = await context.showLoadingDialog(fn: () => _container.stop(id));
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(title: libL10n.error, child: Text(e ?? 'null'));
        }
        break;
      case ContainerMenu.restart:
        final (result, err) = await context.showLoadingDialog(fn: () => _container.restart(id));
        if (err != null || result != null) {
          final e = result?.message ?? err?.toString();
          context.showRoundDialog(title: libL10n.error, child: Text(e ?? 'null'));
        }
        break;
      case ContainerMenu.logs:
        final args = SshPageArgs(
          spi: widget.args.spi,
          initCmd:
              '${switch (_container.type) {
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
              '${switch (_container.type) {
                ContainerType.podman => 'podman',
                ContainerType.docker => 'docker',
              }} exec -it ${dItem.id} sh',
        );
        SSHPage.route.go(context, args);
        break;
    }
  }

  void _initAutoRefresh() {
    if (Stores.setting.containerAutoRefresh.fetch()) {
      Timer.periodic(Duration(seconds: Stores.setting.serverStatusUpdateInterval.fetch()), (timer) {
        if (mounted) {
          _container.refresh(isAuto: true);
        } else {
          timer.cancel();
        }
      });
    }
  }
}

part of 'edit.dart';

extension _Actions on _ServerEditPageState {
  void _onTapSSHImport() async {
    try {
      final servers = await SSHConfig.parseConfig();
      if (servers.isEmpty) {
        context.showSnackBar(l10n.sshConfigNoServers);
        return;
      }

      dprint('Parsed ${servers.length} servers from SSH config');
      await _processSSHServers(servers);
      dprint('Finished processing SSH config servers');
    } catch (e, s) {
      _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  void _handleImportSSHCfgPermissionIssue(Object e, StackTrace s) async {
    dprint('Error importing SSH config: $e');
    // Check if it's a permission error and offer file picker as fallback
    if (e is PathAccessException ||
        e.toString().contains('Operation not permitted')) {
      final useFilePicker = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigPermissionDenied),
            const SizedBox(height: 8),
            Text(l10n.sshConfigManualSelect),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      if (useFilePicker == true) {
        await _onTapSSHImportWithFilePicker();
      }
    } else {
      context.showErrDialog(e, s);
    }
  }

  Future<void> _processSSHServers(List<Spi> servers) async {
    final deduplicated = ServerDeduplication.deduplicateServers(servers);
    final resolved = ServerDeduplication.resolveNameConflicts(deduplicated);
    final summary = ServerDeduplication.getImportSummary(servers, resolved);

    if (!summary.hasItemsToImport) {
      context.showSnackBar(l10n.sshConfigAllExist('${summary.duplicates}'));
      return;
    }

    final shouldImport = await context.showRoundDialog<bool>(
      title: l10n.sshConfigImport,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFoundServers('${summary.total}')),
            if (summary.hasDuplicates)
              Text(
                l10n.sshConfigDuplicatesSkipped('${summary.duplicates}'),
                style: UIs.textGrey,
              ),
            Text(l10n.sshConfigServersToImport('${summary.toImport}')),
            const SizedBox(height: 16),
            ...resolved.map(
              (s) => Text('• ${s.name} (${s.user}@${s.ip}:${s.port})'),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );

    if (shouldImport == true) {
      for (final server in resolved) {
        ref.read(serversNotifierProvider.notifier).addServer(server);
      }
      context.showSnackBar(l10n.sshConfigImported('${resolved.length}'));
    }
  }

  Future<void> _onTapSSHImportWithFilePicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: 'SSH ${libL10n.select}',
      );

      if (result?.files.single.path case final path?) {
        final servers = await SSHConfig.parseConfig(path);
        if (servers.isEmpty) {
          context.showSnackBar(l10n.sshConfigNoServers);
          return;
        }

        await _processSSHServers(servers);
      }
    } catch (e, s) {
      context.showErrDialog(e, s);
    }
  }

  void _onTapCustomItem() async {
    final res = await KvEditor.route.go(
      context,
      KvEditorArgs(data: _customCmds.value),
    );
    if (res == null) return;
    _customCmds.value = res;
  }

  void _onTapDisabledCmdTypes() async {
    final allCmdTypes = ShellCmdType.all;

    // [TimeSeq] depends on the `time` cmd type, so it should be removed from the list
    allCmdTypes.remove(StatusCmdType.time);

    await _showCmdTypesDialog(allCmdTypes);
  }

  void _onSave() async {
    if (_ipController.text.isEmpty) {
      context.showSnackBar('${libL10n.empty} ${l10n.host}');
      return;
    }

    if (_keyIdx.value == null && _passwordController.text.isEmpty) {
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(libL10n.askContinue(l10n.useNoPwd)),
        actions: Btnx.cancelRedOk,
      );
      if (ok != true) return;
    }

    // If [_pubKeyIndex] is -1, it means that the user has not selected
    if (_keyIdx.value == -1) {
      context.showSnackBar(libL10n.empty);
      return;
    }
    if (_usernameController.text.isEmpty) {
      _usernameController.text = 'root';
    }
    if (_portController.text.isEmpty) {
      _portController.text = '22';
    }
    final customCmds = _customCmds.value;
    final custom = ServerCustom(
      pveAddr: _pveAddrCtrl.text.selfNotEmptyOrNull,
      pveIgnoreCert: _pveIgnoreCert.value,
      cmds: customCmds.isEmpty ? null : customCmds,
      preferTempDev: _preferTempDevCtrl.text.selfNotEmptyOrNull,
      logoUrl: _logoUrlCtrl.text.selfNotEmptyOrNull,
      netDev: _netDevCtrl.text.selfNotEmptyOrNull,
      scriptDir: _scriptDirCtrl.text.selfNotEmptyOrNull,
    );

    final wolEmpty =
        _wolMacCtrl.text.isEmpty &&
        _wolIpCtrl.text.isEmpty &&
        _wolPwdCtrl.text.isEmpty;
    final wol = wolEmpty
        ? null
        : WakeOnLanCfg(
            mac: _wolMacCtrl.text,
            ip: _wolIpCtrl.text,
            pwd: _wolPwdCtrl.text.selfNotEmptyOrNull,
          );
    if (wol != null) {
      final wolValidation = wol.validate();
      if (!wolValidation.$2) {
        context.showSnackBar('${libL10n.fail}: ${wolValidation.$1}');
        return;
      }
    }

    final spi = Spi(
      name: _nameController.text.isEmpty
          ? _ipController.text
          : _nameController.text,
      ip: _ipController.text,
      port: int.parse(_portController.text),
      user: _usernameController.text,
      pwd: _passwordController.text.selfNotEmptyOrNull,
      keyId: _keyIdx.value != null
          ? ref
                .read(privateKeyNotifierProvider)
                .keys
                .elementAt(_keyIdx.value!)
                .id
          : null,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      alterUrl: _altUrlController.text.selfNotEmptyOrNull,
      autoConnect: _autoConnect.value,
      jumpId: _jumpServer.value,
      custom: custom,
      wolCfg: wol,
      envs: _env.value.isEmpty ? null : _env.value,
      id: widget.args?.spi.id ?? ShortId.generate(),
      customSystemType: _systemType.value,
      disabledCmdTypes: _disabledCmdTypes.value.isEmpty
          ? null
          : _disabledCmdTypes.value.toList(),
    );

    if (this.spi == null) {
      final existsIds = ServerStore.instance.box.keys;
      if (existsIds.contains(spi.id)) {
        context.showSnackBar('${l10n.sameIdServerExist}: ${spi.id}');
        return;
      }
      ref.read(serversNotifierProvider.notifier).addServer(spi);
    } else {
      ref.read(serversNotifierProvider.notifier).updateServer(this.spi!, spi);
    }

    context.pop();
  }
}

extension _Utils on _ServerEditPageState {
  void _checkSSHConfigImport() async {
    final prop = Stores.setting.firstTimeReadSSHCfg;
    // Only check if it's first time and user hasn't disabled it
    if (!prop.fetch()) return;

    try {
      // Check if SSH config exists
      final (_, configExists) = SSHConfig.configExists();
      if (!configExists) return;

      // Ask for permission
      final hasPermission = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFound),
            UIs.height7,
            Text(l10n.sshConfigImportPermission),
            UIs.height7,
            Text(l10n.sshConfigImportHelp, style: UIs.textGrey),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      prop.put(false);

      if (hasPermission == true) {
        // Parse and import SSH config
        final servers = await SSHConfig.parseConfig();
        if (servers.isEmpty) {
          context.showSnackBar(l10n.sshConfigNoServers);
          return;
        }

        final deduplicated = ServerDeduplication.deduplicateServers(servers);
        final resolved = ServerDeduplication.resolveNameConflicts(deduplicated);
        final summary = ServerDeduplication.getImportSummary(servers, resolved);

        if (!summary.hasItemsToImport) {
          context.showSnackBar(l10n.sshConfigAllExist('${summary.duplicates}'));
          return;
        }

        // Import without asking again since user already gave permission
        for (final server in resolved) {
          ref.read(serversNotifierProvider.notifier).addServer(server);
        }
        context.showSnackBar(l10n.sshConfigImported('${resolved.length}'));
      }
    } catch (e, s) {
      _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  Future<void> _showCmdTypesDialog(Set<ShellCmdType> allCmdTypes) {
    return context.showRoundDialog(
      title: '${libL10n.disabled} ${l10n.cmd}',
      child: SizedBox(
        width: 270,
        child: _disabledCmdTypes.listenVal((disabled) {
          return ListView.builder(
            itemCount: allCmdTypes.length,
            itemExtent: 50,
            itemBuilder: (context, index) {
              final cmdType = allCmdTypes.elementAtOrNull(index);
              if (cmdType == null) return UIs.placeholder;
              final display = cmdType.displayName;
              return ListTile(
                leading: Icon(cmdType.sysType.icon, size: 20),
                title: Text(cmdType.name, style: const TextStyle(fontSize: 16)),
                trailing: Checkbox(
                  value: disabled.contains(display),
                  onChanged: (value) {
                    if (value == null) return;
                    if (value) {
                      _disabledCmdTypes.value.add(display);
                    } else {
                      _disabledCmdTypes.value.remove(display);
                    }
                    _disabledCmdTypes.notify();
                  },
                ),
                onTap: () {
                  final isDisabled = disabled.contains(display);
                  if (isDisabled) {
                    _disabledCmdTypes.value.remove(display);
                  } else {
                    _disabledCmdTypes.value.add(display);
                  }
                  _disabledCmdTypes.notify();
                },
              );
            },
          );
        }),
      ),
      actions: Btnx.oks,
    );
  }

  void _initWithSpi(Spi spi) {
    _nameController.text = spi.name;
    _ipController.text = spi.ip;
    _portController.text = spi.port.toString();
    _usernameController.text = spi.user;
    if (spi.keyId == null) {
      _passwordController.text = spi.pwd ?? '';
    } else {
      _keyIdx.value = ref
          .read(privateKeyNotifierProvider)
          .keys
          .indexWhere((e) => e.id == spi.keyId);
    }

    /// List in dart is passed by pointer, so you need to copy it here
    _tags.value = spi.tags?.toSet() ?? {};

    _altUrlController.text = spi.alterUrl ?? '';
    _autoConnect.value = spi.autoConnect;
    _jumpServer.value = spi.jumpId;

    final custom = spi.custom;
    if (custom != null) {
      _pveAddrCtrl.text = custom.pveAddr ?? '';
      _pveIgnoreCert.value = custom.pveIgnoreCert;
      _customCmds.value = custom.cmds ?? {};
      _preferTempDevCtrl.text = custom.preferTempDev ?? '';
      _logoUrlCtrl.text = custom.logoUrl ?? '';
    }

    final wol = spi.wolCfg;
    if (wol != null) {
      _wolMacCtrl.text = wol.mac;
      _wolIpCtrl.text = wol.ip;
      _wolPwdCtrl.text = wol.pwd ?? '';
    }

    _env.value = spi.envs ?? {};

    _netDevCtrl.text = spi.custom?.netDev ?? '';
    _scriptDirCtrl.text = spi.custom?.scriptDir ?? '';

    _systemType.value = spi.customSystemType;

    final disabledCmdTypes = spi.disabledCmdTypes?.toSet() ?? {};
    final allAvailableCmdTypes = ShellCmdType.all.map((e) => e.displayName);
    disabledCmdTypes.removeWhere((e) => !allAvailableCmdTypes.contains(e));
    _disabledCmdTypes.value = disabledCmdTypes;
  }
}

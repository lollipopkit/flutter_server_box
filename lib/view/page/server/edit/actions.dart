part of 'edit.dart';

/// Only permit ipv4 / ipv6 / domain chars (including IPv6 zone identifier like %en0)
final _hostReg = RegExp(r'^[a-zA-Z0-9\.\-_:%;]+$');

extension _Actions on _ServerEditPageState {
  Iterable<ShellCmdType> get _diskInfoCmdTypes => const [
    StatusCmdType.disk,
    BSDStatusCmdType.disk,
    WindowsStatusCmdType.disk,
  ];

  Iterable<ShellCmdType> get _diskHealthCmdTypes => const [
    StatusCmdType.diskSmart,
    BSDStatusCmdType.diskSmart,
    WindowsStatusCmdType.diskSmart,
  ];

  Future<void> _refreshStoredSudoPasswordState() async {
    String? storedValue;
    try {
      storedValue = await SudoPassword.readOverride(_serverId);
    } catch (e, s) {
      Loggers.app.warning('Failed to read sudo password override', e, s);
      return;
    }
    if (!mounted) return;
    _pendingSudoPassword ??= storedValue;
    _hasStoredSudoPassword.value =
        _pendingSudoPassword != null && _pendingSudoPassword!.isNotEmpty;
  }

  Future<void> _setPendingSudoPassword(String? value) async {
    _pendingSudoPassword = value;
    _sudoPasswordDirty = true;
    _hasStoredSudoPassword.value = value != null && value.isNotEmpty;
  }

  Future<void> _onTapSudoPassword() async {
    final controller = TextEditingController();
    try {
      controller.text = _pendingSudoPassword ?? '';
      if (!mounted) return;

      await context.showRoundDialog(
        title: libL10n.sudoPwdTitle(libL10n.pwd),
        child: Input(
          controller: controller,
          type: TextInputType.visiblePassword,
          obscureText: true,
          label: libL10n.pwd,
          icon: Icons.password,
          suggestion: false,
          onSubmitted: (_) async => await _saveSudoPassword(controller.text),
        ),
        actions: [
          if (_hasStoredSudoPassword.value == true)
            TextButton(
              onPressed: () async {
                await _setPendingSudoPassword(null);
                if (!mounted) return;
                context.pop();
              },
              child: Text(libL10n.clear),
            ),
          TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
          TextButton(
            onPressed: () async => await _saveSudoPassword(controller.text),
            child: Text(libL10n.save),
          ),
        ],
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _saveSudoPassword(String value) async {
    if (value.isEmpty) {
      context.showSnackBar(libL10n.empty);
      return;
    }
    await _setPendingSudoPassword(value);
    if (!mounted) return;
    context.pop();
  }

  Future<bool> _persistPendingSudoPassword() async {
    if (!_sudoPasswordDirty) return true;
    try {
      final pending = _pendingSudoPassword;
      if (pending == null || pending.isEmpty) {
        await SudoPassword.clearOverride(_serverId);
      } else {
        await SudoPassword.writeOverride(_serverId, pending);
      }
      await _refreshStoredSudoPasswordState();
      _sudoPasswordDirty = false;
      return true;
    } catch (e, s) {
      Loggers.app.warning('Failed to persist sudo password override', e, s);
      if (mounted) {
        context.showSnackBar(libL10n.saveFailed);
      }
      return false;
    }
  }

  void _setCmdTypeDisabled(
    String display,
    bool disabled, {
    bool notify = true,
  }) {
    if (disabled) {
      _disabledCmdTypes.value.add(display);
    } else {
      _disabledCmdTypes.value.remove(display);
    }
    if (notify) {
      _disabledCmdTypes.notify();
    }
  }

  bool _isCmdGroupDisabled(Iterable<ShellCmdType> cmdTypes) {
    final disabled = _disabledCmdTypes.value;
    return cmdTypes.every((cmdType) => disabled.contains(cmdType.displayName));
  }

  void _setCmdGroupDisabled(Iterable<ShellCmdType> cmdTypes, bool disabled) {
    for (final cmdType in cmdTypes) {
      _setCmdTypeDisabled(cmdType.displayName, disabled, notify: false);
    }
    _disabledCmdTypes.notify();
  }

  String _cmdTypeTitle(ShellCmdType cmdType) {
    return switch (cmdType) {
      StatusCmdType.disk ||
      BSDStatusCmdType.disk ||
      WindowsStatusCmdType.disk => libL10n.disk,
      StatusCmdType.diskSmart ||
      WindowsStatusCmdType.diskSmart => l10n.diskHealth,
      _ => cmdType.name,
    };
  }

  String _validationErrorMessage(SpiValidationError error) {
    switch (error) {
      case SpiValidationError.jumpServerAndProxyCommandConflict:
        return l10n.jumpServerAndProxyCommandCannotBeUsedTogether;
      case SpiValidationError.monitorTunnelWithoutMonitor:
        return l10n.sshViaMonitorNeedsMonitor;
      case SpiValidationError.monitorTunnelAndOtherTransport:
        return l10n.sshViaMonitorConflictsWithOtherTransport;
    }
  }

  bool _isInvalidJumpSelection(String? candidateJumpId) {
    return _areInvalidJumpSelections(
      candidateJumpId == null ? const [] : [candidateJumpId],
    );
  }

  bool _areInvalidJumpSelections(Iterable<String> candidateJumpIds) {
    final currentServer = spi;
    return wouldCreateJumpCycleForCandidates(
      currentServerId: currentServer?.id,
      candidateJumpIds: candidateJumpIds,
      serversById: ref.read(serversProvider).servers,
    );
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
    final useMonitorHttp = _useMonitorHttp.value;

    // SSH host/auth/jump-chain fields are hidden (and irrelevant) in
    // monitor-HTTP mode — skip their validation/defaulting entirely.
    if (!useMonitorHttp) {
      if (_ipController.text.isEmpty) {
        context.showSnackBar('${libL10n.empty} ${libL10n.host}');
        return;
      }

      if (!_hostReg.hasMatch(_ipController.text)) {
        context.showSnackBar(l10n.invalidHostFormat);
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
      if (_areInvalidJumpSelections(_jumpServers.value)) {
        context.showSnackBar('${l10n.invalid}: ${l10n.jumpServer}');
        return;
      }
    }
    final proxyCommandText = _proxyCommandCtrl.text.trim();
    if (!useMonitorHttp && !isDesktop && proxyCommandText.isNotEmpty) {
      context.showSnackBar(l10n.proxyCommandOnlySupportedOnDesktop);
      return;
    }
    final customCmds = _customCmds.value;
    final custom = ServerCustom(
      pveAddr: _pveAddrCtrl.text.selfNotEmptyOrNull,
      pveIgnoreCert: _pveIgnoreCert.value,
      pvePwd: _pvePwdCtrl.text.selfNotEmptyOrNull,
      cmds: customCmds.isEmpty ? null : customCmds,
      preferTempDev: _preferTempDevCtrl.text.selfNotEmptyOrNull,
      tempIsCelsius: _tempIsCelsius.value,
      logoUrl: _logoUrlCtrl.text.selfNotEmptyOrNull,
      netDev: _netDevCtrl.text.selfNotEmptyOrNull,
      scriptDir: _scriptDirCtrl.text.selfNotEmptyOrNull,
    );

    MonitorHttpCredential? monitorHttp;
    if (useMonitorHttp) {
      final monitorAddr = _monitorAddrCtrl.text.selfNotEmptyOrNull;
      if (monitorAddr == null) {
        context.showSnackBar('${l10n.invalid}: Monitor URL');
        return;
      }
      monitorHttp = MonitorHttpCredential(
        addr: monitorAddr,
        user: _monitorUserCtrl.text.selfNotEmptyOrNull,
        pwd: _monitorPwdCtrl.text.selfNotEmptyOrNull,
        ignoreCert: _monitorIgnoreCert.value,
      );
    }

    // In monitor mode the SSH form is hidden, so there is normally nothing to
    // record — previously these were required, which is why a monitor-only
    // server used to be saved with a host derived from the monitor URL and a
    // user literally named `monitor`. The exception is the SSH-via-monitor
    // tunnel, which needs credentials but no address: the agent connects to
    // its own configured target and takes none from us.
    final ssh = useMonitorHttp
        ? (!_sshViaMonitor.value
              ? null
              : SshCredential(
                  ip: '',
                  user: _tunnelUserCtrl.text.selfNotEmptyOrNull ?? 'root',
                  pwd: _tunnelPwdCtrl.text.selfNotEmptyOrNull,
                  keyId: _tunnelKeyIdx.value != null
                      ? ref
                            .read(privateKeyProvider)
                            .keys
                            .elementAt(_tunnelKeyIdx.value!)
                            .id
                      : null,
                  viaMonitor: true,
                ))
        : SshCredential(
            ip: _ipController.text,
            port: int.tryParse(_portController.text) ?? 22,
            user: _usernameController.text,
            pwd: _passwordController.text.selfNotEmptyOrNull,
            keyId: _keyIdx.value != null
                ? ref
                      .read(privateKeyProvider)
                      .keys
                      .elementAt(_keyIdx.value!)
                      .id
                : null,
            alterUrl: _altUrlController.text.selfNotEmptyOrNull,
            jumpId: _jumpServers.value.isEmpty
                ? null
                : _jumpServers.value.first,
            jumpIds: _jumpServers.value.isEmpty ? null : _jumpServers.value,
            proxyCommand: proxyCommandText.selfNotEmptyOrNull,
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
          ? (ssh?.ip ?? monitorHttp?.addr ?? '')
          : _nameController.text,
      ssh: ssh,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      autoConnect: _autoConnect.value,
      custom: custom,
      wolCfg: wol,
      monitorHttp: monitorHttp,
      envs: _env.value.isEmpty ? null : _env.value,
      id: _serverId,
      customSystemType: _systemType.value,
      disabledCmdTypes: _disabledCmdTypes.value.isEmpty
          ? null
          : _disabledCmdTypes.value.toList(),
    );
    final validationError = spi.validate();
    if (validationError != null) {
      context.showSnackBar(_validationErrorMessage(validationError));
      return;
    }

    if (this.spi == null) {
      final existsIds = ServerStore.instance.box.keys;
      if (existsIds.contains(spi.id)) {
        context.showSnackBar('${l10n.sameIdServerExist}: ${spi.id}');
        return;
      }
      if (!await _persistPendingSudoPassword()) return;
      ref.read(serversProvider.notifier).addServer(spi);
    } else {
      if (!await _persistPendingSudoPassword()) return;
      ref.read(serversProvider.notifier).updateServer(this.spi!, spi);
    }

    context.pop();
  }
}

extension _Utils on _ServerEditPageState {
  void _markSSHConfigImportHandled() {
    Stores.setting.firstTimeReadSSHCfg.put(false);
  }

  Future<void> _checkSSHConfigImport() async {
    final hasExistingServers = ref.read(serversProvider).servers.isNotEmpty;
    if (hasExistingServers) {
      _markSSHConfigImportHandled();
      return;
    }

    try {
      final servers = await SSHConfig.parseConfig();
      if (!mounted) return;
      if (servers.isEmpty) {
        _markSSHConfigImportHandled();
        return;
      }

      final shouldImport = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFound),
            const SizedBox(height: 8),
            Text(l10n.sshConfigImportPermission),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      if (!mounted) return;

      _markSSHConfigImportHandled();

      if (shouldImport == true) {
        await ServerDeduplication.importServersWithNotification(
          servers: servers,
          ref: ref,
          context: context,
          allExistMessage: l10n.sshConfigAllExist,
          importedMessage: l10n.sshConfigImported,
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is PathAccessException ||
          e.toString().contains('Operation not permitted')) {
        _markSSHConfigImportHandled();
        context.showSnackBar(
          '${l10n.sshConfigPermissionDenied} ${l10n.sshConfigManualSelect}',
        );
      } else {
        dprint('Error checking SSH config: $e');
        _markSSHConfigImportHandled();
        if (e is SpiValidationException) {
          context.showSnackBar(_validationErrorMessage(e.error));
        }
      }
    }
  }

  Future<void> _showCmdTypesDialog(Set<ShellCmdType> allCmdTypes) {
    return context.showRoundDialog(
      title: '${libL10n.disabled} ${libL10n.cmd}',
      child: SizedBox(
        width: 270,
        child: _disabledCmdTypes.listenVal((disabled) {
          return ListView.builder(
            itemCount: allCmdTypes.length,
            itemExtent: 72,
            itemBuilder: (context, index) {
              final cmdType = allCmdTypes.elementAtOrNull(index);
              if (cmdType == null) return UIs.placeholder;
              final display = cmdType.displayName;
              return ListTile(
                leading: Icon(cmdType.sysType.icon, size: 20),
                title: Text(
                  _cmdTypeTitle(cmdType),
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: Text(cmdType.displayName, style: UIs.text12Grey),
                trailing: Checkbox(
                  value: disabled.contains(display),
                  onChanged: (value) {
                    if (value == null) return;
                    _setCmdTypeDisabled(display, value);
                  },
                ),
                onTap: () {
                  _setCmdTypeDisabled(display, !disabled.contains(display));
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

    final ssh = spi.ssh;
    // A tunneled credential has no address and lives in its own section of
    // the form; loading it into the direct-SSH fields would show a host of ''
    // and a port of 22 that mean nothing.
    if (ssh != null && ssh.viaMonitor) {
      _sshViaMonitor.value = true;
      _tunnelUserCtrl.text = ssh.user;
      if (ssh.keyId == null) {
        _tunnelPwdCtrl.text = ssh.pwd ?? '';
      } else {
        _tunnelKeyIdx.value = ref
            .read(privateKeyProvider)
            .keys
            .indexWhere((e) => e.id == ssh.keyId);
      }
    } else if (ssh != null) {
      _ipController.text = ssh.ip;
      _portController.text = ssh.port.toString();
      _usernameController.text = ssh.user;
      if (ssh.keyId == null) {
        _passwordController.text = ssh.pwd ?? '';
      } else {
        _keyIdx.value = ref
            .read(privateKeyProvider)
            .keys
            .indexWhere((e) => e.id == ssh.keyId);
      }
      _altUrlController.text = ssh.alterUrl ?? '';
      _jumpServers.value = ssh.resolvedJumpIds;
      _proxyCommandCtrl.text = ssh.proxyCommand ?? '';
    }

    /// List in dart is passed by pointer, so you need to copy it here
    _tags.value = spi.tags?.toSet() ?? {};

    _autoConnect.value = spi.autoConnect;

    final custom = spi.custom;
    if (custom != null) {
      _pveAddrCtrl.text = custom.pveAddr ?? '';
      _pveIgnoreCert.value = custom.pveIgnoreCert;
      _pvePwdCtrl.text = custom.pvePwd ?? '';
      _customCmds.value = custom.cmds ?? {};
      _preferTempDevCtrl.text = custom.preferTempDev ?? '';
      _tempIsCelsius.value = custom.tempIsCelsius;
      _logoUrlCtrl.text = custom.logoUrl ?? '';
    }

    final monitorHttp = spi.monitorHttp;
    _useMonitorHttp.value = monitorHttp != null;
    if (monitorHttp != null) {
      _monitorAddrCtrl.text = monitorHttp.addr;
      _monitorUserCtrl.text = monitorHttp.user ?? '';
      _monitorPwdCtrl.text = monitorHttp.pwd ?? '';
      _monitorIgnoreCert.value = monitorHttp.ignoreCert;
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

part of 'edit.dart';

/// Only permit ipv4 / ipv6 / domain chars (including IPv6 zone identifier like %en0)
final _hostReg = RegExp(r'^[a-zA-Z0-9\.\-_:%;]+$');

/// The BMC account picker's "create a new one" entry.
///
/// A sentinel in the same list as the ids, rather than a second button:
/// the picker takes one list, and a value `ShortId` cannot produce is
/// cheaper than a wrapper type for one entry.
const _kNewBmcCred = '\u0000new';

extension _Discovery on _ServerEditPageState {
  /// Sweeps the network and fills this form in from what is picked.
  ///
  /// Only the fields the sweep actually knows: an address and a port. It
  /// cannot know an account, a key or what you call the machine, so it does
  /// not guess at them — except the name, and only while that field is still
  /// empty, where the address is a better starting point than nothing and is
  /// what someone would have typed anyway.
  Future<void> _onTapDiscover() async {
    final SshDiscoveryResult? found;
    try {
      found = await SshDiscoveryDialog.show(context);
    } catch (e, s) {
      if (!mounted) return;
      context.showErrDialog(e, s);
      return;
    }
    if (!mounted || found == null) return;

    _ipController.text = found.ip;
    _portController.text = '${found.port}';
    if (_nameController.text.isEmpty) _nameController.text = found.ip;
  }
}

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

  /// Picks the account this server's BMC is opened with, or opens the editor
  /// for a new one.
  ///
  /// Creating and editing are the account page's job, reached from here and
  /// from the account list — the same arrangement the private key picker
  /// already uses. A dialog owned by this page would be a second copy of that
  /// form, and the delete and the "used by N servers" warning would only exist
  /// in one of them.
  Future<void> _onTapBmcAccount() async {
    final creds = ref.read(bmcCredentialProvider).creds;
    final current = _bmcCredId.value;
    // `showPickDialog` rather than `showPickSingleDialog`, which answers null
    // for a dialog that was dismissed *and* for one whose selection was
    // cleared. Those have to be told apart here, or dismissing would silently
    // unset the account. This one answers null only for a dismissal, and an
    // empty list for a clear.
    final picked = await context.showPickDialog<String>(
      title: l10n.bmcAccount,
      items: [...creds.map((e) => e.id), _kNewBmcCred],
      display: (id) {
        if (id == _kNewBmcCred) return '+ ${libL10n.add}';
        final cred = creds.firstWhereOrNull((e) => e.id == id);
        return cred == null ? id : '${cred.name} (${cred.user})';
      },
      multi: false,
      initial: current == null ? null : [current],
      // An address with no account is a state the whole stack models: the
      // column is nullable, the key action sets it null, `isComplete` answers
      // false to it and the tile has a string for it. Without this there was
      // no way back to it once an account had been picked, short of deleting
      // the address and the reviewed certificate with it.
      clearable: true,
    );
    if (picked == null || !mounted) return;

    final choice = picked.firstOrNull;
    if (choice != _kNewBmcCred) {
      _bmcCredId.value = choice;
      return;
    }
    final created = await BmcCredentialEditPage.route.go(context);
    // Whatever the page saved, or null if it was left without saving. Read
    // rather than assumed: the picker must not point at a record that does not
    // exist, which the foreign key would refuse at save time anyway.
    if (!mounted) return;
    if (created is BmcCredential) _bmcCredId.value = created.id;
  }

  /// Fetches the certificate the BMC presents, shows it, and pins it if the
  /// user agrees.
  ///
  /// The connection here sends nothing — it exists only to read what the far
  /// end offers — so an impostor at that address learns no password from it.
  /// That is what makes it safe to accept any certificate for this one step,
  /// and it is the only step that does.
  Future<void> _onTapBmcCert() async {
    final cfg = BmcCfg(addr: _bmcAddrCtrl.text.trim());
    final uri = cfg.uri;
    final port = cfg.port;
    if (uri == null || port == null) {
      Toast.error(libL10n.fail, body: l10n.bmcAddrInvalid);
      return;
    }

    final CertInfo info;
    try {
      info = await fetchServerCert(uri.host, port);
    } catch (e) {
      Toast.error(libL10n.fail, body: '$e');
      return;
    }
    if (!mounted) return;

    final pinned = _bmcCert.value;
    final changed = pinned != null && pinned != info.fingerprint;

    final accepted = await context.showRoundDialog<bool>(
      title: l10n.bmcCert,
      barrierDismiss: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(changed ? l10n.bmcCertChanged : l10n.bmcCertReview),
          const SizedBox(height: 12),
          SelectableText('${libL10n.addr}: ${uri.host}:$port'),
          SelectableText('Subject: ${info.subject}'),
          SelectableText('Issuer: ${info.issuer}'),
          SelectableText('SHA-256: ${info.prettyFingerprint}'),
          if (info.isExpired) ...[
            const SizedBox(height: 8),
            Text(
              l10n.bmcCertExpired,
              style: const TextStyle(color: Colors.orange),
            ),
          ],
          if (changed) ...[
            const SizedBox(height: 8),
            SelectableText(l10n.bmcCertWas(pinned)),
          ],
        ],
      ),
      actions: Btnx.cancelOk,
    );
    // The dialog answers; this page acts on the answer and this page is what
    // holds the field — see the dialog rules in CLAUDE.md
    if (accepted != true || !mounted) return;
    _bmcCert.value = info.fingerprint;
  }

  Future<void> _onTapSudoPassword() async {
    final controller = TextEditingController();
    controller.text = _pendingSudoPassword ?? '';
    if (!mounted) return;

    // Disposed by the tree, not after this `await`: the dialog's future
    // completes on the pop, while the field is still mounted and animating.
    await context.showRoundDialog(
      title: libL10n.sudoPwdTitle(libL10n.pwd),
      child: DisposeWith(
        notifiers: [controller],
        child: Input(
          controller: controller,
          type: TextInputType.visiblePassword,
          obscureText: true,
          label: libL10n.pwd,
          icon: Icons.password,
          suggestion: false,
          onSubmitted: (_) async => await _saveSudoPassword(controller.text),
        ),
      ),
      actions: [
        if (_hasStoredSudoPassword.value == true)
          TextButton(
            onPressed: () async {
              await _setPendingSudoPassword(null);
              if (!mounted) return;
              context.popDialog();
            },
            child: Text(libL10n.clear),
          ),
        TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async => await _saveSudoPassword(controller.text),
          child: Text(libL10n.save),
        ),
      ],
    );
  }

  Future<void> _saveSudoPassword(String value) async {
    if (value.isEmpty) {
      Toast.show(libL10n.empty);
      return;
    }
    await _setPendingSudoPassword(value);
    if (!mounted) return;
    // `popDialog`, not `pop`. This runs from the dialog's Save button but
    // `context` is the *page's*, and `showRoundDialog` puts the dialog on the
    // root navigator — so in a pane those are two navigators and `pop` closed
    // the edit page while leaving the dialog on screen.
    context.popDialog();
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
        Toast.error(libL10n.saveFailed);
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
      case SpiValidationError.sshAndMonitorHttpConflict:
        return libL10n.invalid;
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

  /// Opens the editor, which reads and writes the server's own directory.
  ///
  /// Needs a server that exists and can be reached: there is nowhere to put a
  /// command for a server that has not been saved yet.
  void _onTapCustomItem() async {
    final spi = this.spi;
    if (spi == null) {
      Toast.show('${libL10n.save} ${libL10n.server}');
      return;
    }
    await CustomCmdsPage.route.go(context, SpiRequiredArgs(spi));
  }

  void _onTapDisabledCmdTypes() async {
    final allCmdTypes = ShellCmdType.all;

    // [TimeSeq] depends on the `time` cmd type, so it should be removed from the list
    allCmdTypes.remove(StatusCmdType.time);

    await _showCmdTypesDialog(allCmdTypes);
  }

  void _onSave() async {
    final useMonitorHttp = _useMonitorHttp.value;
    final keyIdx = _keyIdx.value;
    final selectedKey = keyIdx == null
        ? null
        : ref.read(privateKeyProvider).keys.elementAtOrNull(keyIdx);
    // Said rather than silently dropped. `elementAtOrNull` is what keeps the
    // save from throwing a RangeError when the chosen key was deleted from
    // another pane meanwhile, but going on from there would write a server
    // with no key and no word about why.
    if (keyIdx != null && selectedKey == null) {
      Toast.show('${libL10n.invalid}: ${libL10n.key}');
      return;
    }

    // SSH host/auth/jump-chain fields are hidden (and irrelevant) in
    // monitor-HTTP mode — skip their validation/defaulting entirely.
    if (!useMonitorHttp) {
      if (_ipController.text.isEmpty) {
        Toast.show('${libL10n.empty} ${libL10n.host}');
        return;
      }

      if (!_hostReg.hasMatch(_ipController.text)) {
        Toast.show(l10n.invalidHostFormat);
        return;
      }

      // Either key source counts. A server imported with an IdentityFile has
      // a key and no password, and asking it to confirm "no authentication"
      // on every save would be asking about something that is not true.
      final hasKey = selectedKey != null || _keyPath.value != null;
      if (!hasKey && _passwordController.text.isEmpty) {
        final ok = await context.showRoundDialog<bool>(
          title: libL10n.attention,
          child: Text(libL10n.askContinue(l10n.useNoPwd)),
          actions: Btnx.cancelRedOk,
        );
        if (ok != true || !mounted) return;
      }

      // If [_pubKeyIndex] is -1, it means that the user has not selected
      if (_keyIdx.value == -1 && _passwordController.text.isEmpty) {
        Toast.show(libL10n.empty);
        return;
      }
      if (_usernameController.text.isEmpty) {
        _usernameController.text = 'root';
      }
      if (_portController.text.isEmpty) {
        _portController.text = '22';
      }
      if (_areInvalidJumpSelections(_jumpServers.value)) {
        Toast.show('${libL10n.invalid}: ${l10n.jumpServer}');
        return;
      }
    }
    final proxyCommandText = _proxyCommandCtrl.text.trim();
    if (!useMonitorHttp && !isDesktop && proxyCommandText.isNotEmpty) {
      Toast.show(l10n.proxyCommandOnlySupportedOnDesktop);
      return;
    }
    final customCmds = _unmigratedCmds.value;
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
        Toast.show('${libL10n.invalid}: Monitor URL');
        return;
      }
      monitorHttp = MonitorHttpCredential(
        addr: monitorAddr,
        user: _monitorUserCtrl.text.selfNotEmptyOrNull,
        pwd: _monitorPwdCtrl.text.selfNotEmptyOrNull,
        ignoreCert: _monitorIgnoreCert.value,
        allowInsecure: _monitorAllowInsecure.value,
      );
    }

    // In monitor mode the SSH form is hidden and a monitor server carries no
    // SSH credential at all: it is reached through its agent, and nothing here
    // would have anywhere to go. Previously these fields were required, which
    // is why a monitor-only server used to be saved with a host derived from
    // the monitor URL and a user literally named `monitor`.
    final ssh = useMonitorHttp
        ? null
        : SshCredential(
            ip: _ipController.text,
            port: int.tryParse(_portController.text) ?? 22,
            user: _usernameController.text,
            pwd: _passwordController.text.selfNotEmptyOrNull,
            keyId: selectedKey?.id,
            // Carried through rather than rebuilt from the form: nothing on
            // this page can type a path, and dropping it on save would take
            // away the only credential an imported server has
            keyPath: selectedKey != null ? null : _keyPath.value,
            identityFiles:
                keyIdx == null && _keyPath.value == this.spi?.ssh?.keyPath
                ? this.spi?.ssh?.identityFiles
                : null,
            alterUrl: _altUrlController.text.selfNotEmptyOrNull,
            jumpId: _jumpServers.value.isEmpty
                ? null
                : _jumpServers.value.first,
            jumpIds: _jumpServers.value.isEmpty ? null : _jumpServers.value,
            proxyCommand: proxyCommandText.selfNotEmptyOrNull,
            fileTransport: _fileTransport.value,
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
        Toast.error(libL10n.fail, body: wolValidation.$1?.toString());
        return;
      }
    }

    // An address alone is not enough to reach a BMC, and a half-filled one
    // would poll forever against nothing — so it is all or nothing
    final bmcAddr = _bmcAddrCtrl.text.trim();
    final bmc = bmcAddr.isEmpty
        ? null
        : BmcCfg(
            addr: bmcAddr,
            credId: _bmcCredId.value,
            certSha256: _bmcCert.value,
          );
    if (bmc != null && !bmc.isComplete) {
      // Which half is missing, since `isComplete` is both and reporting either
      // as a bad address sent the user back to retype one that was fine.
      Toast.error(
        libL10n.fail,
        body: bmc.uri == null ? l10n.bmcAddrInvalid : l10n.bmcAccountUnset,
      );
      return;
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
      bmc: bmc,
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
      Toast.error(_validationErrorMessage(validationError));
      return;
    }

    try {
      if (this.spi == null) {
        final existsIds = Stores.server.keys();
        if (existsIds.contains(spi.id)) {
          Toast.show('${l10n.sameIdServerExist}: ${spi.id}');
          return;
        }
        if (!await _persistPendingSudoPassword()) return;
        await ref.read(serversProvider.notifier).addServer(spi);
      } else {
        if (!await _persistPendingSudoPassword()) return;
        await ref.read(serversProvider.notifier).updateServer(this.spi!, spi);
      }
    } on DuplicateNameException catch (e) {
      if (mounted) Toast.error(l10n.nameAlreadyExistsFmt(e.name));
      return;
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s);
      return;
    }

    if (!mounted) return;
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
        Toast.show(
          '${l10n.sshConfigPermissionDenied} ${l10n.sshConfigManualSelect}',
        );
      } else {
        dprint('Error checking SSH config: $e');
        _markSSHConfigImportHandled();
        if (e is SpiValidationException) {
          Toast.error(_validationErrorMessage(e.error));
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
    if (ssh != null) {
      _ipController.text = ssh.ip;
      _portController.text = ssh.port.toString();
      _usernameController.text = ssh.user;
      _passwordController.text = ssh.pwd ?? '';
      if (ssh.keyId != null) {
        _keyIdx.value = ref
            .read(privateKeyProvider)
            .keys
            .indexWhere((e) => e.id == ssh.keyId);
      }
      _keyPath.value = ssh.keyPath;
      _altUrlController.text = ssh.alterUrl ?? '';
      _jumpServers.value = ssh.resolvedJumpIds;
      _proxyCommandCtrl.text = ssh.proxyCommand ?? '';
      _fileTransport.value = ssh.fileTransport;
    }

    /// List in dart is passed by pointer, so you need to copy it here
    _tags.value = spi.tags?.toSet() ?? {};

    _autoConnect.value = spi.autoConnect;

    final custom = spi.custom;
    if (custom != null) {
      _pveAddrCtrl.text = custom.pveAddr ?? '';
      _pveIgnoreCert.value = custom.pveIgnoreCert;
      _pvePwdCtrl.text = custom.pvePwd ?? '';
      _unmigratedCmds.value = custom.cmds ?? {};
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
      _monitorAllowInsecure.value = monitorHttp.allowInsecure;
    }

    final bmc = spi.bmc;
    if (bmc != null) {
      _bmcAddrCtrl.text = bmc.addr;
      _bmcCredId.value = bmc.credId;
      _bmcCert.value = bmc.certSha256;
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

part of 'edit.dart';

/// Only permit ipv4 / ipv6 / domain chars (including IPv6 zone identifier like %en0)
final _hostReg = RegExp(r'^[a-zA-Z0-9\.\-_:%;]+$');

/// The BMC account picker's "create a new one" entry.
///
/// A sentinel in the same list as the ids, rather than a second button:
/// the picker takes one list, and a value `ShortId` cannot produce is
/// cheaper than a wrapper type for one entry.
const _kNewBmcCred = '\u0000new';

extension _Tags on _ServerEditPageState {
  /// How many servers carry each tag.
  ///
  /// Counted here rather than kept anywhere: a tag is not a record, only a
  /// string repeated across servers, and the count is what makes the editor's
  /// list worth reading — it says which of `prod` and `production` is the one
  /// everything else already uses.
  Map<String, int> _tagUsage() {
    final counts = <String, int>{};
    for (final spi in ref.read(serversProvider).servers.values) {
      for (final tag in spi.tags ?? const <String>[]) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _onEditTags(BuildContext context) {
    final counts = _tagUsage();
    final all = ref.read(serversProvider).tags;
    return showTagEditor(
      context,
      tags: _tags,
      allTags: all,
      hint: l10n.tagNewHint,
      listTitle: l10n.tagAllTags,
      matchingTitle: l10n.tagMatching,
      countLabel: l10n.tagOnThisServerFmt,
      // "Create" only when there is something to create. Typing the name of a
      // tag that already exists is how someone reaches a row far down the
      // list, and offering to create it again would be offering a duplicate
      // of the row right underneath.
      createLabel: (needle) =>
          all.contains(needle) ? libL10n.add : l10n.tagCreateFmt(needle),
      noteOf: (tag, selected, matching) => [
        if (selected) l10n.tagOnThisServer,
        if (matching && !selected) l10n.tagMatchesTyped,
        l10n.tagServersFmt(counts[tag] ?? 0),
      ].join(' · '),
      onRename: _onRenameTag,
      note: l10n.tagEditorTip,
      footer: l10n.tagRenamesOnSave,
    );
  }

  /// Records a rename, to be carried out across every server on save.
  ///
  /// Staged rather than written now, because this page has not written
  /// anything yet: leaving it by the back gesture undoes the name, the tags
  /// and the address, and a rename that had already reached four other servers
  /// would be the one edit that survived a cancel.
  void _onRenameTag(String from, String to) {
    // Collapsed, so renaming `a` to `b` and then `b` to `c` is one rename of
    // `a` to `c` rather than two, the second of which would find nothing left
    // called `b` on any server.
    final origin = _pendingTagRenames.entries
        .firstWhereOrNull((e) => e.value == from)
        ?.key;
    _pendingTagRenames.remove(origin);
    if ((origin ?? from) != to) _pendingTagRenames[origin ?? from] = to;
  }

  /// Rewrites the staged renames onto every other server that carries one.
  ///
  /// This server is not among them: its own tags are whatever `_tags` holds,
  /// and the save that calls this has already written them.
  Future<void> _applyTagRenames() async {
    if (_pendingTagRenames.isEmpty) return;
    final notifier = ref.read(serversProvider.notifier);
    for (final old in ref.read(serversProvider).servers.values.toList()) {
      if (old.id == _serverId) continue;
      final tags = old.tags;
      if (tags == null || tags.isEmpty) continue;

      var changed = false;
      final next = <String>[];
      for (final tag in tags) {
        final to = _pendingTagRenames[tag];
        if (to == null) {
          if (!next.contains(tag)) next.add(tag);
          continue;
        }
        changed = true;
        // A rename onto a name the server already carries is a merge, not a
        // second copy of it.
        if (!next.contains(to)) next.add(to);
      }
      if (!changed) continue;

      await notifier.updateServer(
        old,
        old.copyWith(tags: next.isEmpty ? null : next),
      );
    }
    _pendingTagRenames.clear();
  }
}

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

  void _initWithDraft(ServerDraft draft) {
    if (draft.host case final host?) _ipController.text = host;
    if (draft.port case final port?) _portController.text = '$port';
    if (draft.user case final user?) _usernameController.text = user;
    _nameController.text = draft.name ?? draft.host ?? '';
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
      info = await bmcFetchServerCert(host: uri.host, port: port);
    } on BmcError catch (e) {
      Toast.error(libL10n.fail, body: e.message);
      return;
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

  /// What [_pveConfigToSave] answers when the form cannot be saved; it has
  /// already said why.
  static const _pveInvalid = PveConfig(addr: '');

  /// The PVE configuration the form describes: null for none, [_pveInvalid]
  /// when it is incomplete. [sshKeyId] is the key the SSH login is saved
  /// with, which decides whether the PVE password is kept at all.
  PveConfig? _pveConfigToSave({required String? sshKeyId}) {
    final addr = _pveAddrCtrl.text.trim();
    final useToken = _pveUseToken.value;
    final tokenId = _pveTokenIdCtrl.text.trim().selfNotEmptyOrNull;
    final tokenSecret = _pveTokenSecretCtrl.text.trim().selfNotEmptyOrNull;
    if (addr.isEmpty) return null;
    // A password login is the SSH user's (`PveBackend`), and a server with no
    // SSH host saves no SSH user: refused here rather than saved to fail on
    // every connection.
    if (!useToken && !_hasPveLoginUser) {
      Toast.show('${libL10n.empty} ${libL10n.user}: ${l10n.pveAuthToken}');
      return _pveInvalid;
    }
    if (useToken) {
      if (tokenId == null || !PveConfig.tokenIdPattern.hasMatch(tokenId)) {
        Toast.show(l10n.pveTokenIdInvalid);
        return _pveInvalid;
      }
      if (tokenSecret == null) {
        Toast.show('${libL10n.empty} ${l10n.pveTokenSecret}');
        return _pveInvalid;
      }
    }
    // The pin is the stored one, read now rather than when the page opened:
    // this page never sets it, and the Virtualization tab may have confirmed
    // a certificate while it was open. Saving the copy read at open time
    // wrote that confirmation away. Three things drop it: Forget, another
    // address, and another far end ([_pveKeepsPin], once the server is
    // built) — a pin names a certificate seen at one address, and keeping it
    // for another would turn that server's first connection into a
    // "certificate changed" error instead of the confirmation it should be.
    final stored = Stores.pve.fetch(spi?.id);
    final cert = stored != null && stored.addr.trim() == addr && !_pveCertForgot
        ? stored.certSha256
        : null;
    // Only the chosen method's credentials, so the row never holds a token
    // and a password that disagree about how to log in. The password only
    // where its field is shown — SSH with a key — since only there is it what
    // a login sends (`PveConfig.loginPassword`); a hidden field's text saved
    // anyway would be a second password nothing uses.
    final ownsPwd = !useToken && PveConfig.ownsPassword(sshKeyId: sshKeyId);
    return PveConfig(
      addr: addr,
      auth: useToken ? PveAuth.token : PveAuth.password,
      pwd: ownsPwd ? _pvePwdCtrl.text.selfNotEmptyOrNull : null,
      tokenId: useToken ? tokenId : null,
      tokenSecret: useToken ? tokenSecret : null,
      certSha256: cert,
    );
  }

  /// Whether saving leaves an SSH user for a PVE password login: the SSH
  /// credential is written exactly when there is a host (see `_onSave`).
  bool get _hasPveLoginUser => _ipController.text.trim().isNotEmpty;

  /// Whether [cfg]'s pin still names the certificate it was confirmed for
  /// once the server is saved as [next]: the API's host resolves on the far
  /// end of the transport, so `https://127.0.0.1:8006` on another SSH host,
  /// behind another jump or through another agent is another machine.
  PveConfig? _pveKeepsPin(PveConfig? cfg, Spi next) {
    if (cfg == null || cfg.certSha256 == null) return cfg;
    final old = spi;
    if (old != null && _pveFarEnd(old) == _pveFarEnd(next)) return cfg;
    return cfg.copyWith(certSha256: null);
  }

  /// What decides where a PVE address resolves — see `ServerTcpDialer`.
  static String _pveFarEnd(Spi s) {
    final ssh = s.sshOn;
    return [
      s.local,
      ssh?.ip.trim(),
      ssh?.port,
      ssh?.resolvedJumpIds.join(','),
      ssh?.proxyCommand?.trim(),
      s.monitorOn?.addr.trim(),
    ].join('\u0000');
  }

  Future<void> _onTapForgetPveCert() async {
    // The dialog answers; this page clears the field it holds — see the
    // dialog rules in CLAUDE.md.
    final ok = await context.showRoundDialog<bool>(
      title: l10n.pveCertForget,
      child: Text(l10n.pveCertForgetTip),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    _pveCert.value = null;
    _pveCertForgot = true;
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
    // The one saved here is the one meant from now on, not one typed earlier
    // this session (`SudoPassword.known` tries that first).
    SudoPassword.forget(_serverId);
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
      case SpiValidationError.noConnectionMethod:
        return l10n.noConnectionMethod;
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

  Future<void> _onSave() async {
    final form = await _validateForm();
    if (form == null || !mounted) return;
    final spi = _buildSpi(form);
    if (spi.validate() case final error?) {
      Toast.error(_validationErrorMessage(error));
      return;
    }
    if (!await _persist(spi, form.pve)) return;
    if (!mounted) return;
    _reportSaved(form);
    // Saved either way — the address may well be one TLS is being set up for,
    // and refusing to store it would be this page deciding that for the user.
    // But it will not connect as it stands, and the switch that would let it
    // is on this same page under More, so saying so beats leaving them to find
    // out from the detail page's error.
    if (spi.monitorHttp?.needsInsecureOptIn == true) {
      Toast.warn(
        l10n.monitorHttpsRequired,
        body: l10n.monitorAllowInsecureHttpTip,
      );
    }
    context.pop();
  }

  /// The checks a save makes before anything is built, each saying what is
  /// wrong. Null when one refused; nothing on the form is changed.
  Future<_SaveForm?> _validateForm() async {
    final local = _local.value;
    // What is going to be dialled, which is what the checks below are about.
    // The switches themselves are stored as they are: this device parks both
    // methods rather than turning them off.
    final useSsh = _useSsh.value && !local;
    final useMonitorHttp = _useMonitorHttp.value && !local;
    final keyIdx = _keyIdx.value;
    // `-1` is what the key-auth switch writes when it is turned on before a
    // key is picked: no selection. `elementAtOrNull` throws on it rather than
    // answering null.
    final selectedKey = keyIdx == null || keyIdx < 0
        ? null
        : ref.read(privateKeyProvider).keys.elementAtOrNull(keyIdx);

    // The SSH form is hidden when SSH is switched off, so there is nothing
    // there to validate — and requiring it is what used to make a
    // monitor-only server invent a host and a user named `monitor`.
    if (useSsh) {
      // Said rather than silently dropped: the chosen key was deleted from
      // another pane meanwhile, and going on would write a server with no
      // key and no word about why.
      if (keyIdx != null && keyIdx >= 0 && selectedKey == null) {
        Toast.show('${libL10n.invalid}: ${libL10n.key}');
        return null;
      }
      if (_ipController.text.isEmpty) {
        Toast.show('${libL10n.empty} ${libL10n.host}');
        return null;
      }
      if (!_hostReg.hasMatch(_ipController.text)) {
        Toast.show(l10n.invalidHostFormat);
        return null;
      }
      // Key auth switched on with no key picked and no password to fall back
      // on: refused before asking whether no authentication is meant.
      if (keyIdx == -1 && _passwordController.text.isEmpty) {
        Toast.show('${libL10n.empty}: ${libL10n.key}');
        return null;
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
        if (ok != true || !mounted) return null;
      }
      if (_areInvalidJumpSelections(_jumpServers.value)) {
        Toast.show('${libL10n.invalid}: ${l10n.jumpServer}');
        return null;
      }
    }
    // Refused rather than dropped. A coordinate that does not parse is a typo
    // in something the user meant, and silently saving nothing there would
    // read as the field not working.
    final geoText = _geoCtrl.text.trim();
    final geo = GeoCoord.tryParse(geoText);
    if (geoText.isNotEmpty && geo == null) {
      Toast.show('${libL10n.invalid}: ${libL10n.location}');
      return null;
    }
    final pve = _pveConfigToSave(sshKeyId: selectedKey?.id);
    if (identical(pve, _pveInvalid)) return null;

    // Only the address is required, and only when the switch is on: there is
    // nothing to dial without it.
    if (useMonitorHttp && _monitorAddrCtrl.text.selfNotEmptyOrNull == null) {
      Toast.show('${libL10n.invalid}: Monitor URL');
      return null;
    }

    final wol = _wolToSave();
    if (wol != null) {
      final wolValidation = wol.validate();
      if (!wolValidation.$2) {
        Toast.error(libL10n.fail, body: wolValidation.$1?.toString());
        return null;
      }
    }

    final bmc = _bmcToSave();
    if (bmc != null && !bmc.isComplete) {
      // Which half is missing, since `isComplete` is both and reporting either
      // as a bad address sent the user back to retype one that was fine.
      Toast.error(
        libL10n.fail,
        body: bmc.uri == null ? l10n.bmcAddrInvalid : l10n.bmcAccountUnset,
      );
      return null;
    }

    return (
      local: local,
      useSsh: useSsh,
      useMonitorHttp: useMonitorHttp,
      selectedKey: selectedKey,
      geo: geo,
      pve: pve,
      wol: wol,
      bmc: bmc,
    );
  }

  WakeOnLanCfg? _wolToSave() {
    final wolEmpty =
        _wolMacCtrl.text.isEmpty &&
        _wolIpCtrl.text.isEmpty &&
        _wolPwdCtrl.text.isEmpty;
    return wolEmpty
        ? null
        : WakeOnLanCfg(
            mac: _wolMacCtrl.text,
            ip: _wolIpCtrl.text,
            pwd: _wolPwdCtrl.text.selfNotEmptyOrNull,
          );
  }

  BmcCfg? _bmcToSave() {
    // An address alone is not enough to reach a BMC, and a half-filled one
    // would poll forever against nothing — so it is all or nothing
    final bmcAddr = _bmcAddrCtrl.text.trim();
    return bmcAddr.isEmpty
        ? null
        : BmcCfg(
            addr: bmcAddr,
            credId: _bmcCredId.value,
            certSha256: _bmcCert.value,
          );
  }

  /// The server the form describes, defaults applied once. Pure: nothing on
  /// the form is written.
  Spi _buildSpi(_SaveForm form) {
    final (:local, :selectedKey, :geo, :wol, :bmc, useSsh: _, useMonitorHttp: _, pve: _) = form;
    final proxyCommandText = _proxyCommandCtrl.text.trim();
    final customCmds = _unmigratedCmds.value;
    final custom = ServerCustom(
      cmds: customCmds.isEmpty ? null : customCmds,
      preferTempDev: _preferTempDevCtrl.text.selfNotEmptyOrNull,
      tempIsCelsius: _tempIsCelsius.value,
      logoUrl: _logoUrlCtrl.text.selfNotEmptyOrNull,
      netDev: _netDevCtrl.text.selfNotEmptyOrNull,
      scriptDir: _scriptDirCtrl.text.selfNotEmptyOrNull,
      geo: geo,
      diskCountsNetwork: _diskCountsNetwork.value,
    );

    // Built from the fields whatever the switch says, and the switch travels
    // beside it as `monitorEnabled`. Off keeps the configuration — that is the
    // whole of what "off" means here — so turning a method back on is not a
    // retyping exercise. Only the address is required, and only when the
    // switch is on: there is nothing to dial without it.
    final monitorAddr = _monitorAddrCtrl.text.selfNotEmptyOrNull;
    final monitorHttp = monitorAddr == null
        ? null
        : MonitorHttpCredential(
            addr: monitorAddr,
            pwd: _monitorPwdCtrl.text.selfNotEmptyOrNull,
            // Not edited here: kept for the same agent only.
            // TODO: remove with `MonitorHttpCredential.legacyUser`.
            legacyUser: spi?.monitorHttp?.addr == monitorAddr
                ? spi?.monitorHttp?.legacyUser
                : null,
            ignoreCert: _monitorIgnoreCert.value,
            allowInsecure: _monitorAllowInsecure.value,
          );

    // Same rule as the agent above: kept when switched off, and absent only
    // when there is no host to keep.
    final ssh = _ipController.text.trim().isEmpty
        ? null
        : SshCredential(
            ip: _ipController.text,
            port: int.tryParse(_portController.text) ?? 22,
            // Defaulted here and only here, whatever the switch says: a
            // parked configuration is still one somebody will turn back on.
            user: _usernameController.text.isEmpty
                ? 'root'
                : _usernameController.text,
            pwd: _passwordController.text.selfNotEmptyOrNull,
            keyId: selectedKey?.id,
            // Carried through rather than rebuilt from the form: nothing on
            // this page can type a path, and dropping it on save would take
            // away the only credential an imported server has
            identityFiles: switch ((selectedKey, _keyPath.value)) {
              (null, final path?) =>
                path == spi?.ssh?.resolvedIdentityFiles.firstOrNull
                    ? spi!.ssh!.resolvedIdentityFiles
                    : [path],
              _ => null,
            },
            alterUrl: _altUrlController.text.selfNotEmptyOrNull,
            jumpIds: _jumpServers.value.isEmpty ? null : _jumpServers.value,
            proxyCommand: proxyCommandText.selfNotEmptyOrNull,
            fileTransport: _fileTransport.value,
            allowLegacyAlgorithms: _allowLegacyAlgorithms.value,
          );

    return Spi(
      name: _nameController.text.isNotEmpty
          ? _nameController.text
          : local
          ? Platform.localHostname
          : (ssh?.ip ?? monitorHttp?.addr ?? ''),
      ssh: ssh,
      tags: _tags.value.isEmpty ? null : _tags.value.toList(),
      autoConnect: _autoConnect.value,
      custom: custom,
      wolCfg: wol,
      bmc: bmc,
      monitorHttp: monitorHttp,
      // Only meaningful with two to order. Storing it for a server with one
      // way in would leave a preference behind for a transport that is not
      // configured — which is exactly what `Spix.transport` then has to
      // ignore, so it is better never written.
      preferredTransport: ssh != null && monitorHttp != null
          ? (_preferMonitorHttp.value
                ? ServerTransport.monitorHttp
                : ServerTransport.ssh)
          : null,
      sshEnabled: _useSsh.value,
      monitorEnabled: _useMonitorHttp.value,
      local: local,
      envs: _env.value.isEmpty ? null : _env.value,
      id: _serverId,
      customSystemType: _systemType.value,
      disabledCmdTypes: _disabledCmdTypes.value.isEmpty
          ? null
          : _disabledCmdTypes.value.toList(),
    );
  }

  /// Writes [spi], its sudo password, its PVE config and the tag renames.
  /// False when it did not save, having said why.
  Future<bool> _persist(Spi spi, PveConfig? pve) async {
    try {
      if (this.spi == null) {
        final existsIds = Stores.server.keys();
        if (existsIds.contains(spi.id)) {
          Toast.show('${l10n.sameIdServerExist}: ${spi.id}');
          return false;
        }
        if (!await _persistPendingSudoPassword()) return false;
        await ref.read(serversProvider.notifier).addServer(spi);
      } else {
        if (!await _persistPendingSudoPassword()) return false;
        await ref.read(serversProvider.notifier).updateServer(this.spi!, spi);
      }
      // A child of the server row, so only once that row exists.
      Stores.pve.put(spi.id, _pveKeepsPin(pve, spi));
      // After this server is written, so that a failure above leaves the other
      // servers alone — and so that the state this reads back already has this
      // server's own tags in it.
      await _applyTagRenames();
    } on DuplicateNameException catch (e) {
      if (mounted) Toast.error(l10n.nameAlreadyExistsFmt(e.name));
      return false;
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s);
      return false;
    }
    return true;

  }

  /// Closes the funnel `edit opened` began, and is the one place that knows
  /// the whole shape of what was configured. Every value here is an enum or a
  /// flag this app defines -- no host, no name, no credential -- which is
  /// what makes "which combinations are actually used" answerable without
  /// any of them being about a particular server.
  void _reportSaved(_SaveForm form) {
    final (:useSsh, :useMonitorHttp, :local, :selectedKey, :geo, pve: _, wol: _, bmc: _) = form;
    String auth() {
      if (selectedKey != null || _keyPath.value != null) return 'key';
      if (_passwordController.text.isNotEmpty) return 'password';
      return 'none';
    }

    String via() {
      if (_jumpServers.value.isNotEmpty) return 'jump';
      if (_proxyCommandCtrl.text.trim().isNotEmpty) return 'proxy';
      return 'direct';
    }

    Diag.crumb(
      SbDiag.server,
      'edit saved',
      data: {
        'ssh': '$useSsh',
        'monitor': '$useMonitorHttp',
        'local': '$local',
        // The same two key sources the validation counts: a server imported
        // with an IdentityFile has its key in `_keyPath` and no `selectedKey`.
        // `none` is a real third answer -- the save asks the user to confirm
        // it and then goes ahead.
        if (useSsh) 'auth': auth(),
        if (useSsh) 'via': via(),
        if (useSsh) 'files': _fileTransport.value.name,
        // Whether one was typed, never what it was — a coordinate is where the
        // user's machine is.
        'geo': geo == null ? 'no' : 'yes',
      },
    );
  }
}

/// What [_Actions._validateForm] checked, for the rest of a save.
typedef _SaveForm = ({
  bool local,
  bool useSsh,
  bool useMonitorHttp,
  PrivateKeyInfo? selectedKey,
  GeoCoord? geo,
  PveConfig? pve,
  WakeOnLanCfg? wol,
  BmcCfg? bmc,
});

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

  void _openSection(ServerEditSection section) {
    switch (section) {
      case ServerEditSection.pve:
        // The API as the server itself sees it, which every transport can
        // reach (`ServerTcpDialer`).
        if (_pveAddrCtrl.text.trim().isEmpty) {
          _pveAddrCtrl.text = PveConfig.localAddr;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _pveKey.currentContext;
          final object = ctx?.findRenderObject();
          if (ctx == null || !ctx.mounted || object == null) return;
          // The page's own list only. `Scrollable.ensureVisible` walks every
          // scrollable above, physics or not — the home's tab `PageView`
          // included, which it leaves between two tabs.
          Scrollable.maybeOf(ctx)?.position.ensureVisible(
            object,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        });
    }
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
      _keyPath.value = ssh.resolvedIdentityFiles.firstOrNull;
      _altUrlController.text = ssh.alterUrl ?? '';
      _jumpServers.value = ssh.resolvedJumpIds;
      _proxyCommandCtrl.text = ssh.proxyCommand ?? '';
      _fileTransport.value = ssh.fileTransport;
      _allowLegacyAlgorithms.value = ssh.allowLegacyAlgorithms;
    }

    /// List in dart is passed by pointer, so you need to copy it here
    _tags.value = spi.tags?.toSet() ?? {};

    _autoConnect.value = spi.autoConnect;

    final custom = spi.custom;
    if (custom != null) {
      _unmigratedCmds.value = custom.cmds ?? {};
      _preferTempDevCtrl.text = custom.preferTempDev ?? '';
      _tempIsCelsius.value = custom.tempIsCelsius;
      _diskCountsNetwork.value = custom.diskCountsNetwork;
      _logoUrlCtrl.text = custom.logoUrl ?? '';
      _geoCtrl.text = custom.geo?.text ?? '';
    }

    final pve = Stores.pve.fetch(spi.id);
    if (pve != null) {
      _pveAddrCtrl.text = pve.addr;
      _pveUseToken.value = pve.auth == PveAuth.token;
      _pvePwdCtrl.text = pve.pwd ?? '';
      _pveTokenIdCtrl.text = pve.tokenId ?? '';
      _pveTokenSecretCtrl.text = pve.tokenSecret ?? '';
      _pveCert.value = pve.certSha256;
    }

    final monitorHttp = spi.monitorHttp;
    // The switch, which is configuration *and* the switch: a method with
    // nothing configured is off however the flag reads, and one that is
    // configured and switched off shows its fields under a section that says
    // it is off.
    //
    // Read as though the server were not this device: `sshOn`, `monitorOn`
    // and `transport` all answer "nothing is dialled" for one, and what the
    // form shows is what turning that off would bring back.
    final dialled = spi.copyWith(local: false);
    _local.value = spi.local;
    _useSsh.value = dialled.sshOn != null;
    _useMonitorHttp.value = dialled.monitorOn != null;
    _preferMonitorHttp.value = dialled.transport == ServerTransport.monitorHttp;
    if (monitorHttp != null) {
      _monitorAddrCtrl.text = monitorHttp.addr;
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

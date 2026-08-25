part of 'edit.dart';

extension _Widgets on _ServerEditPageState {
  Widget _buildAuth() {
    // Reads both sources: a server imported with an IdentityFile authenticates
    // with a key even though nothing is selected among the stored ones, and a
    // switch that showed "off" there would be describing the wrong thing.
    final switch_ = ListTile(
      title: Text(l10n.keyAuth),
      trailing: _keyIdx.listenVal(
        (idx) => _keyPath.listenVal(
          (path) => Switch(
            value: idx != null || path != null,
            onChanged: (on) {
              if (on) {
                // Already on by way of a file: leave the file alone rather
                // than adding an empty stored-key selection beside it
                if (path == null) _keyIdx.value = -1;
              } else {
                _keyIdx.value = null;
                _keyPath.value = null;
              }
            },
          ),
        ),
      ),
    );
    final password = Input(
      controller: _passwordController,
      obscureText: true,
      type: TextInputType.text,
      label: libL10n.pwd,
      icon: Icons.password,
      suggestion: false,
      onSubmitted: (_) => _onSave(),
    );

    /// Keep static auth fields outside [ValueBuilder] to avoid rebuilding them.
    return _keyIdx.listenVal((v) {
      final children = <Widget>[switch_];
      if (v != null) {
        children.add(_buildKeyAuth());
      }
      children.add(_buildKeyPath());
      children.add(password);
      return Column(children: children);
    });
  }

  /// The key file an `~/.ssh/config` import pointed at, when there is one.
  ///
  /// Read-only: nothing on this page writes a path, and the field exists so a
  /// server imported with an `IdentityFile` shows what it authenticates with
  /// instead of an empty key picker. Clearing it is offered because the only
  /// other way off it is to pick a stored key, which not every setup wants.
  Widget _buildKeyPath() {
    return _keyPath.listenVal((path) {
      if (path == null) return UIs.placeholder;
      return ListTile(
        leading: const Icon(Icons.description),
        title: Text(path, style: UIs.text13),
        subtitle: Text(l10n.sshConfigImport, style: UIs.textGrey),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => _keyPath.value = null,
        ),
      ).cardx;
    });
  }

  Widget _buildKeyAuth() => _buildKeyAuthFor(_keyIdx);

  /// The private-key picker, parameterised by which selection it drives.
  ///
  /// Two independent SSH credentials can be on this page — the direct one and
  /// the tunnel's — and they must not share a selection.
  Widget _buildKeyAuthFor(ValueNotifier<int?> keyIdx) {
    const padding = EdgeInsets.only(left: 13, right: 13, bottom: 7);
    final privateKeyState = ref.watch(privateKeyProvider);
    final pkis = privateKeyState.keys;

    final choice = keyIdx.listenVal((val) {
      final selectedPki = val != null && val >= 0 && val < pkis.length
          ? pkis[val]
          : null;
      return Choice<int>(
        multiple: false,
        clearable: true,
        value: selectedPki != null ? [val!] : [],
        builder: (state, _) => Column(
          children: [
            Wrap(
              children: List<Widget>.generate(pkis.length, (index) {
                final item = pkis[index];
                return ChoiceChipX<int>(
                  key: ValueKey(index),
                  // The name, not the id: an id is generated now, so this
                  // chip showed the user a `ShortId`.
                  label: item.name,
                  state: state,
                  value: index,
                  onSelected: (idx, on) {
                    if (on) {
                      keyIdx.value = idx;
                      // At most one of the two — see `SshCredential.keyPath`
                      _keyPath.value = null;
                    } else {
                      keyIdx.value = -1;
                    }
                  },
                );
              }),
            ),
            UIs.height7,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (selectedPki != null)
                  Btn.icon(
                    icon: const Icon(Icons.edit, size: 20),
                    text: libL10n.edit,
                    onTap: () => PrivateKeyEditPage.route.go(
                      context,
                      args: PrivateKeyEditPageArgs(pki: selectedPki),
                    ),
                  ),
                Btn.icon(
                  icon: const Icon(Icons.add, size: 20),
                  text: libL10n.add,
                  onTap: () => PrivateKeyEditPage.route.go(context),
                ),
              ],
            ),
          ],
        ),
      );
    });

    return ExpandTile(
      leading: const Icon(Icons.key),
      initiallyExpanded: keyIdx.value != null && keyIdx.value! >= 0,
      childrenPadding: padding,
      title: Text(l10n.privateKey),
      children: [choice],
    ).cardx;
  }

  Widget _buildEnvs() {
    return _env.listenVal((val) {
      final subtitle = val.isEmpty
          ? null
          : Text(val.keys.join(','), style: UIs.textGrey);
      return ListTile(
        leading: const Icon(HeroIcons.variable),
        subtitle: subtitle,
        title: Text(l10n.envVars),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () async {
          final res = await KvEditor.route.go(
            context,
            KvEditorArgs(data: spi?.envs ?? {}),
          );
          if (res == null) return;
          _env.value = res;
        },
      ).cardx;
    });
  }

  Widget _buildMore() {
    return ExpandTile(
      title: Text(libL10n.more),
      children: [
        _buildSudoPassword(),
        Input(
          controller: _logoUrlCtrl,
          type: TextInputType.url,
          icon: Icons.image,
          label: 'Logo URL',
          hint: 'https://example.com/logo.png',
          suggestion: false,
        ),
        _buildAltUrl(),
        _buildProxyCommand(),
        _buildFileTransport(),
        _buildScriptDir(),
        _buildEnvs(),
        _buildPVEs(),
        _buildCustomCmds(),
        _buildStorageCollection(),
        _buildDisabledCmdTypes(),
        _buildCustomDev(),
        _buildBmc(),
        _buildWOLs(),
      ],
    );
  }

  Widget _buildSudoPassword() {
    return _hasStoredSudoPassword.listenVal((hasValue) {
      final subtitle = switch (hasValue) {
        true => Text(libL10n.configured, style: UIs.textGrey),
        false => Text(libL10n.empty, style: UIs.textGrey),
        null => Text(libL10n.loadingEllipsis, style: UIs.textGrey),
      };
      return ListTile(
        leading: const Icon(Icons.password),
        title: Text(libL10n.sudoPassword),
        subtitle: subtitle,
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _onTapSudoPassword,
      ).cardx;
    });
  }

  Widget _buildScriptDir() {
    return Input(
      controller: _scriptDirCtrl,
      type: TextInputType.text,
      label: '${l10n.remotePath} (Shell ${libL10n.install})',
      icon: Icons.folder,
      hint: '~/.config/server_box',
      suggestion: false,
    );
  }

  Widget _buildCustomDev() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.specifyDev),
        ListTile(
          leading: const Icon(MingCute.question_line),
          title: TipText(libL10n.note, l10n.specifyDevTip),
        ).cardx,
        Input(
          controller: _preferTempDevCtrl,
          type: TextInputType.text,
          label: libL10n.temperature,
          icon: MingCute.low_temperature_line,
          hint: 'nvme-pci-0400',
          suggestion: false,
        ),
        ListTile(
          leading: const Icon(MingCute.question_line),
          title: TipText('${libL10n.temperature} (°C)', l10n.tempIsCelsiusTip),
          trailing: _tempIsCelsius.listenVal(
            (v) => Switch(
              value: v,
              onChanged: (val) {
                _tempIsCelsius.value = val;
              },
            ),
          ),
        ).cardx,
        Input(
          controller: _netDevCtrl,
          type: TextInputType.text,
          label: libL10n.net,
          icon: ZondIcons.network,
          hint: 'eth0',
          suggestion: false,
        ),
      ],
    );
  }

  Widget _buildSystemType() {
    return _systemType.listenVal((val) {
      return ListTile(
        leading: Icon(MingCute.laptop_2_line),
        title: Text(libL10n.system),
        trailing: PopupMenu<SystemType?>(
          initialValue: val,
          items: [
            PopupMenuItem(value: null, child: Text(libL10n.auto)),
            PopupMenuItem(value: SystemType.linux, child: Text('Linux')),
            PopupMenuItem(value: SystemType.bsd, child: Text('BSD')),
            PopupMenuItem(value: SystemType.windows, child: Text('Windows')),
          ],
          onSelected: (value) => _systemType.value = value,
          child: Text(
            val?.name ?? libL10n.auto,
            style: TextStyle(color: val == null ? Colors.grey : null),
          ),
        ),
      ).cardx;
    });
  }

  Widget _buildAltUrl() {
    return Input(
      controller: _altUrlController,
      type: TextInputType.url,
      node: _alterUrlFocus,
      onSubmitted: (_) => _focusScope.requestFocus(_proxyCommandFocus),
      label: l10n.fallbackSshDest,
      icon: MingCute.link_line,
      hint: 'user@ip:port',
      suggestion: false,
    );
  }

  Widget _buildProxyCommand() {
    final input = Input(
      controller: _proxyCommandCtrl,
      type: TextInputType.multiline,
      node: _proxyCommandFocus,
      label: 'ProxyCommand',
      icon: MingCute.command_line,
      hint: 'socat - PROXY:x.x.x.x:%h:%p,proxyport=5002',
      suggestion: false,
      maxLines: 3,
    );
    // Said here as well as in the failure, because the failure is what this
    // is meant to save someone from: on a sandboxed build the command runs
    // and fails for a reason nothing in its output mentions.
    if (!Pfs.isMacSandboxed) return input;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        ListTile(
          leading: const Icon(MingCute.question_line),
          title: TipText(libL10n.note, l10n.proxyCommandSandboxed),
        ).cardx,
      ],
    );
  }

  /// Which protocol this server's files move over.
  ///
  /// Offered rather than probed: opening an SFTP session and falling back when
  /// it fails would take a link that dropped, or an account that was locked,
  /// for a host with no subsystem — and answer the second failure instead of
  /// the first. Nobody has to come here unless SFTP does not work, and the
  /// browser's own failure says so when it does not.
  Widget _buildFileTransport() {
    // Nothing to set on a monitor server: saving one writes `ssh: null`, so a
    // choice made here would be accepted, saved and discarded without a word.
    // The two fields above it have the same shape and the same problem; this
    // one is new, so it does not add to it.
    return _useMonitorHttp.listenVal((useHttp) {
      if (useHttp) return UIs.placeholder;
      return _buildFileTransportTile();
    });
  }

  Widget _buildFileTransportTile() {
    return _fileTransport.listenVal((val) {
      return ListTile(
        leading: const Icon(MingCute.transfer_2_line),
        title: TipText(libL10n.file, l10n.sshFileTransportTip),
        trailing: PopupMenu<SshFileTransport>(
          initialValue: val,
          items: const [
            PopupMenuItem(value: SshFileTransport.sftp, child: Text('SFTP')),
            PopupMenuItem(value: SshFileTransport.scp, child: Text('SCP')),
          ],
          onSelected: (value) => _fileTransport.value = value,
          child: Text(val == SshFileTransport.scp ? 'SCP' : 'SFTP'),
        ),
      ).cardx;
    });
  }

  Widget _buildPVEs() {
    const addr = 'https://127.0.0.1:8006';
    return _keyIdx.listenVal((v) {
      final useKeyAuth = v != null && v >= 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CenterGreyTitle('PVE'),
          Input(
            controller: _pveAddrCtrl,
            type: TextInputType.url,
            icon: MingCute.web_line,
            label: 'URL',
            hint: addr,
            suggestion: false,
          ),
          if (useKeyAuth)
            Input(
              controller: _pvePwdCtrl,
              type: TextInputType.visiblePassword,
              icon: MingCute.lock_line,
              label: l10n.pvePassword,
              hint: l10n.pvePasswordHint,
              obscureText: true,
              suggestion: false,
            ),
          ListTile(
            leading: const Icon(MingCute.certificate_line),
            title: TipText('PVE ${l10n.ignoreCert}', l10n.pveIgnoreCertTip),
            trailing: _pveIgnoreCert.listenVal(
              (v) => Switch(
                value: v,
                onChanged: (val) {
                  _pveIgnoreCert.value = val;
                },
              ),
            ),
          ).cardx,
        ],
      );
    });
  }

  /// SSH+shell vs monitor's HTTP API — mutually exclusive connection
  /// methods for reaching this server (see `Spi.monitorHttp`'s doc comment).
  Widget _buildConnMethodSwitch() {
    return _useMonitorHttp.listenVal((useHttp) {
      return SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('SSH'),
            icon: Icon(Icons.terminal, size: 16),
          ),
          ButtonSegment(
            value: true,
            label: Text('Monitor HTTP'),
            icon: Icon(MingCute.web_line, size: 16),
          ),
        ],
        selected: {useHttp},
        onSelectionChanged: (selection) {
          _useMonitorHttp.value = selection.first;
        },
      );
    });
  }

  /// SSH host/port/user — hidden when `_useMonitorHttp` is selected, since
  /// they're not used by the monitor HTTP connection path at all.
  Widget _buildSshConnFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Input(
          controller: _ipController,
          type: TextInputType.url,
          onSubmitted: (_) => _focusScope.requestFocus(_portFocus),
          node: _ipFocus,
          label: libL10n.host,
          icon: BoxIcons.bx_server,
          hint: 'example.com',
          suggestion: false,
        ),
        Input(
          controller: _portController,
          type: TextInputType.number,
          node: _portFocus,
          onSubmitted: (_) => _focusScope.requestFocus(_usernameFocus),
          label: libL10n.port,
          icon: Bootstrap.number_123,
          hint: '22',
          suggestion: false,
        ),
        Input(
          controller: _usernameController,
          type: TextInputType.text,
          node: _usernameFocus,
          onSubmitted: (_) => _focusScope.requestFocus(_alterUrlFocus),
          label: libL10n.user,
          icon: Icons.account_box,
          hint: 'root',
          suggestion: false,
        ),
      ],
    );
  }

  /// Monitor's HTTP API connection fields — shown instead of `_buildAuth()`
  /// when `_useMonitorHttp` is selected, never alongside it.
  Widget _buildMonitorHttp() {
    const addr = 'https://127.0.0.1:3770';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(libL10n.network),
        Input(
          controller: _monitorAddrCtrl,
          type: TextInputType.url,
          icon: MingCute.web_line,
          label: 'URL',
          hint: addr,
          suggestion: false,
        ),
        // Prefixed to say which account this is: the agent's panel login, not
        // a system account on the far host. A server reached this way has no
        // system account configured here at all.
        Input(
          controller: _monitorUserCtrl,
          type: TextInputType.text,
          icon: MingCute.user_2_line,
          label: 'Monitor ${libL10n.user}',
          suggestion: false,
        ),
        Input(
          controller: _monitorPwdCtrl,
          type: TextInputType.visiblePassword,
          icon: MingCute.lock_line,
          label: 'Monitor ${libL10n.pwd}',
          obscureText: true,
          suggestion: false,
        ),
        ListTile(
          leading: const Icon(MingCute.certificate_line),
          title: TipText('Monitor ${l10n.ignoreCert}', l10n.pveIgnoreCertTip),
          trailing: _monitorIgnoreCert.listenVal(
            (v) => Switch(
              value: v,
              onChanged: (val) {
                _monitorIgnoreCert.value = val;
              },
            ),
          ),
        ).cardx,
        ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: TipText(
            l10n.monitorAllowInsecureHttp,
            l10n.monitorAllowInsecureHttpTip,
          ),
          trailing: _monitorAllowInsecure.listenVal(
            (v) => Switch(
              value: v,
              onChanged: (val) {
                _monitorAllowInsecure.value = val;
              },
            ),
          ),
        ).cardx,
      ],
    );
  }

  Widget _buildCustomCmds() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.customCmd),
        // No count and no preview: the commands are on the server, and this
        // page has not asked it. The editor is what reads them.
        ListTile(
          leading: const Icon(MingCute.command_line),
          title: Text(libL10n.edit),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: _onTapCustomItem,
        ).cardx,
        ListTile(
          leading: const Icon(MingCute.doc_line),
          title: Text(libL10n.doc),
          trailing: const Icon(Icons.open_in_new, size: 17),
          onTap: libL10n.customCmdDocUrl.launchUrl,
        ).cardx,
      ],
    );
  }

  Widget _buildStorageCollection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(libL10n.disk),
        _disabledCmdTypes.listenVal((_) {
          final diskInfoEnabled = !_isCmdGroupDisabled(_diskInfoCmdTypes);
          final diskHealthEnabled = !_isCmdGroupDisabled(_diskHealthCmdTypes);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.storage),
                title: Text(libL10n.disk),
                subtitle: Text(
                  _diskInfoCmdTypes.map((e) => e.displayName).join(', '),
                  style: UIs.textGrey,
                ),
                trailing: Switch(
                  value: diskInfoEnabled,
                  onChanged: (value) {
                    _setCmdGroupDisabled(_diskInfoCmdTypes, !value);
                  },
                ),
                onTap: () {
                  _setCmdGroupDisabled(_diskInfoCmdTypes, diskInfoEnabled);
                },
              ).cardx,
              ListTile(
                leading: const Icon(MingCute.heartbeat_line),
                title: Text(l10n.diskHealth),
                subtitle: Text(
                  _diskHealthCmdTypes.map((e) => e.displayName).join(', '),
                  style: UIs.textGrey,
                ),
                trailing: Switch(
                  value: diskHealthEnabled,
                  onChanged: (value) {
                    _setCmdGroupDisabled(_diskHealthCmdTypes, !value);
                  },
                ),
                onTap: () {
                  _setCmdGroupDisabled(_diskHealthCmdTypes, diskHealthEnabled);
                },
              ).cardx,
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDisabledCmdTypes() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle('${libL10n.disabled} ${libL10n.cmd}'),
        _disabledCmdTypes.listenVal((disabled) {
          return ListTile(
            leading: const Icon(Icons.disabled_by_default),
            title: Text('${libL10n.disabled} ${libL10n.cmd}'),
            subtitle: disabled.isEmpty
                ? null
                : Text(disabled.join(', '), style: UIs.textGrey),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: _onTapDisabledCmdTypes,
          );
        }).cardx,
      ],
    );
  }

  Widget _buildBmc() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CenterGreyTitle('BMC (Redfish)'),
        // A row of its own rather than a suffix on the title, the same shape
        // the Linux page uses: what a suffix cannot say is the part that
        // matters, which is that nothing here is guaranteed. This is where
        // someone decides to turn it on, so it is where the warning belongs.
        ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('Beta'),
          subtitle: Text(l10n.betaTip, style: UIs.textGrey),
        ).cardx,
        ListTile(
          leading: const Icon(BoxIcons.bxs_help_circle),
          title: TipText(libL10n.about, l10n.bmcTip),
        ).cardx,
        Input(
          controller: _bmcAddrCtrl,
          type: TextInputType.url,
          label: libL10n.addr,
          icon: MingCute.web_line,
          hint: 'https://10.0.0.9',
          suggestion: false,
        ),
        _buildBmcAccount(),
        _buildBmcCert(),
      ],
    );
  }

  /// Which account this server's BMC is opened with.
  ///
  /// A picker rather than a user and a password field, because the account is
  /// shared: BMCs are provisioned a rack at a time, so the same credentials
  /// open twenty of them. Typed per server, a rotation means twenty edits and
  /// no way to tell which one was missed.
  ///
  /// The subtitle says how many servers point at the record, since editing it
  /// here changes what all of them use.
  Widget _buildBmcAccount() {
    return _bmcCredId.listenVal((id) {
      // Watched rather than fetched: editing the account from the page this
      // tile opens has to be visible here when it returns.
      final creds = ref.watch(bmcCredentialProvider).creds;
      final cred = creds.firstWhereOrNull((e) => e.id == id);
      final shared = cred == null
          ? 0
          : ref.read(bmcCredentialProvider.notifier).serversUsing(cred.id);
      return ListTile(
        leading: Icon(
          cred == null ? Icons.person_off_outlined : Icons.person,
          color: cred == null ? Colors.orange : null,
        ),
        title: Text(l10n.bmcAccount),
        subtitle: Text(
          switch (cred) {
            null => l10n.bmcAccountUnset,
            final c when shared > 1 =>
              '${c.name} (${c.user}) - ${l10n.bmcAccountShared(shared)}',
            final c => '${c.name} (${c.user})',
          },
          style: UIs.textGrey,
        ),
        trailing: cred == null
            ? const Icon(Icons.keyboard_arrow_right)
            : IconButton(
                icon: const Icon(Icons.edit),
                // Awaited, and the result read back. That page can delete the
                // account, and leaving without doing so left `_bmcCredId`
                // naming a row that is gone: the tile rebuilt as "none picked"
                // from the provider while the value behind it did not move, so
                // the two disagreed with nothing on screen to say so, and Save
                // took a foreign key error out of the editor.
                onPressed: () async {
                  await BmcCredentialEditPage.route.go(
                    context,
                    args: BmcCredentialEditPageArgs(cred: cred),
                  );
                  if (!mounted) return;
                  final live = ref.read(bmcCredentialProvider).creds;
                  if (!live.any((e) => e.id == cred.id)) {
                    _bmcCredId.value = null;
                  }
                },
              ),
        onTap: _onTapBmcAccount,
      ).cardx;
    });
  }

  /// The certificate the BMC presents, and whether it has been reviewed.
  ///
  /// A step of its own because it has to be: the TLS callbacks that decide
  /// whether to accept a certificate are synchronous, so the question cannot be
  /// put to anyone from inside them. Reviewing here means the check at request
  /// time answers by itself, with nothing to interrupt — see `cert_pin.dart`.
  Widget _buildBmcCert() {
    return _bmcCert.listenVal((pinned) {
      final has = pinned?.isNotEmpty == true;
      return ListTile(
        leading: Icon(
          has ? Icons.verified_user : Icons.gpp_maybe,
          color: has ? null : Colors.orange,
        ),
        title: Text(l10n.bmcCert),
        subtitle: Text(
          has ? l10n.bmcCertPinned : l10n.bmcCertUnreviewed,
          style: UIs.textGrey,
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _onTapBmcCert,
      ).cardx;
    });
  }

  Widget _buildWOLs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CenterGreyTitle('Wake On LAN (beta)'),
        ListTile(
          leading: const Icon(BoxIcons.bxs_help_circle),
          title: TipText(libL10n.about, l10n.wolTip),
        ).cardx,
        Input(
          controller: _wolMacCtrl,
          type: TextInputType.text,
          label: 'MAC ${libL10n.addr}',
          icon: Icons.computer,
          hint: '00:11:22:33:44:55',
          suggestion: false,
        ),
        Input(
          controller: _wolIpCtrl,
          type: TextInputType.text,
          label: 'IP ${libL10n.addr}',
          icon: ZondIcons.network,
          hint: '192.168.1.x',
          suggestion: false,
        ),
        Input(
          controller: _wolPwdCtrl,
          type: TextInputType.text,
          obscureText: true,
          label: libL10n.pwd,
          icon: Icons.password,
          suggestion: false,
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _onSave,
      child: const Icon(Icons.save),
    );
  }

  Widget _buildJumpServer() {
    const padding = EdgeInsets.only(left: 13, right: 13, bottom: 7);
    final srvs = ref
        .watch(serversProvider)
        .servers
        .values
        .where((e) => e.id != spi?.id)
        .where((e) => !_isInvalidJumpSelection(e.id))
        .toList();
    final choice = _jumpServers.listenVal((val) {
      final selectedSrvs = <Spi>[];
      for (final id in val) {
        final srv = srvs.firstWhereOrNull((e) => e.id == id);
        if (srv != null) selectedSrvs.add(srv);
      }
      return Choice<Spi>(
        multiple: true,
        clearable: true,
        value: selectedSrvs,
        builder: (state, _) => Wrap(
          children: List<Widget>.generate(srvs.length, (index) {
            final item = srvs[index];
            final selectedIndex = val.indexOf(item.id);
            return ChoiceChipX<Spi>(
              key: ValueKey(item),
              label: selectedIndex == -1
                  ? item.name
                  : '${selectedIndex + 1}. ${item.name}',
              state: state,
              value: item,
              onSelected: (srv, on) {
                final next = List<String>.from(_jumpServers.value);
                if (on) {
                  if (next.contains(srv.id)) return;
                  if (next.length >= 2) {
                    Toast.show('${l10n.jumpServer}: 2');
                    return;
                  }
                  next.add(srv.id);
                } else {
                  next.remove(srv.id);
                }
                _jumpServers.value = next;
              },
            );
          }),
        ),
      );
    });
    return ExpandTile(
      leading: const Icon(Icons.map),
      initiallyExpanded: _jumpServers.value.isNotEmpty,
      childrenPadding: padding,
      title: Text(l10n.jumpServer),
      children: [choice],
    ).cardx;
  }

  Widget _buildDiscoverBtn() {
    return IconButton(
      tooltip: l10n.discoverSshServers,
      onPressed: _onTapDiscover,
      icon: const Icon(Icons.radar),
    );
  }

  Widget _buildWriteScriptTip() {
    return IconButton(
      tooltip: libL10n.attention,
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: l10n.writeScriptTip),
          actions: Btnx.oks,
        );
      },
      icon: const Icon(Icons.tips_and_updates),
    );
  }

  Widget _buildDelBtn() {
    return IconButton(tooltip: libL10n.delete, 
      onPressed: () async {
        // The dialog answers; this — which is on the page — acts on the answer
        // and then closes the page. Doing both from inside the button meant
        // two pops in a row from a callback that can see two navigators: the
        // dialog is on the root one, and this page may be inside a pane, so
        // whichever `pop` was written first decided which of the two closed.
        final confirmed = await context.showRoundDialog<bool>(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue(
              '${libL10n.delete} ${libL10n.server}(${spi!.name})',
            ),
          ),
          actions: Btn.ok(red: true).toList,
        );
        if (confirmed != true || !mounted) return;
        await ref.read(serversProvider.notifier).delServer(spi!.id);
        if (!mounted) return;
        context.pop(true);
      },
      icon: const Icon(Icons.delete),
    );
  }
}

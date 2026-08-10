part of 'edit.dart';

/// Where a monitor-reached server's shell comes from.
///
/// One question with three answers, rather than the two independent switches
/// this used to be. They were never independent: [Spix.validate] rejects
/// having both, so the form could reach a state it would then refuse to save
/// — a delayed error message dressed up as a choice. Stating it as a choice
/// also puts the two SSH-account fields underneath the option that owns them,
/// instead of beside a second account with the same field labels.
enum _ShellSource {
  /// Status only. Every shell-backed feature is unavailable, which is the
  /// honest default for a server that has only ever been given a monitor URL.
  none,

  /// SSH relayed by the agent. Real SSH, so it answers everything: terminal,
  /// SFTP, port forwarding, containers.
  tunnel,

  /// A PTY from the agent itself, with no SSH credentials. A terminal and
  /// nothing else, and it makes the monitor password worth a shell.
  passwordless,
}

extension _Widgets on _ServerEditPageState {
  Widget _buildAuth() {
    final switch_ = ListTile(
      title: Text(l10n.keyAuth),
      trailing: _keyIdx.listenVal(
        (v) => Switch(
          value: v != null,
          onChanged: (val) {
            if (val) {
              _keyIdx.value = -1;
            } else {
              _keyIdx.value = null;
            }
          },
        ),
      ),
    );

    /// Put [switch_] out of [ValueBuilder] to avoid rebuild
    return _keyIdx.listenVal((v) {
      final children = <Widget>[switch_];
      if (v != null) {
        children.add(_buildKeyAuth());
      } else {
        children.add(
          Input(
            controller: _passwordController,
            obscureText: true,
            type: TextInputType.text,
            label: libL10n.pwd,
            icon: Icons.password,
            suggestion: false,
            onSubmitted: (_) => _onSave(),
          ),
        );
      }
      return Column(children: children);
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
                  label: item.id,
                  state: state,
                  value: index,
                  onSelected: (idx, on) {
                    if (on) {
                      keyIdx.value = idx;
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
      title: Text(l10n.more),
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
        _buildScriptDir(),
        _buildEnvs(),
        _buildPVEs(),
        _buildCustomCmds(),
        _buildStorageCollection(),
        _buildDisabledCmdTypes(),
        _buildCustomDev(),
        _buildWOLs(),
      ],
    );
  }

  Widget _buildSudoPassword() {
    return _hasStoredSudoPassword.listenVal((hasValue) {
      final subtitle = switch (hasValue) {
        true => Text(l10n.configured, style: UIs.textGrey),
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
        title: Text(l10n.system),
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
    return Input(
      controller: _proxyCommandCtrl,
      type: TextInputType.multiline,
      node: _proxyCommandFocus,
      label: 'ProxyCommand',
      icon: MingCute.command_line,
      hint: 'socat - PROXY:x.x.x.x:%h:%p,proxyport=5002',
      suggestion: false,
      maxLines: 3,
    );
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
        // Prefixed because the shell section below has a second account with
        // the same two labels, and they are not interchangeable: this one is
        // the panel login, that one is a system account on the far host.
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
        const CenterGreyTitle('Shell'),
        _buildShellSource(),
      ],
    );
  }

  _ShellSource get _shellSource {
    if (_sshViaMonitor.value) return _ShellSource.tunnel;
    if (_passwordlessTerminal.value) return _ShellSource.passwordless;
    return _ShellSource.none;
  }

  void _setShellSource(_ShellSource source) {
    _sshViaMonitor.value = source == _ShellSource.tunnel;
    _passwordlessTerminal.value = source == _ShellSource.passwordless;
  }

  /// The shell choice, and the fields belonging to whichever option owns them.
  Widget _buildShellSource() {
    return ListenableBuilder(
      listenable: Listenable.merge([_sshViaMonitor, _passwordlessTerminal]),
      builder: (_, _) {
        final selected = _shellSource;
        Widget option(_ShellSource value, IconData icon, Widget title) {
          return ListTile(
            leading: Icon(icon),
            title: title,
            trailing: Radio<_ShellSource>(value: value),
            onTap: () => _setShellSource(value),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<_ShellSource>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) _setShellSource(value);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A dash rather than a prohibition sign: this is the
                  // ordinary default for a server that only reports status,
                  // not something that has been forbidden. Same reason the
                  // label says what the server has rather than "Disabled",
                  // which in a list of options reads as "unavailable".
                  option(
                    _ShellSource.none,
                    Icons.horizontal_rule,
                    Text(l10n.shellSourceNone),
                  ),
                  option(
                    _ShellSource.tunnel,
                    Icons.terminal,
                    TipText(l10n.sshViaMonitor, l10n.sshViaMonitorTip),
                  ),
                  option(
                    _ShellSource.passwordless,
                    Icons.lock_open,
                    TipText(
                      l10n.passwordlessTerminal,
                      l10n.passwordlessTerminalTip,
                    ),
                  ),
                ],
              ),
            ).cardx,
            if (selected == _ShellSource.tunnel) _buildTunnelCredential(),
          ],
        );
      },
    );
  }

  /// The SSH account the agent logs in as on the far host.
  ///
  /// Deliberately has no host/port field: the agent connects to the address in
  /// its own `remote_access.ssh_addr` and refuses to take one from a client,
  /// which is what stops it being usable to reach anything else on its
  /// network. All that is needed here is who to log in as.
  ///
  /// Labels carry the `SSH` prefix because the network section above has a
  /// second account with the same two labels. They are not interchangeable —
  /// that one is the panel login, this one has to exist on the far host and
  /// be permitted by its sshd.
  Widget _buildTunnelCredential() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Input(
          controller: _tunnelUserCtrl,
          type: TextInputType.text,
          label: 'SSH ${libL10n.user}',
          icon: Icons.account_box,
          hint: 'root',
          suggestion: false,
        ),
        ListTile(
          title: Text(l10n.keyAuth),
          trailing: _tunnelKeyIdx.listenVal(
            (v) => Switch(
              value: v != null,
              onChanged: (val) => _tunnelKeyIdx.value = val ? -1 : null,
            ),
          ),
        ).cardx,
        _tunnelKeyIdx.listenVal((v) {
          if (v != null) return _buildKeyAuthFor(_tunnelKeyIdx);
          return Input(
            controller: _tunnelPwdCtrl,
            obscureText: true,
            type: TextInputType.text,
            label: 'SSH ${libL10n.pwd}',
            icon: Icons.password,
            suggestion: false,
          );
        }),
      ],
    );
  }

  Widget _buildCustomCmds() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle(l10n.customCmd),
        _customCmds.listenVal((vals) {
          return ListTile(
            leading: const Icon(BoxIcons.bxs_file_json),
            title: const Text('JSON'),
            subtitle: vals.isEmpty
                ? null
                : Text(vals.keys.join(','), style: UIs.textGrey),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: _onTapCustomItem,
          );
        }).cardx,
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
          label: 'MAC ${l10n.addr}',
          icon: Icons.computer,
          hint: '00:11:22:33:44:55',
          suggestion: false,
        ),
        Input(
          controller: _wolIpCtrl,
          type: TextInputType.text,
          label: 'IP ${l10n.addr}',
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
                    context.showSnackBar('${l10n.jumpServer}: 2');
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
    return IconButton(
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue(
              '${libL10n.delete} ${libL10n.server}(${spi!.name})',
            ),
          ),
          actions: Btn.ok(
            onTap: () async {
              // Two different navigators: the dialog is on the root one, and
              // this page may be inside a pane. Popping the page's own stack
              // to close a dialog dismissed the page and left the dialog up.
              context.popDialog();
              await ref.read(serversProvider.notifier).delServer(spi!.id);
              if (!mounted) return;
              context.pop(true);
            },
            red: true,
          ).toList,
        );
      },
      icon: const Icon(Icons.delete),
    );
  }
}

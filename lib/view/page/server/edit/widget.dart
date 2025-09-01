part of 'edit.dart';

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

  Widget _buildKeyAuth() {
    const padding = EdgeInsets.only(left: 13, right: 13, bottom: 7);
    final privateKeyState = ref.watch(privateKeyNotifierProvider);
    final pkis = privateKeyState.keys;

    final choice = _keyIdx.listenVal((val) {
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
                  label: item.id,
                  state: state,
                  value: index,
                  onSelected: (idx, on) {
                    if (on) {
                      _keyIdx.value = idx;
                    } else {
                      _keyIdx.value = -1;
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
      initiallyExpanded: _keyIdx.value != null && _keyIdx.value! >= 0,
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
        Input(
          controller: _logoUrlCtrl,
          type: TextInputType.url,
          icon: Icons.image,
          label: 'Logo URL',
          hint: 'https://example.com/logo.png',
          suggestion: false,
        ),
        _buildAltUrl(),
        _buildScriptDir(),
        _buildEnvs(),
        _buildPVEs(),
        _buildCustomCmds(),
        _buildDisabledCmdTypes(),
        _buildCustomDev(),
        _buildWOLs(),
      ],
    );
  }

  Widget _buildScriptDir() {
    return Input(
      controller: _scriptDirCtrl,
      type: TextInputType.text,
      label: '${l10n.remotePath} (Shell ${l10n.install})',
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
          label: l10n.temperature,
          icon: MingCute.low_temperature_line,
          hint: 'nvme-pci-0400',
          suggestion: false,
        ),
        Input(
          controller: _netDevCtrl,
          type: TextInputType.text,
          label: l10n.net,
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
      label: l10n.fallbackSshDest,
      icon: MingCute.link_line,
      hint: 'user@ip:port',
      suggestion: false,
    );
  }

  Widget _buildPVEs() {
    const addr = 'https://127.0.0.1:8006';
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
          onTap: l10n.customCmdDocUrl.launchUrl,
        ).cardx,
      ],
    );
  }

  Widget _buildDisabledCmdTypes() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenterGreyTitle('${libL10n.disabled} ${l10n.cmd}'),
        _disabledCmdTypes.listenVal((disabled) {
          return ListTile(
            leading: const Icon(Icons.disabled_by_default),
            title: Text('${libL10n.disabled} ${l10n.cmd}'),
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
        .watch(serversNotifierProvider)
        .servers
        .values
        .where((e) => e.jumpId == null)
        .where((e) => e.id != spi?.id)
        .toList();
    final choice = _jumpServer.listenVal((val) {
      final srv = srvs.firstWhereOrNull((e) => e.id == _jumpServer.value);
      return Choice<Spi>(
        multiple: false,
        clearable: true,
        value: srv != null ? [srv] : [],
        builder: (state, _) => Wrap(
          children: List<Widget>.generate(srvs.length, (index) {
            final item = srvs[index];
            return ChoiceChipX<Spi>(
              label: item.name,
              state: state,
              value: item,
              onSelected: (srv, on) {
                if (on) {
                  _jumpServer.value = srv.id;
                } else {
                  _jumpServer.value = null;
                }
              },
            );
          }),
        ),
      );
    });
    return ExpandTile(
      leading: const Icon(Icons.map),
      initiallyExpanded: _jumpServer.value != null,
      childrenPadding: padding,
      title: Text(l10n.jumpServer),
      children: [choice],
    ).cardx;
  }

  Widget _buildWriteScriptTip() {
    return Btn.tile(
      text: libL10n.attention,
      icon: const Icon(Icons.tips_and_updates, color: Colors.grey),
      onTap: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: SimpleMarkdown(data: l10n.writeScriptTip),
          actions: Btnx.oks,
        );
      },
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildQrScan() {
    return Btn.tile(
      text: libL10n.import,
      icon: const Icon(Icons.qr_code, color: Colors.grey),
      onTap: () async {
        final ret = await BarcodeScannerPage.route.go(
          context,
          args: const BarcodeScannerPageArgs(),
        );
        final code = ret?.text;
        if (code == null) return;
        try {
          final spi = Spi.fromJson(json.decode(code));
          _initWithSpi(spi);
        } catch (e, s) {
          context.showErrDialog(e, s);
        }
      },
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildSSHImport() {
    return Btn.tile(
      text: l10n.sshConfigImport,
      icon: const Icon(Icons.settings, color: Colors.grey),
      onTap: _onTapSSHImport,
      textStyle: UIs.textGrey,
      mainAxisSize: MainAxisSize.min,
    );
  }

  Widget _buildDelBtn() {
    return IconButton(
      onPressed: () {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue(
              '${libL10n.delete} ${l10n.server}(${spi!.name})',
            ),
          ),
          actions: Btn.ok(
            onTap: () async {
              context.pop();
              ref.read(serversNotifierProvider.notifier).delServer(spi!.id);
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

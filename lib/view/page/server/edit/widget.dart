part of 'edit.dart';

/// One of the two ways into a server, as the connection list draws it.
enum _Method {
  monitorHttp,
  ssh;

  IconData get icon => switch (this) {
    _Method.monitorHttp => MingCute.web_line,
    _Method.ssh => Icons.terminal,
  };

  String get label => switch (this) {
    _Method.monitorHttp => 'Monitor HTTP',
    _Method.ssh => 'SSH',
  };
}

extension _Widgets on _ServerEditPageState {
  Widget _buildGroupTitle(String title) => GroupTitle(title);

  /// A line of explanation under a group, in the form's own voice.
  Widget _buildGroupNote(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
    child: Text(text, style: UIs.text12Grey),
  );

  // --- The two ways in ---

  /// The order the two methods are dialled in, first to last.
  List<_Method> get _methodOrder => _preferMonitorHttp.value
      ? const [_Method.monitorHttp, _Method.ssh]
      : const [_Method.ssh, _Method.monitorHttp];

  bool _methodOn(_Method method) => switch (method) {
    _Method.monitorHttp => _useMonitorHttp.value,
    _Method.ssh => _useSsh.value,
  };

  /// The address below an enabled connection method.
  String _methodSummary(_Method method) {
    if (!_methodOn(method)) return '';
    return switch (method) {
      _Method.monitorHttp => _monitorAddrCtrl.text.selfNotEmptyOrNull ?? '',
      _Method.ssh => [
        if (_ipController.text.trim().isNotEmpty)
          '${_usernameController.text.selfNotEmptyOrNull ?? 'root'}'
              '@${_ipController.text.trim()}'
              ':${_portController.text.selfNotEmptyOrNull ?? '22'}',
      ].join(),
    };
  }

  /// Both ways in, in the order they are dialled, each with its own switch.
  ///
  /// One list rather than two switches and a segmented control below them. The
  /// order *is* the list, so there is nothing to keep in step: a method that is
  /// off has no number, and the one at the top is the one that is tried first.
  ///
  /// Turning the last one off is allowed, and says so rather than being
  /// refused. What it produces is a server with no way in, which the save
  /// refuses through `Spix.validate` — a switch that will not move leaves the
  /// user guessing which of the two the app objected to.
  /// [otherIsLocal] is whether another server already is this device.
  Widget _buildConnectionGroup({required bool otherIsLocal}) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _useSsh,
        _useMonitorHttp,
        _preferMonitorHttp,
        _local,
      ]),
      builder: (_, _) {
        // Offered where this build can read this device and no other server
        // already is it — two would be one machine polled twice under two
        // names. Kept on screen wherever this record already says it is one:
        // a server synced from a desktop has to be switchable back on a phone.
        final localRow =
            (LocalServer.isSupported && !otherIsLocal) || _local.value
            ? _buildLocalRow()
            : null;
        if (_local.value) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGroupTitle(l10n.connection),
              ?localRow,
              _buildGroupNote(
                LocalServer.isSupported
                    ? l10n.localServerTip
                    : l10n.localServerUnsupported,
              ),
            ],
          );
        }

        final order = _methodOrder;
        final live = order.where(_methodOn).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupTitle(l10n.connection),
            ?localRow,
            _buildGroupNote(l10n.connectionTip),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // The handle is drawn where the design puts it, at the start of
              // the row: the default listener wraps the whole tile, which on a
              // row carrying a switch means a long press anywhere picks it up.
              buildDefaultDragHandles: false,
              onReorderItem: (_, _) =>
                  _preferMonitorHttp.value = !_preferMonitorHttp.value,
              children: [
                for (final (at, method) in order.indexed)
                  _buildMethodRow(method, at: at, live: live),
              ],
            ),
            if (live.isEmpty) _buildGroupNote(l10n.transportNoneOn),
          ],
        );
      },
    );
  }

  /// The switch that makes this server the device the app runs on.
  ///
  /// Above the two methods rather than a third row among them: those are
  /// ordered and this is not, and while it is on they are not dialled at all.
  Widget _buildLocalRow() {
    return ListTile(
      leading: const Icon(Icons.computer),
      title: Text(l10n.thisDevice),
      subtitle: Text(
        Platform.localHostname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text12Grey,
      ),
      trailing: SwitchX(
        value: _local.value,
        onChanged: (v) => _local.value = v,
      ),
      onTap: () => _local.value = !_local.value,
    ).cardx;
  }

  Widget _buildMethodRow(
    _Method method, {
    required int at,
    required List<_Method> live,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final on = _methodOn(method);
    final ordinal = on ? '${live.indexOf(method) + 1}' : '—';
    final leads = on && live.firstOrNull == method;
    final summary = _methodSummary(method);

    return CardX(
      key: ValueKey(method),
      child: InkWell(
          // Tapping the row promotes it, so the order is reachable without a
          // drag: two rows are a long press and a short travel, which is a lot
          // of gesture for a choice between two things.
          onTap: () => _preferMonitorHttp.value =
              method == _Method.monitorHttp,
          child: Padding(
            // 5 rather than the design's 9, because Material's switch is not
            // the design's. `shrinkWrap` already dropped its tap target, and
            // what is left — `_kSwitchMinSize`, 40 — is still taller than the
            // two lines of text beside it, so the row's height is the switch's
            // and the padding is the only part of it this page decides.
            padding: const EdgeInsets.fromLTRB(7, 5, 13, 5),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: at,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 19,
                    color: UIs.textGrey.color,
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: leads
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    ordinal,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: leads
                          ? scheme.onPrimary
                          : on
                          ? null
                          : UIs.textGrey.color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(method.icon, size: 19, color: UIs.textGrey.color),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: on ? null : UIs.textGrey.color,
                        ),
                      ),
                      if (summary.isNotEmpty)
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text12Grey,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                SwitchX(
                  value: on,
                  onChanged: (val) => switch (method) {
                    _Method.monitorHttp => _useMonitorHttp.value = val,
                    _Method.ssh => _useSsh.value = val,
                  },
                ),
              ],
            ),
          ),
        ),
    );
  }

  /// One method's own fields, under a heading that says what it is for.
  ///
  /// The fields stay on the page when the switch is off — that is what off
  /// means — but a section that showed them with nothing to say about them
  /// would read as a method that is on, so what a switched-off section carries
  /// is one line saying they are kept.
  Widget _buildMethodSection(_Method method, Widget fields) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _useSsh,
        _useMonitorHttp,
        _preferMonitorHttp,
      ]),
      builder: (_, _) {
        final title = switch (method) {
          _Method.monitorHttp => l10n.monitorAgent,
          _Method.ssh => 'SSH',
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupTitle(title),
            if (!_methodOn(method))
              _buildGroupNote(l10n.transportSectionOff)
            else
              fields,
          ],
        );
      },
    );
  }

  Widget _buildAuth() {
    // Reads both sources: a server imported with an IdentityFile authenticates
    // with a key even though nothing is selected among the stored ones, and a
    // switch that showed "off" there would be describing the wrong thing.
    final switch_ = ListTile(
      title: Text(l10n.keyAuth),
      trailing: _keyIdx.listenVal(
        (idx) => _keyPath.listenVal(
          (path) => SwitchX(
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
          tooltip: libL10n.close,
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

  /// What this server does once it is reachable.
  ///
  /// Separate from the connection above because none of it is about getting
  /// there, and separate from `Optional` below because every server has an
  /// answer to all three whether or not anybody set one.
  Widget _buildBehaviourGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(l10n.behaviour),
        ListTile(
          leading: const Icon(Icons.bolt),
          title: Text(l10n.autoConnect),
          trailing: _autoConnect.listenVal(
            (val) => SwitchX(
              value: val,
              onChanged: (val) {
                _autoConnect.value = val;
              },
            ),
          ),
        ).cardx,
        _buildSudoPassword(),
        _buildEnvs(),
      ],
    );
  }

  /// Everything a server can have and most do not.
  ///
  /// One `More` held fifteen entries in a flat list, so finding Wake on LAN
  /// meant reading past a logo URL and a coordinate. They are grouped by the
  /// question they answer and each group is folded, which also gives the four
  /// that are whole subsystems — PVE, the BMC, Wake on LAN, what the status
  /// script collects — a name on the page instead of a row in the middle of
  /// one.
  ///
  /// [ExpandTile] rather than a page each: a group's fields belong to the
  /// server being edited, and a page would be a second form with its own save.
  Widget _buildOptionalGroup() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(l10n.optional),
        _buildOptionalTile(
          icon: Icons.tune,
          title: l10n.sshAdvanced,
          summary: l10n.sshAdvancedTip,
          children: [
            _buildAltUrl(),
            _buildProxyCommand(),
            _buildJumpServer(),
            _buildFileTransport(),
            _buildAllowLegacyAlgorithms(),
            _buildScriptDir(),
            _buildSystemType(),
          ],
        ),
        _buildOptionalTile(
          icon: Icons.image_outlined,
          title: l10n.appearanceAndPlace,
          summary: l10n.appearanceAndPlaceTip,
          children: [
            Input(
              controller: _logoUrlCtrl,
              type: TextInputType.url,
              icon: Icons.image,
              label: 'Logo URL',
              hint: 'https://example.com/logo.png',
              suggestion: false,
            ),
            _buildGeo(),
          ],
        ),
        // Where "remove temperature from the status script" is actually done,
        // which is what the detail page's advice on an unreadable section
        // points at.
        _buildOptionalTile(
          icon: MingCute.dashboard_line,
          title: l10n.statusCollection,
          summary: l10n.statusCollectionTip,
          children: [
            _buildDisabledCmdTypes(),
            _buildCustomCmds(),
            _buildStorageCollection(),
            _buildCustomDev(),
          ],
        ),
        _buildOptionalTile(
          icon: MingCute.server_line,
          title: 'PVE',
          summary: 'Proxmox VE',
          children: [_buildPVEs()],
        ),
        _buildOptionalTile(
          icon: MingCute.chip_line,
          title: 'BMC (Redfish)',
          // The word, not the sentence: a right-aligned summary is a phrase
          // read at a glance. The sentence is under the heading's `?`, first,
          // because what matters about this one is that nothing here is
          // guaranteed and this is where someone decides to turn it on.
          summary: 'Beta',
          tip: '${l10n.betaTip}\n\n${l10n.bmcTip}',
          children: [_buildBmc()],
        ),
        _buildOptionalTile(
          icon: Icons.power_settings_new,
          title: 'Wake on LAN',
          summary: 'Beta',
          tip: '${l10n.betaTip}\n\n${l10n.wolTip}',
          children: [_buildWOLs()],
        ),
      ],
    );
  }

  /// A folded group: what it is on the left, what it amounts to on the right,
  /// and its fields as rows below rather than inside it.
  ///
  /// [ExpandableTile] rather than `ExpandTile`, because an `ExpansionTile`
  /// holds its children inside itself: a card around it put the fields inside
  /// the header's card, and no card left the header the one row on this page
  /// without one. Every other row of this form is a card, and opening a group
  /// should add rows, not grow a box.
  ///
  /// [tip] is what the group used to spend a row of its own explaining. A
  /// whole tile for a paragraph nobody reads twice was the first thing inside
  /// two of these groups, above the fields they describe; on the heading it is
  /// one glyph, and it is there before the group is opened.
  Widget _buildOptionalTile({
    required IconData icon,
    required String title,
    required String summary,
    required List<Widget> children,
    String? tip,
  }) {
    return ExpandableTile(
      leading: Icon(icon),
      title: tip == null ? Text(title) : TipText(title, tip),
      summary: Text(summary),
      children: children,
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

  /// Where this server is, when the app has no way to find out.
  ///
  /// The tip is its own row because [Input] takes a label rather than a
  /// widget, so there is nowhere in the field itself to say what the numbers
  /// are for — and "Location" on a page full of addresses reads as another
  /// one.
  Widget _buildGeo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(MingCute.question_line),
          title: TipText(libL10n.location, l10n.locationTip),
        ).cardx,
        Input(
          controller: _geoCtrl,
          // The plain text keyboard, not a numeric one. Android's numeric IME
          // offers digits, `-` and `.` and neither a comma nor a space — so
          // with `numberWithOptions` the only thing that could be typed here
          // was `39.9042116.4074`, which does not parse, and saving is now
          // refused rather than silently dropped. The comment that used to sit
          // here said this and the code did the opposite.
          type: TextInputType.text,
          icon: Icons.public,
          label: '${libL10n.location} (lat, lon)',
          hint: '39.9042, 116.4074',
          suggestion: false,
        ),
      ],
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
            (v) => SwitchX(
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
    // Follows the *SSH* switch. Nothing to set with SSH off: saving then
    // writes `ssh: null`, so a choice made here would be accepted, saved and
    // discarded without a word. It used to follow the monitor switch, which
    // was the same question only while the two were exclusive — a server
    // carrying both had its file transport hidden and could not be told to
    // use SCP.
    return _useSsh.listenVal((useSsh) {
      if (!useSsh) return UIs.placeholder;
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

  /// Whether this host is allowed the algorithms SSH has retired.
  ///
  /// Follows the *SSH* switch, for the file transport's reason: with SSH off
  /// the save writes `ssh: null`, so a choice made here would be accepted,
  /// saved and discarded without a word.
  ///
  /// A switch rather than something the app finds out for itself. The handshake
  /// is where the answer would be, and the only way to get there is to try a
  /// set the server has already refused — which for a host that *is* current
  /// means giving a stranger a list containing SHA-1 that they do not need.
  Widget _buildAllowLegacyAlgorithms() {
    return _useSsh.listenVal((useSsh) {
      if (!useSsh) return UIs.placeholder;
      return _allowLegacyAlgorithms.listenVal((val) {
        return ListTile(
          leading: const Icon(MingCute.lock_line),
          title: TipText(
            l10n.sshLegacyAlgorithms,
            l10n.sshLegacyAlgorithmsTip,
          ),
          trailing: SwitchX(
            value: val,
            onChanged: (v) => _allowLegacyAlgorithms.value = v,
          ),
          onTap: () => _allowLegacyAlgorithms.value = !val,
        ).cardx;
      });
    });
  }

  /// The PVE address, how to log in, and the certificate that was confirmed.
  ///
  /// Token first: it is what a new configuration gets, and what PVE itself
  /// recommends for an app — its permissions are its own and it never asks for
  /// a TOTP code. The password stays for configurations that already use it.
  Widget _buildPVEs() {
    const addr = 'https://127.0.0.1:8006';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Input(
          controller: _pveAddrCtrl,
          type: TextInputType.url,
          icon: MingCute.web_line,
          label: 'URL',
          hint: addr,
          suggestion: false,
        ),
        _buildPveAuthMode(),
        _pveUseToken.listenVal((useToken) {
          if (useToken) return _buildPveToken();
          return _buildPvePassword();
        }),
        _buildPveCert(),
      ],
    );
  }

  Widget _buildPveAuthMode() {
    return _pveUseToken.listenVal((useToken) {
      final token = l10n.pveAuthToken;
      final pwd = libL10n.pwd;
      return ListTile(
        leading: const Icon(MingCute.key_2_line),
        title: TipText(
          libL10n.login,
          useToken ? l10n.pveTokenTip : l10n.pvePasswordAuthTip,
        ),
        trailing: PopupMenu<bool>(
          initialValue: useToken,
          items: [
            PopupMenuItem(value: true, child: Text(token)),
            PopupMenuItem(value: false, child: Text(pwd)),
          ],
          onSelected: (value) => _pveUseToken.value = value,
          child: Text(useToken ? token : pwd),
        ),
      ).cardx;
    });
  }

  Widget _buildPveToken() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Input(
          controller: _pveTokenIdCtrl,
          type: TextInputType.text,
          icon: MingCute.user_2_line,
          label: l10n.pveTokenId,
          hint: 'root@pam!serverbox',
          suggestion: false,
        ),
        Input(
          controller: _pveTokenSecretCtrl,
          type: TextInputType.visiblePassword,
          icon: MingCute.lock_line,
          label: l10n.pveTokenSecret,
          hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          obscureText: true,
          suggestion: false,
        ),
      ],
    );
  }

  /// The PVE password, only where the SSH login has none to lend: with a
  /// password there, that is what is sent.
  Widget _buildPvePassword() {
    return _keyIdx.listenVal((v) {
      final useKeyAuth = v != null && v >= 0;
      if (!useKeyAuth) return UIs.placeholder;
      return Input(
        controller: _pvePwdCtrl,
        type: TextInputType.visiblePassword,
        icon: MingCute.lock_line,
        label: l10n.pvePassword,
        hint: l10n.pvePasswordHint,
        obscureText: true,
        suggestion: false,
      );
    });
  }

  /// The certificate the user confirmed, and the way to make the next
  /// connection ask again.
  ///
  /// Nothing here sets it. PVE's certificate is seen when the app connects,
  /// through whichever transport the server uses — which this page cannot
  /// reach — so the confirmation is asked for there.
  Widget _buildPveCert() {
    return _pveCert.listenVal((pinned) {
      final has = pinned != null && pinned.isNotEmpty;
      return ListTile(
        leading: Icon(has ? Icons.verified_user : MingCute.certificate_line),
        title: Text(l10n.bmcCert),
        subtitle: has
            ? SelectableText(
                'SHA-256: ${prettyCertFingerprint(pinned)}',
                style: UIs.textGrey,
              )
            : Text(l10n.pveCertUnpinned, style: UIs.textGrey),
        trailing: has
            ? Btn.icon(
                icon: const Icon(Icons.delete_outline),
                onTap: _onTapForgetPveCert,
              )
            : null,
      ).cardx;
    });
  }

  /// SSH+shell and monitor's HTTP API — peer ways of reaching this server
  /// (see `Spi.monitorHttp`'s doc comment), either or both.
  ///
  /// Two switches rather than the segmented control this replaced. Both at
  /// once is a real configuration: an agent that reports status without
  /// holding a shell open, and sshd for the things the agent has no endpoint
  /// for. What survives of the exclusivity is the order, which only has to be
  /// asked when there are two things to order.
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

  /// The agent's own fields.
  ///
  /// Which of the last two rows is here is decided by the URL, because they
  /// answer questions only one scheme raises: a certificate to trust is an
  /// `https://` question, and permission to send a password in the clear is an
  /// `http://` one. Showing both put a switch on the page that could not
  /// matter whichever way it was set.
  ///
  /// Read as "anything that is not explicitly `http://`", so typing
  /// `https://…` never passes through the plaintext warning on its way: the
  /// callout appears when the user has actually declared plaintext, not while
  /// they are still typing the scheme.
  Widget _buildMonitorHttpFields() {
    const addr = 'https://127.0.0.1:3770';
    return ListenableBuilder(
      listenable: _monitorAddrCtrl,
      builder: (_, _) {
        final plain = _monitorAddrCtrl.text
            .trim()
            .toLowerCase()
            .startsWith('http://');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Input(
              controller: _monitorAddrCtrl,
              type: TextInputType.url,
              icon: MingCute.web_line,
              label: 'URL',
              hint: addr,
              suggestion: false,
            ),
            // Prefixed to say which account this is: the agent's panel login,
            // not a system account on the far host. A server reached this way
            // has no system account configured here at all.
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
            // What a monitor agent *is*, where there is not one yet. It is the
            // only way in on this page that does not exist until something has
            // been installed on the server, which no switch can convey — and
            // once an address is typed the question has been answered, so the
            // explanation goes rather than sitting there for good.
            if (_monitorAddrCtrl.text.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
                child: SimpleMarkdown(
                  data: l10n.monitorHttpTip(Urls.monitorAgentDoc),
                ),
              ),
            if (!plain)
              ListTile(
                leading: const Icon(MingCute.certificate_line),
                title: TipText(
                  'Monitor ${l10n.ignoreCert}',
                  l10n.pveIgnoreCertTip,
                ),
                trailing: _monitorIgnoreCert.listenVal(
                  (v) => SwitchX(
                    value: v,
                    onChanged: (val) {
                      _monitorIgnoreCert.value = val;
                    },
                  ),
                ),
              ).cardx
            else
              _buildPlainHttpCallout(),
          ],
        );
      },
    );
  }

  /// The warning a plaintext URL raises, with the permission it is about
  /// inside it.
  ///
  /// `Allow HTTP` is not a setting that happens to sit near a warning — it *is*
  /// the warning's answer, and the app refuses to call a plain-http URL
  /// without it. Separated, the switch read as an option and the warning read
  /// as something that had already been decided.
  Widget _buildPlainHttpCallout() {
    final scheme = Theme.of(context).colorScheme;
    return CardX(
      // Lifted off the colour every other row uses. This is the one thing on
      // the page that is not a field but a warning about one, and on the card
      // colour it read as another field that had failed to draw.
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 19,
                  color: scheme.error,
                ),
                const SizedBox(width: 9),
                // Both lines beside the icon rather than the heading alone:
                // the icon marks the whole warning, and a body that started
                // back at the card's edge put the two halves of one paragraph
                // on two different margins.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.plainHttpTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        l10n.plainHttpEditTip,
                        style: UIs.text12Grey.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            // Inside the warning, not the next row of the form. Allowing
            // plain http *is* what the warning is about, and a switch below
            // the card would read as one more setting that happened to follow
            // it.
            Material(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.monitorAllowInsecureHttp,
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            l10n.monitorAllowInsecureHttpTip,
                            style: UIs.text12Grey,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    _monitorAllowInsecure.listenVal(
                      (v) => SwitchX(
                        value: v,
                        onChanged: (val) {
                          _monitorAllowInsecure.value = val;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                trailing: SwitchX(
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
                trailing: SwitchX(
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
    return _disabledCmdTypes.listenVal((disabled) {
      return ListTile(
        leading: const Icon(Icons.disabled_by_default),
        title: Text('${libL10n.disabled} ${libL10n.cmd}'),
        subtitle: disabled.isEmpty
            ? null
            : Text(disabled.join(', '), style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _onTapDisabledCmdTypes,
      );
    }).cardx;
  }

  Widget _buildBmc() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        subtitle: Text(switch (cred) {
          null => l10n.bmcAccountUnset,
          final c when shared > 1 =>
            '${c.name} (${c.user}) - ${l10n.bmcAccountShared(shared)}',
          final c => '${c.name} (${c.user})',
        }, style: UIs.textGrey),
        trailing: cred == null
            ? const Icon(Icons.keyboard_arrow_right)
            : IconButton(
                tooltip: libL10n.edit,
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

  /// The one button that writes anything.
  ///
  /// A filled button rather than an icon, because it is the page's only
  /// outcome and the two icons beside it are not: `Delete` and the script tip
  /// are recognised by their glyphs, and a third glyph among them would be a
  /// save that looks like a third utility.
  Widget _buildSaveBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: FilledButton(
        onPressed: _onSave,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 17),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(libL10n.save),
      ),
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
    return IconButton(
      tooltip: libL10n.delete,
      onPressed: () async {
        final cur = spi;
        if (cur == null) return;
        // The dialog answers; this — which is on the page — acts on the answer
        // and then closes the page. Doing both from inside the button meant
        // two pops in a row from a callback that can see two navigators: the
        // dialog is on the root one, and this page may be inside a pane, so
        // whichever `pop` was written first decided which of the two closed.
        final confirmed = await context.showRoundDialog<bool>(
          title: libL10n.attention,
          child: Text(
            libL10n.askContinue(
              '${libL10n.delete} ${libL10n.server}(${cur.name})',
            ),
          ),
          actions: Btn.ok(red: true).toList,
        );
        if (confirmed != true || !mounted) return;
        try {
          await ref.read(serversProvider.notifier).delServer(cur.id);
        } catch (e, s) {
          if (mounted) context.showErrDialog(e, s);
          return;
        }
        if (!mounted) return;
        context.pop(true);
      },
      icon: const Icon(Icons.delete),
    );
  }
}

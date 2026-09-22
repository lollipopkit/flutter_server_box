part of '../entry.dart';

extension _Server on _AppSettingsPageState {
  void _showInvalidUrlDialog() {
    context.showRoundDialog(
      title: libL10n.fail,
      child: Text(libL10n.invalidUrl),
      actions: Btnx.oks,
    );
  }

  List<SettingsGroup> _buildServer() {
    return [
      SettingsGroup(libL10n.view, [
        _buildNetViewType(),
        _buildCpuNoLineChart(),
        _buildDisplayCpuIndex(),
        _buildServerTabPreferDiskAmount(),
        _buildDoubleColumnServersPage(),
        _buildTextScaler(),
      ]),
      // Four rows about one feature, which is what the tile they were folded
      // into was for. A name over them says the same thing and does not have
      // to be opened.
      SettingsGroup(l10n.distIcon, [
        _buildShowDistMark(),
        _buildServerMarkUrl(),
        _buildServerLogoUrl(),
        _buildDistNameMap(),
      ]),
      SettingsGroup(l10n.behaviour, [
        _buildKeepStatusWhenErr(),
        _buildRememberPwdInMem(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        if (isDesktop) _buildSSHConfigAutoImportToggle(),
      ]),
      _buildGlobe(),
      SettingsGroup(libL10n.servers, [
        _buildConnectionStats(),
        _buildDeleteServers(),
      ]),
    ];
  }

  SettingsRow _buildNetViewType() {
    final label = l10n.netViewType;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(ZondIcons.network),
        title: Text(label),
        trailing: ValBuilder(
          listenable: _setting.netViewType.listenable(),
          builder: (val) => Text(val.toStr, style: UIs.text15),
        ),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: label,
            items: NetViewType.values,
            display: (p0) => p0.toStr,
            initial: _setting.netViewType.fetch(),
          );
          if (selected != null) {
            _setting.netViewType.put(selected);
          }
        },
      ),
    );
  }

  SettingsRow _buildConnectionStats() {
    final label = l10n.connectionStats;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.analytics),
        title: Text(label),
        subtitle: Text(l10n.connectionStatsDesc, style: UIs.textGrey),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => ConnectionStatsPage.route.go(context),
      ),
      keywords: l10n.connectionStatsDesc,
    );
  }

  SettingsRow _buildDeleteServers() {
    final label = l10n.deleteServers;
    return SettingsRow(
      label,
      () => ListTile(
        title: Text(label),
        leading: const Icon(Icons.delete_forever),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _onTapDeleteServers,
      ),
    );
  }

  Future<void> _onTapDeleteServers() async {
    final keys = Stores.server.keys();
    final names = Map.fromEntries(
      keys.map((e) => MapEntry(e, ref.read(serversProvider).servers[e]?.name ?? e)),
    );
    final deleteKeys = await context.showPickDialog<String>(
      clearable: true,
      items: keys.toList(),
      display: (p0) => names[p0] ?? p0,
    );
    if (deleteKeys == null || deleteKeys.isEmpty) return;

    final md = deleteKeys.map((e) => '- ${names[e] ?? e}').join('\n');
    final sure = await context.showRoundDialog(
      title: libL10n.attention,
      child: SimpleMarkdown(data: md),
      actions: Btnx.cancelRedOk,
    );

    if (sure != true) return;
    final notifier = ref.read(serversProvider.notifier);
    for (final key in deleteKeys) {
      await notifier.delServer(key);
    }
    Toast.success(libL10n.success);
  }

  SettingsRow _buildTextScaler() {
    final label = libL10n.textScaler;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.format_size),
        title: TipText(label, l10n.textScalerTip),
        trailing: ValBuilder(
          listenable: _setting.textFactor.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () => context.showRoundDialog(
          title: label,
          child: Input(
            autoFocus: true,
            type: TextInputType.number,
            hint: '1.0',
            icon: Icons.format_size,
            controller: _textScalerCtrl,
            onSubmitted: _onSaveTextScaler,
            suggestion: false,
          ),
          actions: Btn.ok(onTap: () => _onSaveTextScaler(_textScalerCtrl.text)).toList,
        ),
      ),
      keywords: l10n.textScalerTip,
    );
  }

  void _onSaveTextScaler(String s) {
    final val = double.tryParse(s);
    if (val == null) {
      Toast.error(libL10n.fail);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.notify();
    context.popDialog();
  }

  SettingsRow _buildDoubleColumnServersPage() {
    final label = l10n.doubleColumnMode;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.view_column_outlined),
        title: TipText(label, l10n.doubleColumnTip),
        trailing: StoreSwitch(prop: _setting.doubleColumnServersPage),
      ),
      keywords: l10n.doubleColumnTip,
    );
  }

  SettingsRow _buildKeepStatusWhenErr() {
    final label = l10n.keepStatusWhenErr;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.history_toggle_off),
        title: Text(label),
        subtitle: Text(l10n.keepStatusWhenErrTip, style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.keepStatusWhenErr),
      ),
      keywords: l10n.keepStatusWhenErrTip,
    );
  }

  SettingsRow _buildRememberPwdInMem() {
    final label = l10n.rememberPwdInMem;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.password),
        title: TipText(label, l10n.rememberPwdInMemTip),
        trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
      ),
      keywords: l10n.rememberPwdInMemTip,
    );
  }

  SettingsRow _buildCpuNoLineChart() {
    final label = l10n.noLineChart;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(OctIcons.cpu),
        title: Text(label),
        subtitle: Text(l10n.cpuViewAsProgressTip, style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.cpuViewAsProgress),
      ),
      keywords: 'CPU ${l10n.cpuViewAsProgressTip}',
    );
  }

  SettingsRow _buildDisplayCpuIndex() {
    final label = l10n.displayCpuIndex;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.format_list_numbered),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.displayCpuIndex),
      ),
      keywords: 'CPU',
    );
  }

  /// Whether to draw the mark beside each server at all.
  ///
  /// Putting marks on the rows is a decision, so it is made once with the
  /// terms on screen rather than silently — see [_confirmDistIcon]. The tip on
  /// the title is the whole of the terms, plain rather than markdown, because
  /// a tip is a text bubble and a link in one shows as its own syntax with
  /// nothing to tap.
  SettingsRow _buildShowDistMark() {
    // The tip doubles as this row's title: inside a group already called
    // "Distribution marks", repeating the name says nothing, while what the
    // switch does is the thing worth reading.
    final label = l10n.distIconTip;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.dns_outlined),
        title: TipText(label, distLegalPlain(l10n)),
        trailing: StoreSwitch(
          prop: _setting.showDistMark,
          validator: _confirmDistIcon,
        ),
      ),
      keywords: l10n.distIcon,
    );
  }

  /// Where the small mark in a list comes from.
  ///
  /// There is no on/off beside it: an empty address is the off position, and
  /// the switch that used to sit here governed nothing once the app stopped
  /// shipping pictures — it was a second gate over an address that was already
  /// blank by default.
  SettingsRow _buildServerMarkUrl() {
    final label = l10n.markUrl;

    void onSave(String raw) {
      final url = resolveLogoUrl(raw);
      // Emptying it is how marks are turned off, so it is the one value that
      // skips both the validation and the terms.
      if (url.isEmpty) {
        _setting.serverMarkUrl.put('');
        context.popDialog();
        return;
      }
      if (!isFetchableLogoUrl(url)) {
        _showInvalidUrlDialog();
        return;
      }
      _setting.serverMarkUrl.put(url);
      context.popDialog();
    }

    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.label_outline),
        title: TipText(label, l10n.markUrlTip),
        subtitle: ValBuilder(
          listenable: _setting.serverMarkUrl.listenable(),
          builder: (url) => Text(
            url.isEmpty ? libL10n.empty : url,
            style: UIs.textGrey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () {
          _serverMarkCtrl.text = _setting.serverMarkUrl.fetch();
          context.showRoundDialog(
            title: label,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Input(
                  controller: _serverMarkCtrl,
                  autoFocus: true,
                  hint: 'https://example.com/{DIST}.svg',
                  icon: Icons.link,
                  maxLines: 1,
                  suggestion: false,
                  onSubmitted: onSave,
                ),
                ListTile(
                  title: Text(libL10n.doc),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: Urls.customLogoDoc.launchUrl,
                ),
              ],
            ),
            actions: Btn.ok(onTap: () => onSave(_serverMarkCtrl.text)).toList,
          );
        },
      ),
      keywords: l10n.markUrlTip,
    );
  }

  /// The exceptions to `{DIST}` — see [distFileName].
  ///
  /// A key-value editor rather than a picker over `Dist.values`: the keys are
  /// the app's own case names and the values are whatever the collection the
  /// user chose happens to call those files. Only the disagreements are
  /// written down, so the list is normally empty and is a handful at most.
  SettingsRow _buildDistNameMap() {
    final label = l10n.distNameMap;
    return SettingsRow(
      label,
      () => ValBuilder(
        listenable: _setting.distNameMap.listenable(),
        builder: (map) => ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: TipText(label, l10n.distNameMapTip),
          subtitle: Text(
            // The count, not the pairs: a subtitle listing them would be a
            // line of `arch=archlinux, rhel=redhat, …` that elides after two.
            map.isEmpty ? libL10n.empty : '${map.length}',
            style: UIs.textGrey,
          ),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final result = await KvEditor.route.go(
              context,
              KvEditorArgs(data: Map.of(map)),
            );
            // Null is a back-button, which is not the same as saving an empty
            // map — that is how every override is cleared.
            if (result == null) return;
            _setting.distNameMap.put(result);
          },
        ),
      ),
      keywords: l10n.distNameMapTip,
    );
  }

  /// Only on the way on. Turning them off is agreement to nothing, and asking
  /// there would turn "stop showing these" into a second decision to get past.
  ///
  /// Returning false leaves the switch where it was — `StoreSwitch` treats the
  /// validator as the gate and writes nothing when it declines.
  Future<bool> _confirmDistIcon(bool enabling) async {
    if (!enabling) return true;
    return confirmDistIconTerms(context);
  }

  SettingsRow _buildServerLogoUrl() {
    final label = l10n.logoUrl;

    void onSave(String raw) {
      // Emptying the field clears it. An empty string is not a fetchable URL,
      // so it was refused as invalid — and unset is the state this starts in
      // and shows as [libL10n.empty], which left no way back to it.
      if (raw.trim().isEmpty) {
        _setting.serverLogoUrl.put('');
        context.popDialog();
        return;
      }
      // A GitHub page URL is rewritten to the one that serves the file. It is
      // what the address bar gives you, and left alone it fetches HTML that
      // reaches the decoder as `Invalid image data`.
      final url = resolveLogoUrl(raw);
      if (!isFetchableLogoUrl(url)) {
        _showInvalidUrlDialog();
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.popDialog();
    }

    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.image),
        title: TipText(label, l10n.logoUrlTip),
        subtitle: ValBuilder(
          listenable: _setting.serverLogoUrl.listenable(),
          builder: (url) => Text(
            url.isEmpty ? libL10n.empty : url,
            style: UIs.textGrey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () {
          _serverLogoCtrl.text = _setting.serverLogoUrl.fetch();
          context.showRoundDialog(
            title: label,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Input(
                  controller: _serverLogoCtrl,
                  autoFocus: true,
                  hint: 'https://example.com/logo.png',
                  icon: Icons.link,
                  // One line, so the text sits in the middle of the field. A
                  // URL has nowhere to wrap anyway, and with room for two the
                  // single line it holds was drawn against the top with a
                  // blank line under it.
                  maxLines: 1,
                  suggestion: false,
                  onSubmitted: onSave,
                ),
                ListTile(
                  title: Text(libL10n.doc),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: Urls.customLogoDoc.launchUrl,
                ),
              ],
            ),
            actions: Btn.ok(onTap: () => onSave(_serverLogoCtrl.text)).toList,
          );
        },
      ),
      keywords: l10n.logoUrlTip,
    );
  }

  SettingsRow _buildServerTabPreferDiskAmount() {
    final label = l10n.preferDiskAmount;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.storage),
        title: Text(label),
        trailing: StoreSwitch(prop: Stores.setting.serverTabPreferDiskAmount),
      ),
    );
  }

  SettingsRow _buildSSHConfigAutoImportToggle() {
    final label = l10n.sshConfigImport;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.file_import_line),
        title: Text(label),
        subtitle: Text(l10n.sshConfigImportTip, style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.firstTimeReadSSHCfg),
      ),
      keywords: l10n.sshConfigImportTip,
    );
  }
}

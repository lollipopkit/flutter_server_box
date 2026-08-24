part of '../entry.dart';

extension _Server on _AppSettingsPageState {
  void _showInvalidUrlDialog() {
    context.showRoundDialog(
      title: libL10n.fail,
      child: Text(libL10n.invalidUrl),
      actions: Btnx.oks,
    );
  }

  Widget _buildServer() {
    return Column(
      children: [
        _buildDistIcon(),
        _buildServerLogoUrl(),
        _buildNetViewType(),
        _buildConnectionStats(),
        _buildDeleteServers(),
        _buildCpuView(),
        _buildServerMore(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildNetViewType() {
    return ListTile(
      leading: const Icon(ZondIcons.network, size: _kIconSize),
      title: Text(l10n.netViewType),
      trailing: ValBuilder(
        listenable: _setting.netViewType.listenable(),
        builder: (val) => Text(val.toStr, style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.netViewType,
          items: NetViewType.values,
          display: (p0) => p0.toStr,
          initial: _setting.netViewType.fetch(),
        );
        if (selected != null) {
          _setting.netViewType.put(selected);
        }
      },
    );
  }

  Widget _buildConnectionStats() {
    return ListTile(
      leading: const Icon(Icons.analytics, size: _kIconSize),
      title: Text(l10n.connectionStats),
      subtitle: Text(l10n.connectionStatsDesc, style: UIs.textGrey),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        ConnectionStatsPage.route.go(context);
      },
    );
  }

  Widget _buildDeleteServers() {
    return ListTile(
      title: Text(l10n.deleteServers),
      leading: const Icon(Icons.delete_forever),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () async {
        final keys = Stores.server.keys();
        final names = Map.fromEntries(
          keys.map(
            (e) => MapEntry(e, ref.read(serversProvider).servers[e]?.name ?? e),
          ),
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
      },
    );
  }

  Widget _buildTextScaler() {
    return ListTile(
      title: TipText(libL10n.textScaler, l10n.textScalerTip),
      trailing: ValBuilder(
        listenable: _setting.textFactor.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => context.showRoundDialog(
        title: libL10n.textScaler,
        child: Input(
          autoFocus: true,
          type: TextInputType.number,
          hint: '1.0',
          icon: Icons.format_size,
          controller: _textScalerCtrl,
          onSubmitted: _onSaveTextScaler,
          suggestion: false,
        ),
        actions: Btn.ok(
          onTap: () => _onSaveTextScaler(_textScalerCtrl.text),
        ).toList,
      ),
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

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
      title: TipText(l10n.doubleColumnMode, l10n.doubleColumnTip),
      trailing: StoreSwitch(prop: _setting.doubleColumnServersPage),
    );
  }

  Widget _buildKeepStatusWhenErr() {
    return ListTile(
      title: Text(l10n.keepStatusWhenErr),
      subtitle: Text(l10n.keepStatusWhenErrTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.keepStatusWhenErr),
    );
  }

  Widget _buildServerMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(libL10n.more),
      initiallyExpanded: false,
      children: [
        _buildServerTabPreferDiskAmount(),
        _buildRememberPwdInMem(),
        _buildTextScaler(),
        _buildKeepStatusWhenErr(),
        _buildDoubleColumnServersPage(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        if (isDesktop) _buildSSHConfigAutoImportToggle(),
      ],
    );
  }

  Widget _buildRememberPwdInMem() {
    return ListTile(
      title: TipText(l10n.rememberPwdInMem, l10n.rememberPwdInMemTip),
      trailing: StoreSwitch(prop: _setting.rememberPwdInMem),
    );
  }

  Widget _buildCpuView() {
    return ExpandTile(
      leading: const Icon(OctIcons.cpu, size: _kIconSize),
      title: Text('CPU ${l10n.view}'),
      children: [
        ListTile(
          title: Text(l10n.noLineChart),
          subtitle: Text(l10n.cpuViewAsProgressTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.cpuViewAsProgress),
        ),
        ListTile(
          title: Text(l10n.displayCpuIndex),
          trailing: StoreSwitch(prop: _setting.displayCpuIndex),
        ),
      ],
    );
  }

  /// The mark beside each server, and where it comes from.
  ///
  /// The tip is the short form; the intro page carries the whole of it, which
  /// is why this leads there rather than repeating it in a subtitle.
  Widget _buildDistIcon() {
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      // Plain, not markdown: a tip is a text bubble, and a link in it would
      // show as its own syntax with nothing to tap. The intro page is where
      // the followable version lives.
      title: TipText(l10n.distIcon, distLegalPlain(l10n)),
      subtitle: Text(l10n.distIconTip, style: UIs.textGrey),
      trailing: StoreSwitch(
        prop: _setting.showDistIcon,
        validator: _confirmDistIcon,
      ),
    );
  }

  /// Turning the marks on is a decision, so it is made once with the terms on
  /// screen rather than silently.
  ///
  /// Only on the way on. Switching them off needs no agreement to anything,
  /// and asking would turn "stop showing these" into a second decision.
  ///
  /// Returning false leaves the switch where it was — `StoreSwitch` treats the
  /// validator as the gate and writes nothing when it declines.
  ///
  /// The intro page has the same switch and does not do this: the whole text
  /// is already on that page beside it, and a dialog repeating what is visible
  /// is one people learn to dismiss without reading.
  Future<bool> _confirmDistIcon(bool enabling) async {
    if (!enabling) return true;
    return confirmDistIconTerms(context);
  }

  Widget _buildServerLogoUrl() {
    void onSave(String raw) {
      // A GitHub page URL is rewritten to the one that serves the file. It is
      // what the address bar gives you, and left alone it fetches HTML that
      // reaches the decoder as `Invalid image data`.
      final url = resolveLogoUrl(raw);
      if (url.isEmpty || !url.startsWith('http')) {
        _showInvalidUrlDialog();
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.popDialog();
    }

    return ListTile(
      leading: const Icon(Icons.image),
      title: const Text('Logo URL'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        context.showRoundDialog(
          title: 'Logo URL',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                controller: _serverLogoCtrl,
                autoFocus: true,
                hint: 'https://example.com/logo.png',
                icon: Icons.link,
                // One line, so the text sits in the middle of the field. A URL
                // has nowhere to wrap anyway, and with room for two the single
                // line it holds was drawn against the top with a blank line
                // under it.
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
    );
  }

  Widget _buildServerTabPreferDiskAmount() {
    return ListTile(
      title: Text(l10n.preferDiskAmount),
      trailing: StoreSwitch(prop: Stores.setting.serverTabPreferDiskAmount),
    );
  }

  Widget _buildSSHConfigAutoImportToggle() {
    return ListTile(
      title: Text(l10n.sshConfigImport),
      subtitle: Text(l10n.sshConfigImportTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.firstTimeReadSSHCfg),
    );
  }
}

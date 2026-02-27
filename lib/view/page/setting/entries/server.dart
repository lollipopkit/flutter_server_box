part of '../entry.dart';

extension _Server on _AppSettingsPageState {
  Widget _buildServer() {
    return Column(
      children: [
        _buildServerLogoUrl(),
        _buildServerFuncBtns(),
        _buildNetViewType(),
        _buildServerSeq(),
        _buildServerDetailCardSeq(),
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
      subtitle: Text(l10n.connectionStatsDesc),
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
        for (final key in deleteKeys) {
          Stores.server.remove(key);
        }
        context.showSnackBar(libL10n.success);
      },
    );
  }

  Widget _buildTextScaler() {
    return ListTile(
      // title: Text(l10n.textScaler),
      // subtitle: Text(l10n.textScalerTip, style: UIs.textGrey),
      title: TipText(l10n.textScaler, l10n.textScalerTip),
      trailing: ValBuilder(
        listenable: _setting.textFactor.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => context.showRoundDialog(
        title: l10n.textScaler,
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
    );
  }

  void _onSaveTextScaler(String s) {
    final val = double.tryParse(s);
    if (val == null) {
      context.showSnackBar(libL10n.fail);
      return;
    }
    _setting.textFactor.put(val);
    RNodes.app.notify();
    context.pop();
  }

  Widget _buildServerFuncBtns() {
    return ExpandTile(
      leading: const Icon(BoxIcons.bxs_joystick_button, size: _kIconSize),
      title: Text(l10n.serverFuncBtns),
      children: [_buildServerFuncBtnsSwitch(), _buildServerFuncBtnsOrder()],
    );
  }

  Widget _buildServerFuncBtnsSwitch() {
    return ListTile(
      // title: Text(libL10n.location),
      // subtitle: Text(l10n.moveOutServerFuncBtnsHelp, style: UIs.text13Grey),
      title: TipText(libL10n.location, l10n.moveOutServerFuncBtnsHelp),
      trailing: StoreSwitch(prop: _setting.moveServerFuncs),
    );
  }

  Widget _buildServerFuncBtnsOrder() {
    return ListTile(
      title: Text(libL10n.sequence),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => ServerFuncBtnsOrderPage.route.go(context),
    );
  }

  Widget _buildServerSeq() {
    return ListTile(
      leading: const Icon(OctIcons.sort_desc, size: _kIconSize),
      title: Text(l10n.serverOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => ServerOrderPage.route.go(context),
    );
  }

  Widget _buildServerDetailCardSeq() {
    return ListTile(
      leading: const Icon(OctIcons.sort_desc, size: _kIconSize),
      title: Text(l10n.serverDetailOrder),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => ServerDetailOrderPage.route.go(context),
    );
  }

  Widget _buildDoubleColumnServersPage() {
    return ListTile(
      // title: Text(l10n.doubleColumnMode),
      // subtitle: Text(l10n.doubleColumnTip, style: UIs.textGrey),
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
      title: Text(l10n.more),
      initiallyExpanded: false,
      children: [
        _buildServerTabPreferDiskAmount(),
        _buildRememberPwdInMem(),
        _buildTextScaler(),
        _buildKeepStatusWhenErr(),
        _buildDoubleColumnServersPage(),
        _buildUpdateInterval(),
        _buildMaxRetry(),
        _buildSSHConfigImport(),
      ],
    );
  }

  Widget _buildRememberPwdInMem() {
    return ListTile(
      // title: Text(l10n.rememberPwdInMem),
      // subtitle: Text(l10n.rememberPwdInMemTip, style: UIs.textGrey),
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

  Widget _buildServerLogoUrl() {
    void onSave(String url) {
      if (url.isEmpty || !url.startsWith('http')) {
        context.showRoundDialog(title: libL10n.fail, child: Text('${l10n.invalid} URL'), actions: Btnx.oks);
        return;
      }
      _setting.serverLogoUrl.put(url);
      context.pop();
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
                maxLines: 2,
                suggestion: false,
                onSubmitted: onSave,
              ),
              ListTile(
                title: Text(libL10n.doc),
                trailing: const Icon(Icons.open_in_new),
                onTap: Urls.appWiki.launchUrl,
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

  Widget _buildSSHConfigImport() {
    return ListTile(
      title: Text(l10n.sshConfigImport),
      subtitle: Text(l10n.sshConfigImportTip, style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.firstTimeReadSSHCfg),
    );
  }
}

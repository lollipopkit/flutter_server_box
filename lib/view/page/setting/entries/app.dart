part of '../entry.dart';

extension _App on _AppSettingsPageState {
  Widget _buildApp() {
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      _buildCheckUpdate(),
      PlatformPublicSettings.buildBioAuth(),
      if (specific != null) specific,
      _buildAppMore(),
    ];

    return Column(children: children.map((e) => e.cardx).toList());
  }

  Widget? _buildPlatformSetting() {
    final func = switch (Pfs.type) {
      Pfs.android => AndroidSettingsPage.route.go,
      Pfs.ios => IosSettingsPage.route.go,
      _ => null,
    };
    if (func == null) return null;
    return ListTile(
      leading: const Icon(Icons.phone_android),
      title: Text('${Pfs.type} ${libL10n.setting}'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => func(context),
    );
  }

  Widget _buildCheckUpdate() {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(libL10n.checkUpdate),
      subtitle: ValBuilder(
        listenable: AppUpdateIface.newestBuild,
        builder: (val) {
          String display;
          if (val != null) {
            if (val > BuildData.build) {
              display = libL10n.versionHasUpdate(val);
            } else {
              display = libL10n.versionUpdated(BuildData.build);
            }
          } else {
            display = libL10n.versionUnknownUpdate(BuildData.build);
          }
          return Text(display, style: UIs.textGrey);
        },
      ),
      onTap: () => Fns.throttle(
        () => AppUpdateIface.doUpdate(
          context: context,
          build: BuildData.build,
          url: Urls.updateCfg,
          force: BuildMode.isDebug,
        ),
      ),
      trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
    );
  }

  Widget _buildUpdateInterval() {
    return ListTile(
      title: Text(l10n.updateServerStatusInterval),
      onTap: () async {
        final val = await context.showPickSingleDialog(
          title: libL10n.setting,
          items: List.generate(10, (idx) => idx == 1 ? null : idx),
          initial: _setting.serverStatusUpdateInterval.fetch(),
          display: (p0) => p0 == 0 ? l10n.manual : '$p0 ${l10n.second}',
        );
        if (val != null) {
          _setting.serverStatusUpdateInterval.put(val);
        }
      },
      trailing: ValBuilder(
        listenable: _setting.serverStatusUpdateInterval.listenable(),
        builder: (val) => Text('$val ${l10n.second}', style: UIs.text15),
      ),
    );
  }

  Widget _buildAppColor() {
    return ListTile(
      leading: const Icon(Icons.colorize),
      title: Text(libL10n.primaryColorSeed),
      trailing: _setting.colorSeed.listenable().listenVal((val) {
        final c = Color(val);
        return ClipOval(child: Container(color: c, height: 27, width: 27));
      }),
      onTap: () async {
        final ctrl = TextEditingController(text: UIs.primaryColor.toHex);
        await context.showRoundDialog(
          title: libL10n.primaryColorSeed,
          child: StatefulBuilder(
            builder: (context, setState) {
              final children = <Widget>[
                /// Plugin [dynamic_color] is not supported on iOS
                if (!isIOS)
                  ListTile(
                    title: Text(l10n.followSystem),
                    trailing: StoreSwitch(
                      prop: _setting.useSystemPrimaryColor,
                      callback: (_) => setState(() {}),
                    ),
                  ),
              ];
              if (!_setting.useSystemPrimaryColor.fetch()) {
                children.add(
                  ColorPicker(
                    color: Color(_setting.colorSeed.fetch()),
                    onColorChanged: (c) => ctrl.text = c.toHex,
                  ),
                );
              }
              return Column(mainAxisSize: MainAxisSize.min, children: children);
            },
          ),
          actions: Btn.ok(onTap: () => _onSaveColor(ctrl.text)).toList,
        );
        ctrl.dispose();
      },
    );
  }

  void _onSaveColor(String s) {
    final color = s.fromColorHex;
    if (color == null) {
      context.showSnackBar(libL10n.fail);
      return;
    }
    UIs.colorSeed = color;
    _setting.colorSeed.put(color.value255);
    context.pop();
    Future.delayed(Durations.medium1, RNodes.app.notify);
  }

  Widget _buildMaxRetry() {
    return ValBuilder(
      listenable: _setting.maxRetryCount.listenable(),
      builder: (val) => ListTile(
        title: Text(l10n.maxRetryCount),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: l10n.maxRetryCount,
            items: List.generate(10, (index) => index),
            display: (p0) => '$p0 ${l10n.times}',
            initial: val,
          );
          if (selected != null) {
            _setting.maxRetryCount.put(selected);
          }
        },
        trailing: Text('$val ${l10n.times}', style: UIs.text15),
      ),
    );
  }

  Widget _buildThemeMode() {
    // Issue #57
    final len = ThemeMode.values.length;
    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill),
      title: Text(libL10n.themeMode),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.themeMode,
          items: List.generate(len + 2, (index) => index),
          display: (p0) => _buildThemeModeStr(p0),
          initial: _setting.themeMode.fetch(),
        );
        if (selected != null) {
          _setting.themeMode.put(selected);
          RNodes.app.notify();
        }
      },
      trailing: ValBuilder(
        listenable: _setting.themeMode.listenable(),
        builder: (val) => Text(_buildThemeModeStr(val), style: UIs.text15),
      ),
    );
  }

  String _buildThemeModeStr(int n) {
    switch (n) {
      case 1:
        return libL10n.bright;
      case 2:
        return libL10n.dark;
      case 3:
        return 'AMOLED';
      case 4:
        return '${libL10n.auto} AMOLED';
      default:
        return libL10n.auto;
    }
  }

  Widget _buildLocale() {
    return ListTile(
      leading: const Icon(IonIcons.language),
      title: Text(libL10n.language),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: libL10n.language,
          items: AppLocalizations.supportedLocales,
          display: (p0) => p0.nativeName,
          initial: _setting.locale.fetch().toLocale,
        );
        if (selected != null) {
          _setting.locale.put(selected.code);
          context.pop();
          RNodes.app.notify();
        }
      },
      trailing: ListenBuilder(
        listenable: _setting.locale.listenable(),
        builder: () => Text(context.localeNativeName, style: UIs.text15),
      ),
    );
  }

  Widget _buildAppMore() {
    return ExpandTile(
      leading: const Icon(MingCute.more_3_fill),
      title: Text(l10n.more),
      initiallyExpanded: false,
      children: [
        _buildBeta(),
        if (isMobile) _buildWakeLock(),
        _buildCollapseUI(),
        _buildCupertinoRoute(),
        if (isDesktop) _buildHideTitleBar(),
        _buildEditRawSettings(),
      ],
    );
  }

  Widget _buildBeta() {
    return ListTile(
      title: TipText('Beta Program', l10n.acceptBeta),
      trailing: StoreSwitch(prop: _setting.betaTest),
    );
  }

  Widget _buildWakeLock() {
    return ListTile(
      title: Text(l10n.wakeLock),
      trailing: StoreSwitch(prop: _setting.generalWakeLock),
    );
  }

  Widget _buildCollapseUI() {
    return ListTile(
      title: TipText('UI ${libL10n.fold}', l10n.collapseUITip),
      trailing: StoreSwitch(prop: _setting.collapseUIDefault),
    );
  }

  Widget _buildCupertinoRoute() {
    return ListTile(
      title: Text('Cupertino ${l10n.route}'),
      trailing: StoreSwitch(prop: _setting.cupertinoRoute),
    );
  }

  Widget _buildHideTitleBar() {
    return ListTile(
      title: Text(l10n.hideTitleBar),
      trailing: StoreSwitch(prop: _setting.hideTitleBar),
    );
  }
}

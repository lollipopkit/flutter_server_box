part of '../entry.dart';

extension _App on _AppSettingsPageState {
  Widget _buildApp() {
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      _buildCheckUpdate(),
      _buildHomeTabs(),
      PlatformPublicSettings.buildBioAuth,
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
          display: (p0) => p0 == 0 ? libL10n.manual : '$p0 ${l10n.second}',
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
      trailing: _setting.colorSeed.listenable().listenVal((_) {
        return ClipOval(child: Container(color: UIs.primaryColor, height: 27, width: 27));
      }),
      onTap: () {
        withTextFieldController((ctrl) async {
          ctrl.text = Color(_setting.colorSeed.fetch()).toHex;
          await context.showRoundDialog(
            title: libL10n.primaryColorSeed,
            child: StatefulBuilder(
              builder: (context, setState) {
                final children = <Widget>[
                  if (!isIOS)
                    DynamicColorBuilder(
                      builder: (light, dark) {
                        final supported = light != null || dark != null;
                        if (!supported) return const SizedBox.shrink();
                        return ListTile(
                          title: Text(l10n.followSystem),
                          trailing: StoreSwitch(
                            prop: _setting.useSystemPrimaryColor,
                            callback: (_) => setState(() {}),
                          ),
                        );
                      },
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
        });
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

    RNodes.app.notify();
    context.pop();
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

  Widget _buildHomeTabs() {
    return ListTile(
      leading: const Icon(Icons.tab),
      title: Text(l10n.homeTabs),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        HomeTabsConfigPage.route.go(context);
      },
    );
  }

  Widget _buildEditRawSettings() {
    return ListTile(
      title: const Text('(Dev) Edit raw json'),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _editRawSettings,
    );
  }

  Future<void> _editRawSettings() async {
    final rawMap = Stores.setting.getAllMap(includeInternalKeys: true);
    final map = Map<String, Object?>.from(rawMap);
    final initialKeys = Set<String>.from(map.keys);
    Map<String, Object?> mapForEditor = map;
    String? encryptedKey;
    String? passwordUsed;

    Future<String?> resolvePassword() async {
      final saved = await _setting.backupasswd.read();
      if (saved?.isNotEmpty == true) return saved;
      final backupPwd = await SecureStoreProps.bakPwd.read();
      if (backupPwd?.isNotEmpty == true) return backupPwd;
      final controller = TextEditingController();
      try {
        final result = await context.showRoundDialog<String>(
          title: libL10n.pwd,
          child: Input(
            controller: controller,
            label: libL10n.pwd,
            obscureText: true,
            onSubmitted: (_) => context.pop(controller.text.trim()),
          ),
          actions: [
            TextButton(onPressed: () => context.pop(null), child: Text(libL10n.cancel)),
            TextButton(onPressed: () => context.pop(controller.text.trim()), child: Text(libL10n.ok)),
          ],
        );
        return result?.trim();
      } finally {
        controller.dispose();
      }
    }

    for (final entry in map.entries) {
      final value = entry.value;
      if (value is String && Cryptor.isEncrypted(value)) {
        final password = await resolvePassword();
        if (password == null || password.isEmpty) {
          context.showSnackBar(libL10n.cancel);
          return;
        }
        try {
          final decrypted = Cryptor.decrypt(value, password);
          final decoded = json.decode(decrypted);
          if (decoded is Map<String, dynamic>) {
            mapForEditor = Map<String, Object?>.from(decoded);
            encryptedKey = entry.key;
            passwordUsed = password;
            break;
          } else {
            context.showRoundDialog(title: libL10n.fail, child: Text(l10n.invalid));
            return;
          }
        } catch (e, stack) {
          final msg = e.toString().contains('Failed to decrypt') || e.toString().contains('incorrect password')
              ? l10n.backupPasswordWrong
              : '${libL10n.error}:\n$e';
          context.showRoundDialog(title: libL10n.fail, child: Text(msg));
          Loggers.app.warning('Decrypt raw settings failed', e, stack);
          return;
        }
      }
    }

    void onSave(EditorPageRet ret) {
      if (ret.typ != EditorPageRetType.text) {
        context.showRoundDialog(title: libL10n.fail, child: Text(l10n.invalid));
        return;
      }
      try {
        final newSettings = json.decode(ret.val) as Map<String, dynamic>;
        if (encryptedKey != null) {
          final pwd = passwordUsed;
          if (pwd == null || pwd.isEmpty) {
            context.showRoundDialog(title: libL10n.fail, child: Text(l10n.invalid));
            return;
          }
          final encrypted = Cryptor.encrypt(json.encode(newSettings), pwd);
          Stores.setting.box.put(encryptedKey, encrypted);
        } else {
          Stores.setting.box.putAll(newSettings);
          final newKeys = newSettings.keys.toSet();
          final removedKeys = initialKeys.where((e) => !newKeys.contains(e));
          for (final key in removedKeys) {
            Stores.setting.box.delete(key);
          }
        }
      } catch (e, trace) {
        context.showRoundDialog(title: libL10n.error, child: Text('${l10n.save}:\n$e'));
        Loggers.app.warning('Update json settings failed', e, trace);
      }
    }

    /// Encode [map] to String with indent `\t`
    final text = jsonIndentEncoder.convert(mapForEditor);
    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        text: text,
        lang: ProgLang.json,
        title: libL10n.setting,
        onSave: onSave,
        closeAfterSave: SettingStore.instance.closeAfterSave.fetch(),
        softWrap: SettingStore.instance.editorSoftWrap.fetch(),
        enableHighlight: SettingStore.instance.editorHighlight.fetch(),
      ),
    );
  }
}

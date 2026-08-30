part of '../entry.dart';

extension _App on _AppSettingsPageState {
  void _showInvalidDialog() {
    context.showRoundDialog(title: libL10n.fail, child: Text(libL10n.invalid));
  }

  Widget _buildApp() {
    final androidSettings = isAndroid ? _buildAndroidSettings() : null;
    final specific = _buildPlatformSetting();
    final children = [
      _buildLocale(),
      _buildThemeMode(),
      _buildAppColor(),
      _buildCheckUpdate(),
      PlatformPublicSettings.buildBioAuth,
      ?PlatformPublicSettings.buildPrivacyBlur,
      ?androidSettings,
      ?specific,
      _buildAppMore(),
    ];

    return Column(children: children.map((e) => e.cardx).toList());
  }

  Widget _buildAndroidSettings() {
    return ExpandTile(
      leading: const Icon(Icons.phone_android),
      title: Text('Android ${libL10n.setting}'),
      children: [_buildBgRun()],
    );
  }

  Widget _buildBgRun() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: TipText(l10n.bgRun, l10n.bgRunTip),
          trailing: StoreSwitch(prop: Stores.setting.bgRun),
        ),
        _buildBgRunPermission(),
      ],
    );
  }

  /// Says so when the switch above cannot do what it says.
  ///
  /// Running in the background means holding a foreground service, and a
  /// foreground service means a notification — so an app whose notifications
  /// are turned off is frozen the moment it leaves the screen, and every
  /// connection dies with nothing on screen explaining it (#1287). Shown only
  /// in that case: a row saying "this is fine" on every other device is noise.
  Widget _buildBgRunPermission() {
    return FutureWidget(
      future: MethodChans.notificationsAllowed(),
      loading: UIs.placeholder,
      error: (_, _) => UIs.placeholder,
      success: (allowed) {
        if (allowed != false) return UIs.placeholder;
        return ListTile(
          leading: Icon(Icons.notifications_off, color: UIs.primaryColor),
          title: TipText(libL10n.permission, l10n.bgRunNeedsNotification),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            await MethodChans.openNotificationSettings();
            // Read again on the way back: the point of sending someone there
            // is that they change it, and a row still saying it is off would
            // make them wonder whether it took.
            setStateSafe(() {});
          },
        );
      },
    );
  }

  Widget? _buildPlatformSetting() {
    // The App Store build's one standing entry about the DMG build. The line
    // in the update dialog is asked to go away and does; this one stays, so
    // there is somewhere to read the whole thing afterwards.
    if (DmgNotice.applies) {
      return ListTile(
        leading: const Icon(MingCute.apple_fill),
        title: Text(l10n.macDmgTitle),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => DmgNotice.show(context),
      );
    }

    return null;
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
          githubReleasesUrl: Urls.githubReleasesApi,
          storeUrl: Urls.appStore,
          force: BuildMode.isDebug,
          noticeBuilder: (ctx) =>
              DmgNotice.forUpdate(ctx, build: AppUpdateIface.newestBuild.value ?? BuildData.build),
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
        return ClipOval(
          child: Container(color: UIs.primaryColor, height: 27, width: 27),
        );
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
                        if (!supported) {
                          if (!_setting.useSystemPrimaryColor.fetch()) {
                            _setting.useSystemPrimaryColor.put(false);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {});
                            });
                          }
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          title: Text(libL10n.followSystem),
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
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                );
              },
            ),
            actions: [
              Btn.cancel(),
              Btn.ok(onTap: () => _onSaveColor(ctrl.text)),
            ],
          );
        });
      },
    );
  }

  void _onSaveColor(String s) {
    final color = s.fromColorHex;

    if (color == null) {
      Toast.error(libL10n.fail);
      return;
    }

    // Save the color seed to settings
    _setting.colorSeed.put(color.value255);

    // Only update UIs colors if we're not in system mode
    if (!_setting.useSystemPrimaryColor.fetch()) {
      UIs.primaryColor = color;
      UIs.colorSeed = color;
    }

    RNodes.app.notify();
    // `popDialog`: reached from the colour dialog's OK, with the settings
    // page's `context`.
    context.popDialog();
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
          // No `pop`: the picker has already closed — that is what `await`
          // returning a selection means — so popping here closed the settings
          // page behind it. `notify` is what makes the new language take
          // effect; nothing has to be dismissed for that.
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
      title: Text(libL10n.more),
      initiallyExpanded: false,
      children: [
        _buildBeta(),
        // Only where a report could actually be sent. A switch that cannot do
        // anything is worse than one that is not offered, and this build has
        // no DSN in it at all — which is every build made from this source
        // without one supplied. See [DiagnosticsUpload].
        if (DiagnosticsUpload.availableInBuild) ...[
          _buildDiagnosticsUpload(),
          _buildPrivacyPolicy(),
        ],
        if (isMobile) _buildWakeLock(),
        _buildCollapseUI(),
        if (isDesktop) _buildHideTitleBar(),
        _buildEditRawSettings(),
      ],
    );
  }

  /// Where the choice made on the intro page can be revisited.
  ///
  /// The same three levels, in the same words. Reports are kept on the device
  /// at every level — this only decides what is uploaded, and how often.
  Widget _buildDiagnosticsUpload() {
    return _setting.diagnosticsLevel.listenable().listenVal((name) {
      final current = DiagnosticsLevel.fromName(name);
      return ListTile(
        title: TipText(l10n.crashCollect, l10n.crashCollectFooter),
        trailing: Text(
          switch (current) {
            DiagnosticsLevel.none => l10n.crashCollectNone,
            DiagnosticsLevel.basic => l10n.crashCollectBasic,
            DiagnosticsLevel.full => l10n.crashCollectFull,
          },
          style: UIs.textGrey,
        ),
        onTap: () async {
          final picked = await context.showPickSingleDialog(
            title: l10n.crashCollect,
            items: DiagnosticsLevel.values,
            display: (e) => switch (e) {
              DiagnosticsLevel.none => l10n.crashCollectNone,
              DiagnosticsLevel.basic => l10n.crashCollectBasic,
              DiagnosticsLevel.full => l10n.crashCollectFull,
            },
            initial: current,
          );
          if (picked == null) return;
          _setting.diagnosticsLevel.put(picked.name);
          // Applied now rather than at the next launch: turning it down has to
          // take the sink out immediately, not eventually.
          unawaited(DiagnosticsUpload.sync());
        },
      );
    });
  }

  /// Beside the level, not inside the picker.
  ///
  /// The dialog that picks a level is a list of three options and has nowhere
  /// to put a link; and the policy is worth reaching without first opening the
  /// control that changes a setting. Shown under the same condition as the
  /// level itself — a build that cannot upload has nothing for the page to
  /// describe.
  Widget _buildPrivacyPolicy() {
    return ListTile(
      title: Text(l10n.privacyPolicy),
      trailing: const Icon(Icons.open_in_new, size: 17),
      onTap: Urls.privacyPolicy.launchUrl,
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

  Widget _buildHideTitleBar() {
    return ListTile(
      title: Text(libL10n.hideTitleBar),
      trailing: StoreSwitch(
        prop: _setting.hideTitleBar,
        callback: (value) async {
          await SystemUIs.updateTitleBarStyle(hideTitleBar: value);
        },
      ),
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
      final saved = await _setting.backupPassword.read();
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
            onSubmitted: (_) => context.popDialog(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => context.popDialog(null),
              child: Text(libL10n.cancel),
            ),
            TextButton(
              onPressed: () => context.popDialog(controller.text.trim()),
              child: Text(libL10n.ok),
            ),
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
          Toast.show(libL10n.cancel);
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
            _showInvalidDialog();
            return;
          }
        } catch (e, stack) {
          final msg =
              e.toString().contains('Failed to decrypt') ||
                  e.toString().contains('incorrect password')
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
        _showInvalidDialog();
        return;
      }
      try {
        final newSettings = json.decode(ret.val) as Map<String, dynamic>;
        if (encryptedKey != null) {
          final pwd = passwordUsed;
          if (pwd == null || pwd.isEmpty) {
            _showInvalidDialog();
            return;
          }
          final encrypted = Cryptor.encrypt(json.encode(newSettings), pwd);
          // Not stamping `lastUpdateTs`, which is what going straight to the
          // box used to do.
          //
          // TODO: decide whether that was intentional. Editing the raw settings
          // is a user edit, so leaving the timestamps alone means sync will not
          // carry it to another device until something else is changed.
          Stores.setting.set(
            encryptedKey,
            encrypted,
            updateLastUpdateTsOnSet: false,
          );
        } else {
          // One transaction, as `Backup.merge` does: this rewrites the whole
          // settings store, and half of an edit is not a state to leave behind.
          SqliteStore.transact(() {
          for (final entry in newSettings.entries) {
            final value = entry.value;
            // A key set to null means "clear this". Skipping it instead left
            // the previous value in place, and the key being present kept it
            // out of `removedKeys` below too — so the edit reported success and
            // changed nothing.
            if (value == null) {
              Stores.setting.remove(entry.key, updateLastUpdateTsOnRemove: false);
              continue;
            }
            Stores.setting.set(
              entry.key,
              value as Object,
              updateLastUpdateTsOnSet: false,
            );
          }
          final newKeys = newSettings.keys.toSet();
          // Internal keys are shown by the editor (it reads with
          // `includeInternalKeys: true`) but are not the user's to delete: one
          // of them records that the Hive import already ran, and dropping it
          // makes the next launch copy the retained boxes back over everything.
          final removedKeys = initialKeys.where(
            (e) => !newKeys.contains(e) && !Stores.setting.isInternalKey(e),
          );
          for (final key in removedKeys) {
            Stores.setting.remove(key, updateLastUpdateTsOnRemove: false);
          }
          });
        }
      } catch (e, trace) {
        context.showRoundDialog(
          title: libL10n.error,
          child: Text('${libL10n.save}:\n$e'),
        );
        Loggers.app.warning('Update json settings failed', e, trace);
      }
    }

    /// Encode [map] to String with indent `\t`
    final text = jsonIndentEncoder.convert(mapForEditor);
    final editorFont = _setting.editorFontFamily.fetch();
    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        text: text,
        lang: ProgLang.json,
        title: libL10n.setting,
        onSave: onSave,
        closeAfterSave: _setting.closeAfterSave.fetch(),
        softWrap: _setting.editorSoftWrap.fetch(),
        enableHighlight: _setting.editorHighlight.fetch(),
        lightTheme: HighlightTheme.fromThemeMapKey(
          _setting.editorTheme.fetch(),
        ),
        darkTheme: HighlightTheme.fromThemeMapKey(
          _setting.editorDarkTheme.fetch(),
        ),
        fontFamily: editorFont.isEmpty ? null : editorFont,
      ),
    );
  }
}

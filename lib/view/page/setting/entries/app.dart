part of '../entry.dart';

extension _App on _AppSettingsPageState {
  void _showInvalidDialog() {
    context.showRoundDialog(title: libL10n.fail, child: Text(libL10n.invalid));
  }

  List<SettingsGroup> _buildApp() {
    return [
      SettingsGroup(libL10n.general, [
        _buildLocale(),
        _buildThemeMode(),
        _buildAppColor(),
        _buildCollapseUI(),
      ]),
      SettingsGroup(libL10n.update, [_buildCheckUpdate(), _buildBeta()]),
      // Everything about the machine the app happens to be on, which is why
      // every row in it is behind a platform test. It is also where the rows
      // that used to be behind a tile called "More" ended up: a group with a
      // name is what that tile was standing in for.
      SettingsGroup(libL10n.system, [
        if (_bioAuthAvail == true) _buildBioAuth(),
        if (isMobile) _buildWakeLock(),
        if (isAndroid) _buildBgRun(),
        if (isDesktop) _buildHideTitleBar(),
        if (DmgNotice.applies) _buildDmgNotice(),
        // Debug only, which is where it was moved to while these rows were
        // flat. Naming the group does not put it back in a release build.
        if (kDebugMode) _buildEditRawSettings(),
      ]),
    ];
  }

  SettingsRow _buildBioAuth() {
    return SettingsRow(
      libL10n.bioAuth,
      PlatformPublicSettings.buildBioAuthRows,
    );
  }

  SettingsRow _buildBgRun() {
    final label = l10n.bgRun;
    return SettingsRow(
      label,
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: TipText(label, l10n.bgRunTip),
            trailing: StoreSwitch(prop: Stores.setting.bgRun),
          ),
          _buildBgRunPermission(),
        ],
      ),
      keywords: l10n.bgRunTip,
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

  /// The App Store build's one standing entry about the DMG build. The line in
  /// the update dialog is asked to go away and does; this one stays, so there
  /// is somewhere to read the whole thing afterwards.
  SettingsRow _buildDmgNotice() {
    final label = l10n.macDmgTitle;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.apple_fill),
        title: Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => DmgNotice.show(context),
      ),
    );
  }

  SettingsRow _buildCheckUpdate() {
    final label = libL10n.checkUpdate;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.update),
        title: Text(label),
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
            noticeBuilder: (ctx) => DmgNotice.forUpdate(
              ctx,
              build: AppUpdateIface.newestBuild.value ?? BuildData.build,
            ),
          ),
        ),
        trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
      ),
      // The version is on this row, so it is what somebody typing one is
      // looking for.
      keywords: 'v${BuildData.build}',
    );
  }

  SettingsRow _buildUpdateInterval() {
    final label = l10n.updateServerStatusInterval;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(label),
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
      ),
    );
  }

  SettingsRow _buildAppColor() {
    final label = libL10n.primaryColorSeed;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.colorize),
        title: Text(label),
        trailing: _setting.colorSeed.listenable().listenVal((_) {
          return ClipOval(
            child: Container(color: UIs.primaryColor, height: 23, width: 23),
          );
        }),
        onTap: _onTapAppColor,
      ),
    );
  }

  void _onTapAppColor() {
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
            return Column(mainAxisSize: MainAxisSize.min, children: children);
          },
        ),
        actions: [Btn.cancel(), Btn.ok(onTap: () => _onSaveColor(ctrl.text))],
      );
    });
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

  SettingsRow _buildMaxRetry() {
    final label = l10n.maxRetryCount;
    return SettingsRow(
      label,
      () => ValBuilder(
        listenable: _setting.maxRetryCount.listenable(),
        builder: (val) => ListTile(
          leading: const Icon(Icons.replay),
          title: Text(label),
          onTap: () async {
            final selected = await context.showPickSingleDialog(
              title: label,
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
      ),
    );
  }

  SettingsRow _buildThemeMode() {
    final label = libL10n.themeMode;
    // Issue #57
    final len = ThemeMode.values.length;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.moon_stars_fill),
        title: Text(label),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: label,
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
      ),
      keywords: 'AMOLED ${libL10n.dark} ${libL10n.bright}',
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

  SettingsRow _buildLocale() {
    final label = libL10n.language;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(IonIcons.language),
        title: Text(label),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: label,
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
      ),
    );
  }

  /// Its own page rather than two rows under the app's own settings, because
  /// what it decides is not the same kind of thing as the rows it sat among.
  ///
  /// A page can also be reached — from the intro that first asks the question,
  /// from a release note, from an answer to someone asking what is collected —
  /// and a row buried in a collapsed tile cannot.
  List<SettingsGroup> _buildPrivacy() {
    return [
      // Only where a report could actually be sent. A control that cannot do
      // anything is worse than one that is not offered, and a build with no
      // DSN in it can do nothing here. See [DiagnosticsUpload].
      //
      // Uncarded: the picker is a list of cards already.
      if (DiagnosticsUpload.availableInBuild)
        SettingsGroup(
          l10n.crashCollect,
          [_buildDiagnosticsUpload()],
          carded: false,
        ),
      // Not behind `availableInBuild` — a build with no upload endpoint is
      // exactly the one where handing the log over by hand is the only way a
      // crash gets reported at all. Absent when nothing crashed: a row reading
      // "no crash report" would be on the page for the whole life of every
      // healthy install, while a row that appears is itself the news.
      if (_savedCrashReport != null)
        SettingsGroup(libL10n.log, [_buildLastCrashReport()]),
      SettingsGroup(l10n.privacy, [
        // The policy describes what is kept on the device as well as what is
        // sent, so it has something to say in a build that uploads nothing.
        _buildPrivacyPolicy(),
        // Last, after everything about what leaves the device. It is the one
        // control here that acts on this moment instead — who can read the
        // screen.
        ?PlatformPublicSettings.privacyBlur?.row,
      ]),
    ];
  }

  /// Where the choice made on the intro page can be revisited.
  ///
  /// The same widget the intro puts the question with, so the answer reads the
  /// same in both places. It replaced a row whose trailing text named the
  /// current level and whose tap opened a picker of three bare labels: the
  /// sentence saying what a level actually sends existed only on the intro,
  /// which is the one screen a user sees once and cannot go back to.
  SettingsRow _buildDiagnosticsUpload() {
    return SettingsRow(
      l10n.crashCollect,
      () => DiagnosticsLevelPicker(
        // Applied now rather than at the next launch: turning it down has to
        // take the sink out immediately, not eventually.
        onPicked: () => unawaited(DiagnosticsUpload.sync()),
      ),
    );
  }

  /// The previous run's log, when there is one.
  ///
  /// Whether one exists is a file on disk, read once when the page opens —
  /// see [_AppSettingsPageState.initState]. Read here through a builder it
  /// flickered out and back on every unrelated rebuild, and the group it is in
  /// could not know whether to exist at all.
  SettingsRow _buildLastCrashReport() {
    final label = l10n.crashReportTitle;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: Text(label),
        subtitle: Text(l10n.crashLastRunFailed, style: UIs.textGrey),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final report = _savedCrashReport;
          if (report == null) return;
          final kept = await CrashReportDialog.show(context, report);
          // The row goes when the report does.
          if (kept) return;
          _savedCrashReport = null;
          refresh();
        },
      ),
    );
  }

  /// Beside the level, not inside the picker.
  ///
  /// The dialog that picks a level is a list of three options and has nowhere
  /// to put a link; and the policy is worth reaching without first opening the
  /// control that changes a setting.
  SettingsRow _buildPrivacyPolicy() {
    final label = l10n.privacyPolicy;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.policy_outlined),
        title: Text(label),
        trailing: const Icon(Icons.open_in_new, size: 17),
        onTap: Urls.privacyPolicy.launchUrl,
      ),
    );
  }

  SettingsRow _buildBeta() {
    final label = l10n.preReleaseUpdates;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.science_outlined),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.betaTest),
      ),
    );
  }

  SettingsRow _buildWakeLock() {
    final label = l10n.wakeLock;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.lock_fill),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.generalWakeLock),
      ),
    );
  }

  SettingsRow _buildCollapseUI() {
    final label = 'UI ${libL10n.fold}';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.unfold_less),
        title: TipText(label, l10n.collapseUITip),
        trailing: StoreSwitch(prop: _setting.collapseUIDefault),
      ),
      keywords: l10n.collapseUITip,
    );
  }

  SettingsRow _buildHideTitleBar() {
    final label = libL10n.hideTitleBar;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.web_asset),
        title: Text(label),
        trailing: StoreSwitch(
          prop: _setting.hideTitleBar,
          callback: (value) async {
            await SystemUIs.updateTitleBarStyle(hideTitleBar: value);
          },
        ),
      ),
    );
  }

  SettingsRow _buildEditRawSettings() {
    const label = '(Dev) Edit raw json';
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.data_object),
        title: const Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _editRawSettings,
      ),
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

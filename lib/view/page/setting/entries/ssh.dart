part of '../entry.dart';

extension _SSH on _AppSettingsPageState {
  void _refreshApp({bool closeDialog = false}) {
    if (closeDialog && mounted) {
      context.popDialog();
    }
    RNodes.app.notify();
  }

  List<SettingsGroup> _buildSSH() {
    return [
      SettingsGroup(libL10n.general, [
        if (isDesktop) _buildSSHConfigImport(),
        _buildLetterCache(),
        _buildSSHWakeLock(),
        _buildSSHVirtualKeyAutoOff(),
        _buildProgramStatusAlerts(),
      ]),
      SettingsGroup(libL10n.theme, [
        _buildTermTheme(),
        _buildFont(),
        _buildTermFontSize(),
        _buildTermLineHeight(),
      ]),
      // Three rows about one picture, which is what the tile they were folded
      // into was for.
      SettingsGroup(libL10n.background, [
        _buildSshBgImage(),
        _buildSshBgOpacity(),
        _buildSshBlurRadius(),
      ]),
      SettingsGroup(l10n.tmuxAutoAttach, [
        _buildTmuxAutoToggle(),
        _buildTmuxShowSelector(),
        _buildTmuxSessionName(),
      ]),
    ];
  }

  SettingsRow _buildSSHConfigImport() {
    final label = l10n.sshConfigImport;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.file_import_line),
        title: Text(label),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: _onTapSSHConfigImport,
      ),
    );
  }

  // Scanning a shared code used to be a row here, mobile-only and under SSH
  // *preferences*, while importing the same server from a file was under
  // Backup. Both are ways of acquiring a server, and which one a person needs
  // depends on what the sender picked — so they now sit together behind the
  // server list's add button. See `_onTapAddServer`.

  Future<void> _onTapSSHConfigImport() async {
    try {
      final servers = await SSHConfig.parseConfig();
      if (!mounted) return;
      if (servers.isEmpty) {
        Toast.show(l10n.sshConfigNoServers);
        return;
      }

      await _processSSHServers(servers);
    } catch (e, s) {
      if (!mounted) return;
      await _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  Future<void> _processSSHServers(List<Spi> servers) async {
    final existing = Stores.server.fetch();
    final deduplicated = ServerDeduplication.deduplicateServers(
      servers,
      existingServers: existing,
    );
    final resolved = ServerDeduplication.resolveNameConflicts(
      deduplicated,
      existingServers: existing,
    );
    final summary = ServerDeduplication.getImportSummary(servers, resolved);

    if (!summary.hasItemsToImport) {
      if (!mounted) return;
      Toast.show(l10n.sshConfigAllExist(summary.duplicates));
      return;
    }

    final shouldImport = await context.showRoundDialog<bool>(
      title: l10n.sshConfigImport,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFoundServers(summary.total)),
            if (summary.hasDuplicates)
              Text(
                l10n.sshConfigDuplicatesSkipped(summary.duplicates),
                style: UIs.textGrey,
              ),
            Text(l10n.sshConfigServersToImport(summary.toImport)),
            const SizedBox(height: 16),
            ...resolved.map((s) => Text('• ${s.name} (${s.displayAddr})')),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );

    if (!mounted) return;

    if (shouldImport == true) {
      await ServerDeduplication.importServersWithNotification(
        ref: ref,
        context: context,
        resolvedServers: resolved,
        originalCount: summary.total,
        allExistMessage: l10n.sshConfigAllExist,
        importedMessage: l10n.sshConfigImported,
      );
    }
  }

  Future<void> _handleImportSSHCfgPermissionIssue(
    Object e,
    StackTrace s,
  ) async {
    dprint('Error importing SSH config: $e');
    if (e is PathAccessException ||
        e.toString().contains('Operation not permitted')) {
      final useFilePicker = await context.showRoundDialog<bool>(
        title: l10n.sshConfigImport,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigPermissionDenied),
            const SizedBox(height: 8),
            Text(l10n.sshConfigManualSelect),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      if (!mounted) return;

      if (useFilePicker == true) {
        await _onTapSSHImportWithFilePicker();
      }
    } else {
      if (!mounted) return;
      context.showErrDialog(e, s);
    }
  }

  Future<void> _onTapSSHImportWithFilePicker() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.any,
        dialogTitle: l10n.sshConfigImport,
      );

      if (!mounted) return;

      if (picked?.path case final path?) {
        final servers = await SSHConfig.parseConfig(path);
        if (!mounted) return;
        if (servers.isEmpty) {
          Toast.show(l10n.sshConfigNoServers);
          return;
        }

        await _processSSHServers(servers);
      }
    } catch (e, s) {
      if (!mounted) return;
      context.showErrDialog(e, s);
    }
  }

  SettingsRow _buildSSHVirtualKeyAutoOff() {
    final label = l10n.sshVirtualKeyAutoOff;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.hotkey_fill),
        title: Text(label),
        subtitle: const Text('Ctrl & Alt', style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.sshVirtualKeyAutoOff),
      ),
      keywords: 'Ctrl Alt',
    );
  }

  SettingsRow _buildFont() {
    final label = libL10n.font;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.font_fill),
        title: TipText(label, l10n.termFontTip),
        // Which font is in use: the system's when none is chosen, and a chosen
        // one that did not load says so instead of looking as if it applied.
        trailing: ListenableBuilder(
          listenable: Listenable.merge([
            _setting.fontPath.listenable(),
            TerminalFont.failed,
          ]),
          builder: (_, _) {
            final fontName = _setting.fontPath.fetch().getFileName(
              withoutExtension: true,
            );
            if (fontName == null) {
              return Text(libL10n.system, style: UIs.text15);
            }
            if (TerminalFont.failed.value) {
              return Text(
                '$fontName · ${libL10n.fail}',
                style: UIs.text15.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              );
            }
            return Text(fontName, style: UIs.text15);
          },
        ),
        onTap: () {
          context.showRoundDialog(
            title: label,
            actions: [
              TextButton(
                onPressed: () async => await _pickFontFile(),
                child: Text(libL10n.file),
              ),
              TextButton(
                onPressed: () async {
                  await _clearCachedFont();
                  _setting.fontPath.delete();
                  await TerminalFont.load('');
                  _refreshApp(closeDialog: true);
                },
                child: Text(libL10n.clear),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _clearCachedFont() async {
    final oldFontPath = _setting.fontPath.fetch();
    if (oldFontPath.isEmpty || !oldFontPath.startsWith(Paths.font)) return;
    final oldFile = File(oldFontPath);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }
  }

  Future<void> _pickFontFile() async {
    final path = await Pfs.pickFilePath();
    if (path == null) return;

    // The iOS file picker grants access to the selected file in place, so keep
    // its original path instead of copying it into the app directory.
    if (isIOS) {
      _setting.fontPath.put(path);
      await TerminalFont.load(path);
    } else {
      await _clearCachedFont();

      final fontFile = File(path);
      final fontName = path.getFileName();
      final fontPath = Paths.font.joinPath(fontName ?? 'font.ttf');
      await fontFile.copy(fontPath);
      _setting.fontPath.put(fontPath);
      await TerminalFont.load(fontPath);
    }

    _refreshApp(closeDialog: true);
  }

  SettingsRow _buildTermFontSize() {
    final label = libL10n.fontSize;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.font_size_line),
        title: TipText(label, l10n.termFontSizeTip),
        trailing: ValBuilder(
          listenable: _setting.termFontSize.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () => _showFontSizeDialog(_setting.termFontSize),
      ),
      keywords: l10n.termFontSizeTip,
    );
  }

  SettingsRow _buildTermLineHeight() {
    final label = l10n.termLineHeight;
    final ctrl = TextEditingController(
      text: _setting.termLineHeight.fetch().toString(),
    );
    void onSave() {
      final val = double.tryParse(ctrl.text);
      if (val == null) {
        Toast.error('${libL10n.invalid}: ${ctrl.text}');
        return;
      }
      _setting.termLineHeight.put(
        val.clamp(TerminalLook.minLineHeight, TerminalLook.maxLineHeight),
      );
      context.popDialog();
    }

    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.format_line_spacing),
        title: TipText(label, l10n.termLineHeightTip),
        trailing: ValBuilder(
          listenable: _setting.termLineHeight.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () {
          ctrl.text = _setting.termLineHeight.fetch().toString();
          context.showRoundDialog(
            title: label,
            child: Input(
              controller: ctrl,
              autoFocus: true,
              type: const TextInputType.numberWithOptions(decimal: true),
              hint: '1.2',
              icon: Icons.format_line_spacing,
              suggestion: false,
              onSubmitted: (_) => onSave(),
            ),
            actions: Btn.ok(onTap: onSave).toList,
          );
        },
      ),
      keywords: l10n.termLineHeightTip,
    );
  }

  Future<void> _pickBgImage() async {
    final path = await Pfs.pickFilePath();
    if (path == null) return;

    final file = File(path);
    final extIndex = path.lastIndexOf('.');
    final ext = extIndex != -1 ? path.substring(extIndex) : '';
    final newPath = Paths.img.joinPath('ssh_bg$ext');
    final destFile = File(newPath);
    if (await destFile.exists()) {
      await destFile.delete();
    }
    await file.copy(newPath);
    _setting.sshBgImage.put(newPath);

    _refreshApp(closeDialog: true);
  }

  SettingsRow _buildTermTheme() {
    String index2Str(int index) {
      switch (index) {
        case 0:
          return libL10n.auto;
        case 1:
          return libL10n.bright;
        case 2:
          return libL10n.dark;
        default:
          return libL10n.error;
      }
    }

    return SettingsRow(
      libL10n.theme,
      () => ListTile(
        leading: const Icon(MingCute.moon_stars_fill),
        title: Text(libL10n.theme),
        trailing: ValBuilder(
          listenable: _setting.termTheme.listenable(),
          builder: (val) => Text(index2Str(val), style: UIs.text15),
        ),
        onTap: () async {
          final selected = await context.showPickSingleDialog(
            title: libL10n.theme,
            items: List.generate(3, (index) => index),
            display: (p0) => index2Str(p0),
            initial: _setting.termTheme.fetch(),
          );
          if (selected != null) {
            _setting.termTheme.put(selected);
          }
        },
      ),
    );
  }

  SettingsRow _buildSSHWakeLock() {
    final label = l10n.wakeLock;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.lock_fill),
        title: Text(label),
        trailing: StoreSwitch(prop: _setting.sshWakeLock),
      ),
    );
  }

  SettingsRow _buildProgramStatusAlerts() {
    final label = l10n.programStatusAlerts;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.notification_line),
        title: TipText(label, l10n.programStatusAlertsTip),
        trailing: StoreSwitch(prop: _setting.programStatusAlerts),
      ),
      keywords: l10n.programStatusAlertsTip,
    );
  }

  SettingsRow _buildLetterCache() {
    final label = l10n.letterCache;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Bootstrap.alphabet),
        title: TipText(label, '${l10n.letterCacheTip}\n${l10n.needRestart}'),
        trailing: StoreSwitch(prop: _setting.letterCache),
      ),
      keywords: l10n.letterCacheTip,
    );
  }

  SettingsRow _buildSshBgImage() {
    final label = libL10n.image;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.image),
        title: Text(label),
        trailing: _setting.sshBgImage.listenable().listenVal((val) {
          final name = val.getFileName();
          return Text(name ?? libL10n.empty, style: UIs.text15);
        }),
        onTap: () {
          context.showRoundDialog(
            title: label,
            actions: [
              TextButton(
                onPressed: () async => await _pickBgImage(),
                child: Text(libL10n.file),
              ),
              TextButton(
                onPressed: () {
                  _setting.sshBgImage.delete();
                  _refreshApp(closeDialog: true);
                },
                child: Text(libL10n.clear),
              ),
            ],
          );
        },
      ),
      keywords: libL10n.background,
    );
  }

  SettingsRow _buildSshBgOpacity() {
    void onSave(String s) {
      final val = double.tryParse(s);
      if (val == null) {
        Toast.error(libL10n.fail);
        return;
      }
      _setting.sshBgOpacity.put(val.clamp(0.0, 1.0));
      context.popDialog();
    }

    return SettingsRow(
      libL10n.opacity,
      () => ListTile(
        leading: const Icon(Icons.opacity),
        title: Text(libL10n.opacity),
        trailing: ValBuilder(
          listenable: _setting.sshBgOpacity.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () => context.showRoundDialog(
          title: libL10n.opacity,
          child: Input(
            controller: _sshOpacityCtrl,
            autoFocus: true,
            type: TextInputType.number,
            hint: '0.3',
            icon: Icons.opacity,
            suggestion: false,
            onSubmitted: onSave,
          ),
          actions: Btn.ok(onTap: () => onSave(_sshOpacityCtrl.text)).toList,
        ),
      ),
      keywords: libL10n.background,
    );
  }

  SettingsRow _buildSshBlurRadius() {
    void onSave(String s) {
      final val = double.tryParse(s);
      if (val == null) {
        Toast.error(libL10n.fail);
        return;
      }
      const minRadius = 0.0;
      const maxBlur = 50.0;
      final clampedVal = val.clamp(minRadius, maxBlur);
      _setting.sshBlurRadius.put(clampedVal);
      context.popDialog();
    }

    return SettingsRow(
      libL10n.blurRadius,
      () => ListTile(
        leading: const Icon(Icons.blur_on),
        title: Text(libL10n.blurRadius),
        trailing: ValBuilder(
          listenable: _setting.sshBlurRadius.listenable(),
          builder: (val) => Text(val.toString(), style: UIs.text15),
        ),
        onTap: () => context.showRoundDialog(
          title: libL10n.blurRadius,
          child: Input(
            controller: _sshBlurCtrl,
            autoFocus: true,
            type: TextInputType.number,
            hint: '0',
            icon: Icons.blur_on,
            suggestion: false,
            onSubmitted: onSave,
          ),
          actions: Btn.ok(onTap: () => onSave(_sshBlurCtrl.text)).toList,
        ),
      ),
      keywords: libL10n.background,
    );
  }

  SettingsRow _buildTmuxAutoToggle() {
    final label = l10n.tmuxAuto;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.terminal),
        title: Text(label),
        subtitle: Text(l10n.tmuxAutoTip, style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.tmuxAuto),
      ),
      keywords: 'tmux ${l10n.tmuxAutoTip}',
    );
  }

  SettingsRow _buildTmuxShowSelector() {
    final label = l10n.tmuxSessionSelector;
    return SettingsRow(
      label,
      () => _setting.tmuxAuto.listenable().listenVal((autoEnabled) {
        return IgnorePointer(
          ignoring: !autoEnabled,
          child: Opacity(
            opacity: autoEnabled ? 1.0 : 0.5,
            child: ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(label),
              subtitle: Text(l10n.tmuxSessionSelectorTip, style: UIs.textGrey),
              trailing: StoreSwitch(prop: _setting.tmuxShowSelector),
            ),
          ),
        );
      }),
      keywords: 'tmux ${l10n.tmuxSessionSelectorTip}',
    );
  }

  SettingsRow _buildTmuxSessionName() {
    final label = l10n.tmuxDefaultSessionName;
    return SettingsRow(
      label,
      () => _setting.tmuxAuto.listenable().listenVal((autoEnabled) {
        return _setting.tmuxSessionName.listenable().listenVal((name) {
          final displayName = name.isEmpty ? 'server_box' : name;
          return IgnorePointer(
            ignoring: !autoEnabled,
            child: Opacity(
              opacity: autoEnabled ? 1.0 : 0.5,
              child: ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(label),
                trailing: Text(displayName, style: UIs.text15),
                onTap: () => _showTmuxSessionNameDialog(name),
              ),
            ),
          );
        });
      }),
      keywords: 'tmux',
    );
  }

  Future<void> _showTmuxSessionNameDialog(String current) async {
    withTextFieldController((ctrl) async {
      ctrl.text = current;
      void onSave() {
        _setting.tmuxSessionName.put(ctrl.text.trim());
        // `popDialog`: `context` here is the settings page's, and the dialog
        // is on the root navigator.
        context.popDialog();
      }

      await context.showRoundDialog<bool>(
        title: l10n.tmuxSessionName,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          hint: 'server_box',
          suggestion: false,
          onSubmitted: (_) => onSave(),
        ),
        actions: Btn.ok(onTap: onSave).toList,
      );
    });
  }
}

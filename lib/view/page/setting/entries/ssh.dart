part of '../entry.dart';

extension _SSH on _AppSettingsPageState {
  void _refreshApp({bool closeDialog = false}) {
    if (closeDialog && mounted) {
      context.popDialog();
    }
    RNodes.app.notify();
  }

  Widget _buildSSH() {
    return Column(
      children: [
        if (isDesktop) _buildSSHConfigImport(),
        if (isDesktop) _buildSshConnectionMode(),
        _buildLetterCache(),
        _buildSSHWakeLock(),
        _buildTermTheme(),
        _buildFont(),
        _buildTermFontSize(),
        _buildSshBg(),
        if (isLinux) _buildDesktopTerminal(),
        if (isDesktop) _buildDesktopSshAutoCopyPassword(),
        _buildSSHVirtualKeyAutoOff(),
        _buildTmuxAuto(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildSSHConfigImport() {
    return ListTile(
      leading: const Icon(MingCute.file_import_line),
      title: Text(l10n.sshConfigImport),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapSSHConfigImport,
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
      Toast.show(l10n.sshConfigAllExist('${summary.duplicates}'));
      return;
    }

    final shouldImport = await context.showRoundDialog<bool>(
      title: l10n.sshConfigImport,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshConfigFoundServers('${summary.total}')),
            if (summary.hasDuplicates)
              Text(
                l10n.sshConfigDuplicatesSkipped('${summary.duplicates}'),
                style: UIs.textGrey,
              ),
            Text(l10n.sshConfigServersToImport('${summary.toImport}')),
            const SizedBox(height: 16),
            ...resolved.map(
              (s) => Text('• ${s.name} (${s.displayAddr})'),
            ),
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

  Widget _buildSSHVirtualKeyAutoOff() {
    return ListTile(
      leading: const Icon(MingCute.hotkey_fill),
      title: Text(l10n.sshVirtualKeyAutoOff),
      subtitle: const Text('Ctrl & Alt', style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.sshVirtualKeyAutoOff),
    );
  }

  Widget _buildFont() {
    return ListTile(
      leading: const Icon(MingCute.font_fill),
      title: Text(libL10n.font),
      trailing: _setting.fontPath.listenable().listenVal((val) {
        final fontName = val.getFileName(withoutExtension: true);
        return Text(fontName ?? libL10n.empty, style: UIs.text15);
      }),
      onTap: () {
        context.showRoundDialog(
          title: libL10n.font,
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(libL10n.file),
            ),
            TextButton(
              onPressed: () async {
                await _clearCachedFont();
                _setting.fontPath.delete();
                _refreshApp(closeDialog: true);
              },
              child: Text(libL10n.clear),
            ),
          ],
        );
      },
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

    // iOS can't copy file to app dir, so we need to use the original path
    if (isIOS) {
      _setting.fontPath.put(path);
      await FontUtils.loadFrom(path);
    } else {
      await _clearCachedFont();

      final fontFile = File(path);
      final fontName = path.getFileName();
      final fontPath = Paths.font.joinPath(fontName ?? 'font.ttf');
      await fontFile.copy(fontPath);
      _setting.fontPath.put(fontPath);
      await FontUtils.loadFrom(fontPath);
    }

    _refreshApp(closeDialog: true);
  }

  Widget _buildTermFontSize() {
    return ListTile(
      leading: const Icon(MingCute.font_size_line),
      title: TipText(libL10n.fontSize, l10n.termFontSizeTip),
      trailing: ValBuilder(
        listenable: _setting.termFontSize.listenable(),
        builder: (val) => Text(val.toString(), style: UIs.text15),
      ),
      onTap: () => _showFontSizeDialog(_setting.termFontSize),
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

  Widget _buildDesktopTerminal() {
    return _setting.desktopTerminal.listenable().listenVal((val) {
      return ListTile(
        leading: const Icon(Icons.terminal),
        title: TipText(libL10n.terminal, l10n.desktopTerminalTip),
        trailing: Text(
          val,
          style: UIs.text15,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          withTextFieldController((ctrl) async {
            ctrl.text = val;
            void onSave() {
              _setting.desktopTerminal.put(ctrl.text.trim());
              context.popDialog();
            }

            await context.showRoundDialog<bool>(
              title: libL10n.select,
              child: Input(
                controller: ctrl,
                autoFocus: true,
                label: libL10n.terminal,
                hint: 'x-terminal-emulator / gnome-terminal',
                icon: Icons.edit,
                suggestion: false,
                onSubmitted: (_) => onSave(),
              ),
              actions: Btn.ok(onTap: onSave).toList,
            );
          });
        },
      );
    });
  }

  Widget _buildDesktopSshAutoCopyPassword() {
    return ListTile(
      leading: const Icon(Icons.password),
      title: Text('${libL10n.copy} ${libL10n.pwd}'),
      subtitle: Text('SSH', style: UIs.textGrey),
      trailing: StoreSwitch(prop: _setting.desktopSshAutoCopyPassword),
    );
  }

  Widget _buildSshConnectionMode() {
    return _setting.sshConnectionMode.listenable().listenVal((useSystemSsh) {
      final title = useSystemSsh
          ? l10n.sshConnectionModeUseSystem
          : l10n.sshConnectionModeUseBuiltin;
      return ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: Text(title),
        subtitle: Text(l10n.sshConnectionModeTip, style: UIs.textGrey),
        trailing: StoreSwitch(prop: _setting.sshConnectionMode),
      );
    });
  }

  Widget _buildTermTheme() {
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

    return ListTile(
      leading: const Icon(MingCute.moon_stars_fill, size: _kIconSize),
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
    );
  }

  Widget _buildSSHWakeLock() {
    return ListTile(
      leading: const Icon(MingCute.lock_fill),
      title: Text(l10n.wakeLock),
      trailing: StoreSwitch(prop: _setting.sshWakeLock),
    );
  }

  Widget _buildLetterCache() {
    return ListTile(
      leading: const Icon(Bootstrap.alphabet),
      title: TipText(
        l10n.letterCache,
        '${l10n.letterCacheTip}\n${l10n.needRestart}',
      ),
      trailing: StoreSwitch(prop: _setting.letterCache),
    );
  }

  Widget _buildSshBg() {
    return ExpandTile(
      leading: const Icon(MingCute.background_fill),
      title: Text(libL10n.background),
      children: [
        _buildSshBgImage(),
        _buildSshBgOpacity(),
        _buildSshBlurRadius(),
      ],
    );
  }

  Widget _buildSshBgImage() {
    return ListTile(
      leading: const Icon(Icons.image),
      title: Text(libL10n.image),
      trailing: _setting.sshBgImage.listenable().listenVal((val) {
        final name = val.getFileName();
        return Text(name ?? libL10n.empty, style: UIs.text15);
      }),
      onTap: () {
        context.showRoundDialog(
          title: libL10n.image,
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
    );
  }

  Widget _buildSshBgOpacity() {
    void onSave(String s) {
      final val = double.tryParse(s);
      if (val == null) {
        Toast.error(libL10n.fail);
        return;
      }
      _setting.sshBgOpacity.put(val.clamp(0.0, 1.0));
      context.popDialog();
    }

    return ListTile(
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
    );
  }

  Widget _buildSshBlurRadius() {
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

    return ListTile(
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
    );
  }

  Widget _buildTmuxAuto() {
    return ExpandTile(
      leading: const Icon(Icons.terminal),
      title: Text(l10n.tmuxAutoAttach),
      children: [
        _buildTmuxAutoToggle(),
        _buildTmuxShowSelector(),
        _buildTmuxSessionName(),
      ],
    );
  }

  Widget _buildTmuxAutoToggle() {
    return ListTile(
      title: Text(l10n.tmuxAuto),
      subtitle: Text(
        l10n.tmuxAutoTip,
        style: UIs.textGrey,
      ),
      trailing: StoreSwitch(prop: _setting.tmuxAuto),
    );
  }

  Widget _buildTmuxShowSelector() {
    return _setting.tmuxAuto.listenable().listenVal((autoEnabled) {
      return IgnorePointer(
        ignoring: !autoEnabled,
        child: Opacity(
          opacity: autoEnabled ? 1.0 : 0.5,
          child: ListTile(
            title: Text(l10n.tmuxSessionSelector),
            subtitle: Text(
              l10n.tmuxSessionSelectorTip,
              style: UIs.textGrey,
            ),
            trailing: StoreSwitch(prop: _setting.tmuxShowSelector),
          ),
        ),
      );
    });
  }

  Widget _buildTmuxSessionName() {
    return _setting.tmuxAuto.listenable().listenVal((autoEnabled) {
      return _setting.tmuxSessionName.listenable().listenVal((name) {
        final displayName = name.isEmpty ? 'server_box' : name;
        return IgnorePointer(
          ignoring: !autoEnabled,
          child: Opacity(
            opacity: autoEnabled ? 1.0 : 0.5,
            child: ListTile(
              title: Text(l10n.tmuxDefaultSessionName),
              trailing: Text(displayName, style: UIs.text15),
              onTap: () => _showTmuxSessionNameDialog(name),
            ),
          ),
        );
      });
    });
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

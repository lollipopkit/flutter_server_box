part of '../entry.dart';

extension _SSH on _AppSettingsPageState {
  void _refreshApp({bool closeDialog = false}) {
    if (closeDialog && mounted) {
      context.pop();
    }
    RNodes.app.notify();
  }

  Widget _buildSSH() {
    return Column(
      children: [
        if (isDesktop) _buildSSHConfigImport(),
        if (isMobile) _buildQrScan(),
        _buildSSHDiscovery(),
        _buildLetterCache(),
        _buildSSHWakeLock(),
        _buildTermTheme(),
        _buildFont(),
        _buildTermFontSize(),
        _buildSshBg(),
        if (isDesktop) _buildDesktopTerminal(),
        if (isDesktop) _buildDesktopSshAutoCopyPassword(),
        _buildSSHVirtualKeyAutoOff(),
        if (isMobile) _buildSSHVirtKeys(),
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

  Widget _buildQrScan() {
    return ListTile(
      leading: const Icon(Icons.qr_code),
      title: Text(libL10n.import),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapQrScan,
    );
  }

  Future<void> _onTapQrScan() async {
    final ret = await BarcodeScannerPage.route.go(
      context,
      args: const BarcodeScannerPageArgs(),
    );
    final code = ret?.text;
    if (code == null) return;
    if (!mounted) return;

    try {
      final spi = Spi.fromJson(json.decode(code));
      final existingIds = ref.read(serversProvider).servers.keys;
      if (existingIds.contains(spi.id)) {
        context.showSnackBar('${l10n.sameIdServerExist}: ${spi.id}');
        return;
      }
      final resolvedList = ServerDeduplication.resolveNameConflicts([spi]);
      final resolvedSpi = resolvedList.first;
      ref.read(serversProvider.notifier).addServer(resolvedSpi);
      context.showSnackBar(libL10n.success);
    } catch (e, s) {
      context.showErrDialog(e, s);
    }
  }

  Widget _buildSSHDiscovery() {
    return ListTile(
      leading: const Icon(BoxIcons.bx_search),
      title: Text(l10n.discoverSshServers),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapSSHDiscovery,
    );
  }

  Future<void> _onTapSSHDiscovery() async {
    try {
      final result = await SshDiscoveryPage.route.go(context);
      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        await _processDiscoveredServers(result);
      }
    } catch (e, s) {
      if (!mounted) return;
      context.showErrDialog(e, s);
    }
  }

  Future<void> _processDiscoveredServers(
    List<SshDiscoveryResult> discoveredServers,
  ) async {
    final defaultUsername = 'root';
    final usernameController = TextEditingController(text: defaultUsername);

    try {
      final shouldImport = await context.showRoundDialog<bool>(
        title: libL10n.import,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.sshConfigFoundServers('${discoveredServers.length}')),
            const SizedBox(height: 8),
            Input(controller: usernameController, label: libL10n.user),
          ],
        ),
        actions: Btnx.cancelOk,
      );

      if (!mounted) return;

      if (shouldImport == true) {
        final username = usernameController.text.isNotEmpty
            ? usernameController.text
            : defaultUsername;
        final servers = discoveredServers
            .map(
              (result) => Spi(
                id: ShortId.generate(),
                name: result.ip,
                ip: result.ip,
                port: result.port,
                user: username,
              ),
            )
            .toList();

        await ServerDeduplication.importServersWithNotification(
          servers: servers,
          ref: ref,
          context: context,
          allExistMessage: l10n.sshConfigAllExist,
          importedMessage: (count) =>
              '${libL10n.success}: $count ${libL10n.servers}',
        );
      }
    } finally {
      usernameController.dispose();
    }
  }

  Future<void> _onTapSSHConfigImport() async {
    try {
      final servers = await SSHConfig.parseConfig();
      if (!mounted) return;
      if (servers.isEmpty) {
        context.showSnackBar(l10n.sshConfigNoServers);
        return;
      }

      await _processSSHServers(servers);
    } catch (e, s) {
      if (!mounted) return;
      await _handleImportSSHCfgPermissionIssue(e, s);
    }
  }

  Future<void> _processSSHServers(List<Spi> servers) async {
    final deduplicated = ServerDeduplication.deduplicateServers(servers);
    final resolved = ServerDeduplication.resolveNameConflicts(deduplicated);
    final summary = ServerDeduplication.getImportSummary(servers, resolved);

    if (!summary.hasItemsToImport) {
      if (!mounted) return;
      context.showSnackBar(l10n.sshConfigAllExist('${summary.duplicates}'));
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
              (s) => Text('• ${s.name} (${s.user}@${s.ip}:${s.port})'),
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        dialogTitle: l10n.sshConfigImport,
      );

      if (!mounted) return;

      if (result?.files.single.path case final path?) {
        final servers = await SSHConfig.parseConfig(path);
        if (!mounted) return;
        if (servers.isEmpty) {
          context.showSnackBar(l10n.sshConfigNoServers);
          return;
        }

        await _processSSHServers(servers);
      }
    } catch (e, s) {
      if (!mounted) return;
      context.showErrDialog(e, s);
    }
  }

  Widget _buildSSHVirtKeys() {
    return ListTile(
      leading: const Icon(BoxIcons.bxs_keyboard),
      title: Text(l10n.editVirtKeys),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => SSHVirtKeySettingPage.route.go(context),
    );
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
      title: TipText(l10n.fontSize, l10n.termFontSizeTip),
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
              context.pop();
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
      // title: Text(l10n.letterCache),
      // subtitle: Text(
      //   '${l10n.letterCacheTip}\n${l10n.needRestart}',
      //   style: UIs.textGrey,
      // ),
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
        context.showSnackBar(libL10n.fail);
        return;
      }
      _setting.sshBgOpacity.put(val.clamp(0.0, 1.0));
      context.pop();
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
        context.showSnackBar(libL10n.fail);
        return;
      }
      const minRadius = 0.0;
      const maxBlur = 50.0;
      final clampedVal = val.clamp(minRadius, maxBlur);
      _setting.sshBlurRadius.put(clampedVal);
      context.pop();
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
}

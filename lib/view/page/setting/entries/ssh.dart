part of '../entry.dart';

extension _SSH on _AppSettingsPageState {
  Widget _buildSSH() {
    return Column(
      children: [
        _buildLetterCache(),
        _buildSSHWakeLock(),
        _buildTermTheme(),
        _buildFont(),
        _buildTermFontSize(),
        _buildSshBg(),
        if (isDesktop) _buildDesktopTerminal(),
        _buildSSHVirtualKeyAutoOff(),
        if (isMobile) _buildSSHVirtKeys(),
      ].map((e) => CardX(child: e)).toList(),
    );
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
      title: Text(l10n.font),
      trailing: _setting.fontPath.listenable().listenVal((val) {
        final fontName = val.getFileName();
        return Text(fontName ?? libL10n.empty, style: UIs.text15);
      }),
      onTap: () {
        context.showRoundDialog(
          title: l10n.font,
          actions: [
            TextButton(onPressed: () async => await _pickFontFile(), child: Text(libL10n.file)),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                RNodes.app.notify();
              },
              child: Text(libL10n.clear),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFontFile() async {
    final path = await Pfs.pickFilePath();
    if (path == null) return;

    // iOS can't copy file to app dir, so we need to use the original path
    if (isIOS) {
      _setting.fontPath.put(path);
    } else {
      final fontFile = File(path);
      await fontFile.copy(Paths.font);
      _setting.fontPath.put(Paths.font);
    }

    context.pop();
    RNodes.app.notify();
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

    context.pop();
    RNodes.app.notify();
  }

  Widget _buildDesktopTerminal() {
    return _setting.desktopTerminal.listenable().listenVal((val) {
      return ListTile(
        leading: const Icon(Icons.terminal),
        title: TipText(l10n.terminal, l10n.desktopTerminalTip),
        trailing: Text(val, style: UIs.text15, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () async {
          final ctrl = TextEditingController(text: val);
          void onSave() {
            _setting.desktopTerminal.put(ctrl.text.trim());
            context.pop();
          }

          await context.showRoundDialog<bool>(
            title: libL10n.select,
            child: Input(
              controller: ctrl,
              autoFocus: true,
              label: l10n.terminal,
              hint: 'x-terminal-emulator / gnome-terminal',
              icon: Icons.edit,
              suggestion: false,
              onSubmitted: (_) => onSave(),
            ),
            actions: Btn.ok(onTap: onSave).toList,
          );
          ctrl.dispose();
        },
      );
    });
  }

  Widget _buildTermTheme() {
    String index2Str(int index) {
      switch (index) {
        case 0:
          return l10n.system;
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
      title: Text(l10n.theme),
      trailing: ValBuilder(
        listenable: _setting.termTheme.listenable(),
        builder: (val) => Text(index2Str(val), style: UIs.text15),
      ),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: l10n.theme,
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
      title: TipText(l10n.letterCache, '${l10n.letterCacheTip}\n${l10n.needRestart}'),
      trailing: StoreSwitch(prop: _setting.letterCache),
    );
  }

  Widget _buildSshBg() {
    return ExpandTile(
      leading: const Icon(MingCute.background_fill),
      title: Text(libL10n.background),
      children: [_buildSshBgImage(), _buildSshBgOpacity(), _buildSshBlurRadius()],
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
            TextButton(onPressed: () async => await _pickBgImage(), child: Text(libL10n.file)),
            TextButton(
              onPressed: () {
                _setting.sshBgImage.delete();
                context.pop();
                RNodes.app.notify();
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

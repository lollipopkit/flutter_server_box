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
      onTap: () => AppRoutes.sshVirtKeySetting().go(context),
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
      trailing: _setting.fontPath.listenable().listenVal(
        (val) {
          final fontName = val.getFileName();
          return Text(
            fontName ?? libL10n.empty,
            style: UIs.text15,
          );
        },
      ),
      onTap: () {
        context.showRoundDialog(
          title: l10n.font,
          actions: [
            TextButton(
              onPressed: () async => await _pickFontFile(),
              child: Text(libL10n.file),
            ),
            TextButton(
              onPressed: () {
                _setting.fontPath.delete();
                context.pop();
                RNodes.app.notify();
              },
              child: Text(libL10n.clear),
            )
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
        builder: (val) => Text(
          index2Str(val),
          style: UIs.text15,
        ),
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
      title: TipText(
          l10n.letterCache, '${l10n.letterCacheTip}\n${l10n.needRestart}'),
      trailing: StoreSwitch(prop: _setting.letterCache),
    );
  }
}

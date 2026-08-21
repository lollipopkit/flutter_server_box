part of '../entry.dart';

/// The Linux system on this device: which one, and where it gets its bytes.
///
/// Named for Linux and not for the distribution, because which one is installed
/// is a thing that can change — and the row that changes it is the first one
/// here.
///
/// Three settings and no more, because these are what a network or a preference
/// can make wrong and nothing in the app can work around: the default mirror is
/// not reachable everywhere, and neither are the public resolvers seeded into
/// the guest — which an app cannot replace with the system's, since it can read
/// those on neither platform.
///
/// The mirror and the resolver are seeded into the guest's files at install, so
/// saving either rewrites them in the system already on disk. Otherwise the
/// setting would only take effect on the next install, which on iOS means
/// deleting everything the package manager ever put there.
extension _Linux on _AppSettingsPageState {
  Widget _buildLinux() {
    // The distribution decides what the two rows below it are *about* — the
    // mirror is per distribution and the header of each dialog names it — so
    // all three redraw together when it changes.
    return ValBuilder(
      listenable: _setting.linuxDistro.listenable(),
      builder: (_) => Column(
        children: [
          _buildLinuxDistro(),
          _buildLinuxShell(),
          _buildLinuxMirror(),
          _buildLinuxDns(),
        ].map((e) => CardX(child: e)).toList(),
      ),
    );
  }

  Widget _buildLinuxDistro() {
    final selected = Rootfs.selected;
    final installed = Rootfs.installed;
    return ListTile(
      leading: const Icon(Icons.layers_outlined, size: _kIconSize),
      title: Text(l10n.distro),
      // Only says anything while the two disagree, which is a state the user
      // can reach by declining the download after picking: the setting moved
      // and the tree did not. Saying so is what makes the next tap explicable.
      subtitle: installed == null || installed.distro == selected
          ? null
          : Text(
              '${installed.distro.label} → ${selected.label}',
              style: UIs.textGrey,
            ),
      trailing: Text(selected.label, style: UIs.text15),
      onTap: _onTapLinuxDistro,
    );
  }

  Widget _buildLinuxShell() {
    return ListTile(
      leading: const Icon(Icons.terminal_outlined, size: _kIconSize),
      title: TipText(libL10n.terminal, l10n.linuxShellTip),
      subtitle: ValBuilder(
        listenable: _setting.linuxShell.listenable(),
        builder: (val) => Text(val, style: UIs.textGrey),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapLinuxShell,
    );
  }

  Widget _buildLinuxMirror() {
    return ListTile(
      leading: const Icon(Icons.cloud_download_outlined, size: _kIconSize),
      title: TipText(l10n.mirror, l10n.linuxNetTip),
      subtitle: ValBuilder(
        listenable: _setting.linuxMirrors.listenable(),
        // The mirror in force, not the row stored for it: nothing stored means
        // the distribution's own default, and that is what would be fetched.
        builder: (_) => Text(
          linuxMirror(),
          style: UIs.textGrey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapLinuxMirror,
    );
  }

  Widget _buildLinuxDns() {
    return ListTile(
      leading: const Icon(Icons.dns_outlined, size: _kIconSize),
      title: TipText('DNS', l10n.linuxNetTip),
      subtitle: ValBuilder(
        listenable: _setting.linuxDns.listenable(),
        builder: (val) => Text(
          val,
          style: UIs.textGrey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _onTapLinuxDns,
    );
  }

  /// Picks a distribution, and replaces what is installed if that is what it
  /// takes.
  ///
  /// The setting is written *before* the download, so that [install] reads the
  /// one that was chosen — and so that declining the download leaves the
  /// choice made and the tree gone, which the row above says out loud rather
  /// than pretending nothing happened.
  Future<void> _onTapLinuxDistro() async {
    final picked = await context.showPickSingleDialog(
      title: l10n.distro,
      items: LinuxDistro.values,
      display: (e) => e.label,
      initial: Rootfs.selected,
    );
    if (picked == null || picked == Rootfs.selected) return;

    final installed = Rootfs.installed;
    // Nothing on disk: the setting is the whole change, and whenever a terminal
    // next offers to install one it reads this.
    if (installed == null) {
      _setting.linuxDistro.put(picked.id);
      return;
    }

    if (!mounted) return;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        l10n.distroSwitchTip(installed.distro.label, picked.label),
      ),
      actions: Btnx.cancelRedOk,
    );
    if (confirmed != true || !mounted) return;

    await Rootfs.remove();
    _setting.linuxDistro.put(picked.id);
    if (!mounted) return;
    await installRootfs(context);
    refresh();
  }

  /// Picking a shell, checked against the system that is actually installed.
  ///
  /// Shape and then existence, because neither failure is visible later: the
  /// engine answers `ENOENT` from inside `sbm_ish_open`, and a terminal that
  /// opens and dies on sight says nothing about why. The C side falls back to
  /// `/bin/sh` for the same reason, but only a setting that has gone stale —
  /// `apk del` on whatever it named — should ever reach that fallback.
  ///
  /// Not checked when nothing is installed: there is no tree to look in, and
  /// refusing a path because of that would be wrong rather than careful.
  void _onTapLinuxShell() {
    withTextFieldController((ctrl) async {
      ctrl.text = _setting.linuxShell.fetch();

      Future<void> save() async {
        final typed = ctrl.text.trim();
        context.popDialog();
        // Empty is how the default is asked for, here as in the rows below.
        final chosen = typed.isEmpty ? Defaults.linuxShell : typed;
        final root = Rootfs.root;
        final ok =
            isShellPathValid(chosen) &&
            (root == null ||
                !Rootfs.isReady ||
                await shellExistsIn(root, chosen));
        if (!ok) {
          if (!mounted) return;
          await context.showRoundDialog(
            title: libL10n.fail,
            child: Text('${libL10n.invalid}: $chosen'),
          );
          return;
        }
        _setting.linuxShell.put(chosen);
        Toast.success(libL10n.success);
      }

      await context.showRoundDialog(
        title: libL10n.terminal,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: libL10n.terminal,
          hint: '/bin/sh  /bin/ash  /usr/bin/fish',
          icon: Icons.terminal_outlined,
          suggestion: false,
          onSubmitted: (_) => save(),
        ),
        actions: Btn.ok(onTap: save).toList,
      );
    });
  }

  void _onTapLinuxMirror() {
    final distro = Rootfs.selected;
    _showLinuxNetDialog(
      // Which distribution's mirror, since it is only that one's.
      title: '${distro.label} ${l10n.mirror.toLowerCase()}',
      // What is stored, not what is in force: empty is how the default is
      // asked for, and pre-filling the default would make that impossible to
      // tell from having typed it.
      initial: Stores.setting.linuxMirrors.fetch()[distro.id] ?? '',
      icon: Icons.link,
      // Not a URL the app could have guessed: a mirror is a host someone was
      // told to use, so the hint names one rather than describing the shape.
      hint: distro.defaultMirror,
      // Empty is the way back to the default, so it is not an invalid value.
      validate: (value) => value.isEmpty || isMirrorValid(value),
      onSave: (value) => setLinuxMirror(distro, value),
    );
  }

  void _onTapLinuxDns() {
    _showLinuxNetDialog(
      title: 'DNS',
      initial: _setting.linuxDns.fetch(),
      icon: Icons.dns_outlined,
      hint: Defaults.linuxDns,
      // Addresses only, and every one of them: `resolv.conf` takes nothing
      // else, and a name typed here fails as a timeout rather than as a
      // mistake. Anything dropped by the parser would be silently gone, so a
      // partly-valid list is refused instead of trimmed.
      validate: (value) =>
          value.isEmpty ||
          parseNameservers(value).length ==
              value.split(RegExp(r'[\s,;]+')).where((e) => e.isNotEmpty).length,
      onSave: (value) => _setting.linuxDns.put(
        value.isEmpty ? Defaults.linuxDns : value,
      ),
    );
  }

  /// The dialog both network settings use, and the write both of them need.
  ///
  /// Pops before it validates, so that the failure dialog is not pushed under
  /// the one being closed — `showRoundDialog` puts both on the root navigator.
  void _showLinuxNetDialog({
    required String title,
    required String initial,
    required String hint,
    required IconData icon,
    required bool Function(String value) validate,
    required void Function(String value) onSave,
  }) {
    withTextFieldController((ctrl) async {
      ctrl.text = initial;

      Future<void> save() async {
        final value = ctrl.text.trim();
        context.popDialog();
        if (!validate(value)) {
          await context.showRoundDialog(
            title: libL10n.fail,
            child: Text('${libL10n.invalid}: $value'),
          );
          return;
        }
        onSave(value);
        // The setting is only half of it: what the package manager reads is
        // the file, and that was written at install.
        await Rootfs.applyNetSettings();
        Toast.success(libL10n.success);
      }

      await context.showRoundDialog(
        title: title,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: title,
          hint: hint,
          icon: icon,
          maxLines: 2,
          suggestion: false,
          onSubmitted: (_) => save(),
        ),
        actions: Btn.ok(onTap: save).toList,
      );
    });
  }
}

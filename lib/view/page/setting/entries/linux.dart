part of '../entry.dart';

/// The Linux systems on this device: which ones there are, and where they get
/// their bytes.
///
/// Named for Linux and not for a distribution, because more than one can be
/// installed and they need not be of the same one. Two Alpines side by side are
/// two profiles, which is why the directory under the container is a generated
/// id and the distribution is a field of the marker inside it.
///
/// Selecting is not switching: nothing is deleted, and a session already
/// running stays where it is. One kernel holds them all — which is also the
/// limit of the isolation, since it means one PID space and one network.
///
/// The rest is what a network or a preference can make wrong and nothing in the
/// app can work around: the default mirror is not reachable everywhere, and
/// neither are the public resolvers seeded into the guest — which an app cannot
/// replace with the system's, since it can read those on neither platform.
///
/// The mirror and the resolver are seeded into the guest's files at install, so
/// saving either rewrites them in the system already on disk. Otherwise the
/// setting would only take effect on the next install, which on iOS means
/// deleting everything the package manager ever put there.
extension _Linux on _AppSettingsPageState {
  Widget _buildLinux() {
    // Which profile is selected decides what the rows below are *about* — the
    // mirror is per distribution and each dialog's header names it — so they
    // redraw together with the list.
    return ValBuilder(
      listenable: _setting.linuxProfile.listenable(),
      builder: (_) => Column(
        children: [
          _buildLinuxBeta(),
          _buildLinuxProfiles(),
          _buildLinuxShell(),
          _buildLinuxMirror(),
          _buildLinuxDns(),
        ].nonNulls.map((e) => CardX(child: e)).toList(),
      ),
    );
  }

  /// That this is beta, at the top of the page that manages it.
  ///
  /// A row of its own rather than a suffix on the title. The settings list that
  /// reached here already says "Linux (Beta)", and what a suffix cannot say is
  /// the part that matters — that nothing here is guaranteed to work.
  ///
  /// Stays after the warning before an install has been dismissed: that one is
  /// asked once and can be turned off, and this page would then be the only
  /// place left that says it.
  Widget _buildLinuxBeta() {
    return ListTile(
      leading: const Icon(Icons.science_outlined, size: _kIconSize),
      title: const Text('Beta'),
      subtitle: Text(l10n.betaTip, style: UIs.textGrey),
    );
  }

  /// Every system installed, and a row to add another.
  ///
  /// The list is the container's own subdirectories — see `IosRootfs.scan` —
  /// so a profile deleted from disk cannot linger here, and this cannot promise
  /// a tree that is not there.
  Widget _buildLinuxProfiles() {
    final profiles = Rootfs.profiles;
    final selected = Rootfs.selected;
    return Column(
      children: [
        for (final profile in profiles)
          ListTile(
            leading: Icon(
              profile.id == selected?.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: _kIconSize,
            ),
            title: Text(profile.label),
            // What it is, under what it is called: the label is the user's and
            // says nothing about which distribution or which release.
            subtitle: Text(
              '${profile.distro.label} ${profile.version}',
              style: UIs.textGrey,
            ),
            // The actions themselves, not a menu holding them. Two of them,
            // so a menu was a tap that only ever revealed the same two —
            // and the row keeps no hidden long-press now that both are here.
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (Rootfs.isOutdated(profile))
                  IconButton(
                    icon: const Icon(Icons.update),
                    tooltip: libL10n.update,
                    onPressed: () async {
                      await installRootfs(context, into: profile);
                      refresh();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: libL10n.rename,
                  onPressed: () async {
                    await _renameProfile(profile);
                    refresh();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: libL10n.delete,
                  // The one coloured thing on this page, and it means what it
                  // says: this deletes the system and everything installed in
                  // it. The confirmation is the guard; this is the warning
                  // before the tap.
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () async {
                    await removeRootfs(context, profile: profile);
                    refresh();
                  },
                ),
              ],
            ),
            onTap: () => _selectProfile(profile),
          ),
        ListTile(
          leading: const Icon(Icons.add, size: _kIconSize),
          title: Text(profiles.isEmpty ? libL10n.install : libL10n.add),
          // What a tap gets you, not a stored preference. With one
          // distribution that is the whole answer; with more it is a choice,
          // and the chevron is what says so.
          subtitle: LinuxDistro.values.length == 1
              ? Text(
                  '${LinuxDistro.values.single.label} '
                  '${LinuxDistro.values.single.version}',
                  style: UIs.textGrey,
                )
              : null,
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: _addProfile,
        ),
      ],
    );
  }

  void _selectProfile(LinuxProfile profile) {
    // Only which one a *new* terminal opens in. Sessions already running stay
    // where they are — the machine holds them all at once.
    _setting.linuxProfile.put(profile.id);
    refresh();
  }

  Future<void> _renameProfile(LinuxProfile profile) async {
    // Owns its controller for the reason [_askProfileName] does: awaiting
    // `withTextFieldController` returns before the dialog is answered.
    final ctrl = TextEditingController(text: profile.label);
    try {
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.rename,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: libL10n.name,
          icon: Icons.label_outline,
          suggestion: false,
          onSubmitted: (_) => context.popDialog(true),
        ),
        actions: Btnx.cancelOk,
      );
      if (ok != true) return;
      final label = ctrl.text.trim();
      // An empty name would leave the row with nothing to show; the old one is
      // a better answer than a blank.
      if (label.isEmpty || label == profile.label) return;
      await Rootfs.rename(profile, label);
    } finally {
      _disposeAfterExit(ctrl);
    }
  }

  /// Adds another system, of whichever distribution.
  ///
  /// Nothing is replaced: this is what "two Alpines side by side" is, and why
  /// the id under the container is generated rather than the distribution's.
  ///
  /// It does not ask when there is only one distribution. A dialog whose only
  /// answer is the one you came for teaches nothing, and the install
  /// confirmation after it already names the release and the download. It was
  /// worse than nothing before: the picker it used marks a current value and
  /// toggles it, so the one tap available deselected the only item and the
  /// dialog closed having chosen nothing.
  Future<void> _addProfile() async {
    final distro = LinuxDistro.values.length == 1
        ? LinuxDistro.values.single
        : await _pickDistro();
    if (distro == null || !mounted) return;

    // Two of one distribution would both be called "Alpine", and this list is
    // the only thing that tells them apart. Asked only when that is true: the
    // first of a distribution has a name nobody has to invent.
    String? label;
    final existing = Rootfs.profiles.where((e) => e.distro == distro).length;
    if (existing > 0) {
      label = await _askProfileName('${distro.label} ${existing + 1}');
      if (label == null || !mounted) return;
    }

    _setting.linuxDistro.put(distro.id);
    // Another, beside whatever is there — not "one if there is none".
    await installRootfs(context, another: true, label: label);
    refresh();
  }

  /// Names the system about to be installed. Null when the dialog was
  /// dismissed, which stops the install — a name asked for and not given is a
  /// change of mind, not a blank.
  ///
  /// [suggestion] is pre-filled and is what an empty field means, so accepting
  /// is one tap and nobody has to think of anything.
  Future<String?> _askProfileName(String suggestion) async {
    // Not `withTextFieldController`: it returns `void`, so awaiting it (even
    // wrapped in `Future.sync`) completes before the dialog is answered. This
    // needs the answer, so it owns the controller and disposes it after.
    final ctrl = TextEditingController(text: suggestion);
    try {
      // The buttons answer. `Btnx.cancelOk` pops a value of its own, so an
      // `onTap` that also popped would have to know which navigator the dialog
      // is on — the trap this project keeps walking into.
      final ok = await context.showRoundDialog<bool>(
        title: libL10n.name,
        child: Input(
          controller: ctrl,
          autoFocus: true,
          label: libL10n.name,
          icon: Icons.label_outline,
          suggestion: false,
          onSubmitted: (_) => context.popDialog(true),
        ),
        actions: Btnx.cancelOk,
      );
      if (ok != true) return null;
      final typed = ctrl.text.trim();
      return typed.isEmpty ? suggestion : typed;
    } finally {
      // Not disposed here. `showRoundDialog` completes when the route is
      // popped, and the field is still mounted and animating for a beat after
      // that — disposing now leaves a live `TextField` holding a dead
      // controller, which the framework reports as "tried to build dirty
      // widget in the wrong build scope" from the input decorator. This is
      // what `withTextFieldController`'s delay before disposing is for; that
      // helper cannot be used here because it returns `void`, so awaiting it
      // gives back nothing and does so before the dialog is answered.
      _disposeAfterExit(ctrl);
    }
  }

  /// Frees a dialog's controller once its route has finished leaving.
  ///
  /// A second is far longer than any dialog transition and costs a controller
  /// held that much longer; the alternative is delaying the caller, and what
  /// follows this is a download.
  void _disposeAfterExit(TextEditingController ctrl) {
    Future.delayed(const Duration(seconds: 1), ctrl.dispose);
  }

  /// Which distribution to install, as a list of actions.
  ///
  /// Each row *is* the install: tapping one starts it. Not a selection to be
  /// confirmed afterwards — nothing here is current, so there is no value to
  /// change, and marking one would say otherwise.
  Future<LinuxDistro?> _pickDistro() {
    return context.showRoundDialog<LinuxDistro>(
      title: l10n.distro,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final distro in LinuxDistro.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(distro.label),
              subtitle: Text(distro.version, style: UIs.textGrey),
              onTap: () => context.popDialog(distro),
            ),
        ],
      ),
    );
  }

  /// The selected system's shell, which is a file inside it rather than a
  /// setting — the same file `chsh` writes. Absent when nothing is installed:
  /// there is no tree to hold it.
  Widget? _buildLinuxShell() {
    final root = Rootfs.root;
    if (root == null) return null;
    return ListTile(
      leading: const Icon(Icons.terminal_outlined, size: _kIconSize),
      title: TipText(libL10n.terminal, l10n.linuxShellTip),
      subtitle: Text(linuxShell(root), style: UIs.textGrey),
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
    final root = Rootfs.root;
    if (root == null) return;
    withTextFieldController((ctrl) async {
      ctrl.text = linuxShell(root);

      Future<void> save() async {
        final typed = ctrl.text.trim();
        context.popDialog();
        // Empty is how the default is asked for, here as in the rows below.
        final chosen = typed.isEmpty ? Defaults.linuxShell : typed;
        if (!isShellPathValid(chosen) || !await shellExistsIn(root, chosen)) {
          if (!mounted) return;
          await context.showRoundDialog(
            title: libL10n.fail,
            child: Text('${libL10n.invalid}: $chosen'),
          );
          return;
        }
        // The same file `chsh` writes, in the guest rather than in the app.
        await setLinuxShell(root, chosen);
        refresh();
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
    final distro = Rootfs.selected?.distro ?? Rootfs.nextDistro;
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

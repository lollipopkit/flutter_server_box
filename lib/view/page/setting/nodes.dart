part of 'entry.dart';

/// The menu, built here because every title comes from the l10n of the
/// moment. A group with settings of its own carries them in a leaf under
/// itself, so that opening a branch and showing a page stay separate.
List<SettingsNode> _buildNodes() {
  return [
    // Grouped by what a setting belongs to, using the same names the app's
    // own tabs do — so "is SFTP under connections or under files" is not a
    // question anyone has to answer. Two levels throughout: a third made
    // reaching a page two taps of guessing.
    SettingsNode.branch(
      id: 'app',
      title: libL10n.app,
      icon: Icons.tune,
      children: [
        SettingsNode.leaf(
          id: 'app.setting',
          title: libL10n.general,
          icon: Icons.settings_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.app),
        ),
        SettingsNode.leaf(
          id: 'app.theme',
          title: libL10n.theme,
          icon: Icons.style_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.theme),
        ),
        SettingsNode.leaf(
          id: 'app.font',
          title: libL10n.font,
          icon: Icons.font_download_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.font),
        ),
        SettingsNode.leaf(
          id: 'app.privacy',
          title: l10n.privacy,
          icon: Icons.privacy_tip_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.privacy),
        ),
        SettingsNode.leaf(
          id: 'app.ai',
          title: libL10n.ai,
          icon: Icons.auto_awesome_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.ai),
        ),
        // A tab of its own rather than a row leading out of the general
        // page: pushed from there it drew a second title bar under the one
        // this page already has, naming the same thing twice.
        SettingsNode.leaf(
          id: 'app.homeTabs',
          title: l10n.homeTabs,
          icon: Icons.tab_outlined,
          page: () => const HomeTabsConfigPage(embedded: true),
        ),
        if (isIOS)
          SettingsNode.leaf(
            id: 'app.ios',
            title: 'iOS',
            icon: MingCute.apple_fill,
            page: () => const IosSettingsPage(embedded: true),
          ),
        // Named after the desktop it is running on, like the iOS page above:
        // what is in there is about the platform rather than about the app.
        if (isDesktop)
          SettingsNode.leaf(
            id: 'app.desktop',
            title: DesktopSettingsPage.platformName,
            icon: DesktopSettingsPage.platformIcon,
            page: () => const DesktopSettingsPage(embedded: true),
          ),

        // Fullscreen mode lets a mobile device serve as a dedicated status
        // display.
        if (isMobile)
          SettingsNode.leaf(
            id: 'app.fullScreen',
            title: l10n.fullScreen,
            icon: Icons.fullscreen,
            page: () =>
                const AppSettingsPage(section: SettingsSection.fullScreen),
          ),
      ],
    ),
    SettingsNode.branch(
      id: 'server',
      title: libL10n.server,
      icon: Icons.dns_outlined,
      children: [
        SettingsNode.leaf(
          id: 'server.setting',
          title: libL10n.general,
          icon: Icons.settings_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.server),
        ),
        // One row for all three orderings. Apart they read alike — the row
        // could not say which list it opened — and side by side as tabs each
        // is named by what the other two are not.
        SettingsNode.leaf(
          id: 'server.order',
          title: libL10n.sequence,
          icon: Icons.sort,
          page: () => const ServerOrdersPage(embedded: true),
        ),
      ],
    ),
    SettingsNode.branch(
      id: 'terminal',
      title: libL10n.terminal,
      icon: Icons.terminal,
      children: [
        SettingsNode.leaf(
          id: 'terminal.setting',
          title: libL10n.general,
          icon: Icons.settings_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.ssh),
        ),
        // Under the terminal because that is where a Linux system is
        // reached from, and absent when this build carries none — the same
        // question the terminal's own tab asks before it offers to install
        // one. Named for Linux rather than for the distribution: which one
        // is installed is allowed to change, and none of what is on that
        // page is about which.
        if (Rootfs.isAvailable)
          SettingsNode.leaf(
            id: 'terminal.linux',
            // Not localized, and not searched for either: the id above is
            // what the settings search matches on, and "Linux" is the same
            // word in every locale this ships in.
            title: 'Linux (Beta)',
            icon: Icons.layers_outlined,
            page: () => const AppSettingsPage(section: SettingsSection.linux),
          ),
        SettingsNode.leaf(
          id: 'terminal.knownHosts',
          title: l10n.sshKnownHostKeys,
          icon: Icons.verified_user_outlined,
          page: () => const KnownHostsPage(embedded: true),
        ),
        SettingsNode.leaf(
          id: 'terminal.virtKey',
          title: l10n.editVirtKeys,
          icon: Icons.keyboard_outlined,
          page: () => const SSHVirtKeySettingPage(embedded: true),
        ),
      ],
    ),
    SettingsNode.branch(
      id: 'file',
      title: libL10n.file,
      icon: Icons.folder_outlined,
      children: [
        SettingsNode.leaf(
          id: 'file.sftp',
          title: 'SFTP',
          icon: Icons.cloud_outlined,
          page: () => const AppSettingsPage(section: SettingsSection.sftp),
        ),
        // Under files rather than under the app: it is what opens one.
        SettingsNode.leaf(
          id: 'file.editor',
          title: libL10n.editor,
          icon: Icons.edit_note,
          page: () => const AppSettingsPage(section: SettingsSection.editor),
        ),
      ],
    ),
    SettingsNode.leaf(
      id: 'container',
      title: libL10n.container,
      icon: Icons.inbox_outlined,
      page: () => const AppSettingsPage(section: SettingsSection.container),
    ),
    SettingsNode.branch(
      id: 'backup',
      title: libL10n.backup,
      icon: Icons.backup_outlined,
      children: [
        SettingsNode.leaf(
          id: 'backup.sync',
          title: libL10n.sync,
          icon: Icons.cloud_sync_outlined,
          page: () => const BackupPage(section: BackupSection.sync),
        ),
        SettingsNode.leaf(
          id: 'backup.import',
          title: libL10n.import,
          icon: Icons.file_download_outlined,
          page: () => const BackupPage(section: BackupSection.import),
        ),
      ],
    ),
    SettingsNode.leaf(
      id: 'privateKey',
      title: l10n.privateKey,
      icon: Icons.key_outlined,
      page: () => const PrivateKeysListPage(),
    ),
    SettingsNode.leaf(
      id: 'bmcCredential',
      title: l10n.bmcAccounts,
      icon: Icons.developer_board,
      page: () => const BmcCredentialsListPage(),
    ),
    SettingsNode.leaf(
      id: 'about',
      title: libL10n.about,
      icon: Icons.info_outline,
      page: () => const _AppAboutPage(),
    ),
  ];
}

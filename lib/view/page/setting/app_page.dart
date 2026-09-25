part of 'entry.dart';

/// Which group of settings [AppSettingsPage] is showing.
///
/// One page rather than one per group, so that the state — and the four text
/// controllers on it — survives moving between them.
enum SettingsSection {
  app,
  /// What the app looks like: the theme in all of its parts, and the font.
  appearance,
  privacy,
  ai,
  server,
  ssh,
  linux,
  sftp,
  container,
  /// The remote desktop tab's sessions and a guest's consoles: what they
  /// have in common, which is how long one stays open once it is left.
  remoteDesktop,
  editor,
  fullScreen;

  /// What this group is called when it is a page of its own.
  ///
  /// The *subject's* name rather than the leaf's. Inside the settings the menu
  /// beside a group already says which subject you are in, so three of those
  /// leaves are called "General" — which on a page with nothing beside it names
  /// nothing at all.
  String get title => switch (this) {
    SettingsSection.app => libL10n.app,
    SettingsSection.appearance => l10n.appearanceSettings,
    SettingsSection.privacy => l10n.privacy,
    SettingsSection.ai => libL10n.ai,
    SettingsSection.server => libL10n.server,
    SettingsSection.ssh => libL10n.terminal,
    // Not localized: the id is what the settings search matches on, and Linux
    // is the same word in every locale this ships in.
    SettingsSection.linux => 'Linux (Beta)',
    SettingsSection.sftp => 'SFTP',
    SettingsSection.container => libL10n.container,
    SettingsSection.remoteDesktop => l10n.remoteDesktop,
    SettingsSection.editor => libL10n.editor,
    SettingsSection.fullScreen => l10n.fullScreen,
  };

  /// The page this group is, inside the subject it is under.
  ///
  /// What the search puts over a row it found: three of these pages are called
  /// "General", and the subject is the half that tells them apart.
  String get breadcrumb => switch (this) {
    SettingsSection.app => '${libL10n.app} › ${libL10n.general}',
    SettingsSection.appearance => '${libL10n.app} › ${l10n.appearanceSettings}',
    SettingsSection.privacy => '${libL10n.app} › ${l10n.privacy}',
    SettingsSection.ai => '${libL10n.app} › ${libL10n.ai}',
    SettingsSection.fullScreen => '${libL10n.app} › ${l10n.fullScreen}',
    SettingsSection.server => '${libL10n.server} › ${libL10n.general}',
    SettingsSection.ssh => '${libL10n.terminal} › ${libL10n.general}',
    SettingsSection.linux => '${libL10n.terminal} › Linux (Beta)',
    SettingsSection.sftp => '${libL10n.file} › SFTP',
    SettingsSection.editor => '${libL10n.file} › ${libL10n.editor}',
    SettingsSection.container => libL10n.container,
    SettingsSection.remoteDesktop => l10n.remoteDesktop,
  };

  /// Whether this build has this group at all.
  ///
  /// The search walks every one of them, and a group the menu never offers is
  /// one whose rows cannot be reached from a result either.
  bool get available => switch (this) {
    SettingsSection.fullScreen => isMobile,
    SettingsSection.linux => Rootfs.isAvailable,
    _ => true,
  };
}

/// One settings group as a page of its own.
///
/// For the places outside the settings tree that lead into it — the terminal
/// tab's "add a Linux system" is the one there is.
///
/// A wrapper rather than an `embedded` flag on [AppSettingsPage], which is what
/// the three sibling pages in the menu use: that page is a group's rows and
/// nothing else, on nine call sites, because the settings' own layout supplies
/// the bar, the title and the surface. Pushed as a route it was a `ListView` on
/// an empty one — a black screen with settings on it.
final class SettingsSectionPage extends StatelessWidget {
  const SettingsSectionPage({super.key, required this.args});

  final SettingsSection args;

  /// A route rather than a `Navigator.push` written at the call site, and the
  /// difference is not bookkeeping: `AppRoute` decides *which* navigator the
  /// page lands on and puts the desktop window frame round it when that is the
  /// root one. On the nearest navigator — what a bare push finds — a page
  /// opened from a tab lands inside that tab, so the settings replaced the
  /// terminal's contents with the navigation still under them, and from the
  /// side bar beside the terminals they opened in that narrow column. A caller
  /// that means the whole window says [NavTarget.root].
  static const route = AppRouteArg<void, SettingsSection>(
    page: SettingsSectionPage.new,
    path: '/settings/section',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(args.title)),
      body: AppSettingsPage(section: args),
    );
  }
}

/// What the page shows instead of its own group while a search is on.
///
/// The search is rendered here and not beside the menu, because what it looks
/// through is the rows this page builds — and those are built from a state
/// with five text controllers on it, which nothing outside can construct.
final class SettingsSearch {
  const SettingsSearch({
    required this.query,
    required this.pages,
    required this.onPage,
  });

  final String query;

  /// Pages whose own names match, found by the menu rather than here.
  final List<SettingsHit> pages;

  final void Function(SettingsHit hit) onPage;
}

final class AppSettingsPage extends ConsumerStatefulWidget {
  final SettingsSection section;

  /// When set, every section's matching rows instead of this one's own.
  final SettingsSearch? search;

  const AppSettingsPage({super.key, required this.section, this.search});

  /// No route of its own — see [SettingsSectionPage], which is what a caller
  /// outside the settings tree pushes. This builds a group's rows and nothing
  /// else: no bar, no background, no scaffold.

  @override
  ConsumerState<AppSettingsPage> createState() => _AppSettingsPageState();
}

final class _AppSettingsPageState extends ConsumerState<AppSettingsPage> {
  final _setting = Stores.setting;

  /// The kept crash report, read once in [initState]. Null again after it is
  /// dropped, which is what makes its group disappear.
  String? _savedCrashReport;

  /// Whether this device can ask for a fingerprint or a face. Null until the
  /// platform has answered, which is not a row and not a group.
  bool? _bioAuthAvail;

  late final _sshOpacityCtrl = TextEditingController(
    text: _setting.sshBgOpacity.fetch().toString(),
  );
  late final _sshBlurCtrl = TextEditingController(
    text: _setting.sshBlurRadius.fetch().toString(),
  );
  late final _textScalerCtrl = TextEditingController(
    // `.fetch()`, as the three above: without it the field opened showing
    // `Instance of 'SqlitePropDefault<double>'` and handed that to be parsed.
    text: _setting.textFactor.fetch().toString(),
  );
  late final _serverLogoCtrl = TextEditingController(
    text: _setting.serverLogoUrl.fetch(),
  );
  late final _serverMarkCtrl = TextEditingController(
    text: _setting.serverMarkUrl.fetch(),
  );

  @override
  void initState() {
    super.initState();
    // Which releases are installable is fetched rather than compiled in, and
    // this page is where someone is about to act on the answer: the version
    // beside "add", the update button on a profile. Launch already tries once;
    // this catches the case where it failed or the release moved since.
    //
    // Not awaited and not shown. What is in force already works, and a refresh
    // that changes nothing — the ordinary case — should look like nothing.
    if (widget.section == SettingsSection.linux && Rootfs.isAvailable) {
      RootfsManifestSource.refresh().then((changed) {
        if (changed && mounted) setState(() {});
      });
    }

    // Both of these decide whether a whole group exists, so they are answered
    // once here rather than by a builder inside a row: a row that arrived a
    // frame later left a heading and a hairline with nothing under them.
    unawaited(
      CrashReport.saved().then((report) {
        if (!mounted || report == null) return;
        setState(() => _savedCrashReport = report);
      }),
    );
    unawaited(
      PlatformPublicSettings.bioAuthAvailable.then((avail) {
        if (!mounted || !avail) return;
        setState(() => _bioAuthAvail = true);
      }),
    );
  }

  @override
  void dispose() {
    _sshOpacityCtrl.dispose();
    _sshBlurCtrl.dispose();
    _textScalerCtrl.dispose();
    _serverLogoCtrl.dispose();
    _serverMarkCtrl.dispose();
    super.dispose();
  }

  /// What a group of settings is made of, named and in order.
  ///
  /// A function of the section rather than a field, because the search walks
  /// every one of them — see [_buildSearch].
  List<SettingsGroup> _groupsOf(SettingsSection section) => switch (section) {
    SettingsSection.app => _buildApp(),
    SettingsSection.appearance => _buildAppearance(),
    SettingsSection.privacy => _buildPrivacy(),
    SettingsSection.ai => _buildAskAiConfig(),
    SettingsSection.server => _buildServer(),
    SettingsSection.ssh => _buildSSH(),
    SettingsSection.linux => _buildLinux(),
    SettingsSection.sftp => _buildSFTP(),
    SettingsSection.container => _buildContainer(),
    SettingsSection.remoteDesktop => _buildRemoteDesktop(),
    SettingsSection.editor => _buildEditor(),
    SettingsSection.fullScreen => _buildFullScreen(),
  };

  /// Every row of every group there is, that [query] names.
  ///
  /// The rows themselves, drawn as they are drawn on their own page — so a
  /// switch found by searching is a switch, and flipping it here is flipping
  /// it. Each section's matches carry its own heading, which is where the row
  /// lives; a breadcrumb repeated on every row would say it once per line.
  List<SettingsGroup> _matchingGroups(String query) {
    final needle = query.toLowerCase();
    final groups = <SettingsGroup>[];
    for (final section in SettingsSection.values) {
      if (!section.available) continue;
      final rows = [
        for (final group in _groupsOf(section))
          ...group.rows.where((row) => row.matches(needle)),
      ];
      if (rows.isNotEmpty) groups.add(SettingsGroup(section.breadcrumb, rows));
    }
    return groups;
  }

  Widget _buildSearch(SettingsSearch search) {
    final groups = _matchingGroups(search.query);
    final pages = search.pages;
    final total = groups.fold<int>(pages.length, (n, g) => n + g.rows.length);

    // The pages themselves, under the settings on them: somebody typing
    // "sequence" means the page, and somebody typing "font" means a row.
    final pageGroup = pages.isEmpty
        ? null
        : SettingsGroup(libL10n.setting, [
            for (final hit in pages)
              SettingsRow(
                hit.leaf.title,
                () => ListTile(
                  leading: ThemedIcon(hit.leaf.icon),
                  title: Text(hit.leaf.title),
                  subtitle: hit.parent == null
                      ? null
                      : Text(hit.parent!.title, style: UIs.text11Grey),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                  onTap: () => search.onPage(hit),
                ),
              ),
          ]);

    return Column(
      key: settingsResultsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GroupTitle(
          '$total ${libL10n.result}',
          padding: const EdgeInsets.fromLTRB(3, 0, 3, 7),
        ),
        // A keystroke rewrites this whole list, and which of it changed is
        // the one thing that cannot be read off the result. So a section that
        // stops matching shrinks away and one that starts matching grows in,
        // and the rest of the column flows around it.
        AnimatedColumn(
          children: [
            for (final group in [...groups, ?pageGroup])
              Padding(
                key: ValueKey('group:${group.title}'),
                padding: const EdgeInsets.only(bottom: 13),
                child: SettingsGroupView(group, animated: true),
              ),
            // An entry like any other, so that it grows in as the last group
            // shrinks out. Returned early instead, it replaced the column —
            // state and all — and the groups it was replacing had nothing
            // left to leave from.
            if (total == 0)
              Padding(
                key: const ValueKey('empty'),
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Center(child: Text(libL10n.empty, style: UIs.textGrey)),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.search case final search?) return _buildSearch(search);

    // The grid rather than one tall column. A settings row is a label at one
    // end and a control at the other, and on a desktop window a single column
    // of them put the two a hand's width apart and made the page a screen and
    // a half of scrolling. [PageColumns] is what the rest of the app's forms
    // are laid out in, at a width chosen for exactly this kind of row.
    //
    // No heading over the grid itself: the menu says which group this is, and
    // the header above the content repeats it. The headings inside are the
    // groups' own.
    Widget grid() => PageColumns(
      padding: _kGridPadding,
      spacing: _kGridSpacing,
      bottomInset: MediaQuery.paddingOf(context).bottom,
      children: [
        // A group can come out empty — every row in it is behind a platform
        // test — and an empty one is a heading with a rule and nothing under.
        for (final group in _groupsOf(widget.section))
          if (group.rows.isNotEmpty) SettingsGroupView(group),
      ],
    );

    // See [_Linux._buildLinux]: its rows are about whichever profile is
    // selected, and nothing else here notifies when that changes.
    if (widget.section != SettingsSection.linux) return grid();
    return ValBuilder(
      listenable: _setting.linuxProfile.listenable(),
      builder: (_) => grid(),
    );
  }

  /// Redraws after something a listenable does not cover.
  ///
  /// The Linux page reads `Rootfs.profiles`, which is built by scanning a
  /// directory rather than from a store key, so nothing notifies when an
  /// install or a removal changes it.
  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> showTextSettingDialog({
    required String title,
    required String initialValue,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onSave,
    bool suggestion = false,
  }) {
    return Future<void>.sync(
      () => withTextFieldController((ctrl) async {
        ctrl.text = initialValue;

        void save() {
          onSave(ctrl.text.trim());
          context.popDialog();
        }

        await context.showRoundDialog<bool>(
          title: title,
          child: Input(
            controller: ctrl,
            autoFocus: true,
            label: label,
            hint: hint,
            icon: icon,
            suggestion: suggestion,
            onSubmitted: (_) => save(),
          ),
          actions: Btn.ok(onTap: save).toList,
        );
      }),
    );
  }
}

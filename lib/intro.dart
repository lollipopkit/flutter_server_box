part of 'app.dart';

/// One step of the intro, and the question of whether it applies.
///
/// The predicate travels with the page, so a step's condition sits next to
/// the step it belongs to.
typedef _IntroStep = ({Future<bool> Function() applies, IntroPageBuilder build});

final class _IntroPage extends StatelessWidget {
  const _IntroPage(this.pages);

  final List<IntroPageBuilder> pages;

  static final _setting = Stores.setting;

  static const _kColumnPad = 17.0;
  static const _kHeadPad = EdgeInsets.symmetric(horizontal: 13);
  static const _kStatusIntervals = [2, 3, 5, 10];

  /// Every step there is, in the order they are shown.
  static Future<List<_IntroStep>> get _steps async => [
    (
      applies: _isFirstLaunch,
      // Asked before the page is built: the Security group has to know
      // whether its row exists.
      build: await PlatformPublicSettings.bioAuthAvailable.then(
        (bio) =>
            (BuildContext ctx, double padTop) =>
                _buildAppSettings(ctx, padTop, bio: bio),
      ),
    ),
    (applies: _needsDiagnosticsConsent, build: _buildDiagnostics),
    (applies: _offersDiscovery, build: _buildDiscovery),
  ];

  /// The steps this launch should show.
  static Future<List<IntroPageBuilder>> get builders async {
    final builders = <IntroPageBuilder>[];
    for (final step in await _steps) {
      if (await step.applies()) builders.add(step.build);
    }
    return builders;
  }

  // — When a step applies ————————————————————————————————————————————

  /// Nothing has ever completed the intro on this install.
  static Future<bool> _isFirstLaunch() async => _setting.introVer.fetch() == 0;

  /// The user has not seen the current diagnostics arrangement.
  ///
  /// Its own counter rather than [SettingStore.introVer], which [_onDone] sets
  /// to the build number; keyed on the arrangement, so a change to what is
  /// collected asks again. Not asked in a build that cannot upload (an empty
  /// `SENTRY_DSN`), where every level behaves the same.
  static Future<bool> _needsDiagnosticsConsent() async {
    if (!DiagnosticsUpload.availableInBuild) return false;
    return _setting.diagnosticsConsentVer.fetch() < kDiagnosticsConsentVer;
  }

  /// A first launch, on a build with something to discover.
  static Future<bool> _offersDiscovery() async =>
      await _isFirstLaunch() &&
      (LocalServer.isSupported || SshDiscovery.available.isNotEmpty);

  // — Widget build ——————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = (cons.maxHeight * .1).clamp(26.0, 77.0);
        return IntroPage(
          key: ValueKey(Localizations.localeOf(context)),
          args: IntroPageArgs(
            pages: pages.map((e) => e(context, padTop)).toList(),
            maxWidth: PageColumns.columnWidth,
            onDone: _onDone,
          ),
        );
      },
    );
  }

  static void _onDone(BuildContext ctx) {
    SqliteStore.transact(() {
      _setting.introVer.putSync(BuildData.build);
      final lastVer = _setting.lastVer;
      if (lastVer.fetch() == 0) lastVer.putSync(BuildData.build);
      // Written here rather than on the page itself, so that leaving the intro
      // without reaching the end counts as unanswered and asks again. Only in
      // a build that shows the page.
      if (DiagnosticsUpload.availableInBuild) {
        _setting.diagnosticsConsentVer.putSync(kDiagnosticsConsentVer);
      }
    });
    // Nothing has been uploaded before this point: `DiagnosticsUpload.sync`
    // refuses to start until the consent counter above is written.
    unawaited(DiagnosticsUpload.sync());
    Navigator.of(ctx).pushReplacement(
      AppPageRoute(builder: (_) => _buildHomeWithWindowFrame()),
    );
  }

  // — Shared pieces —————————————————————————————————————————————————

  /// The content column, with the scrollbar at the window edge.
  static Widget _introList({required List<Widget> children}) {
    // `IntroPage` is a bare `Scaffold` holding a `PageView`: bounding the
    // viewport keeps a scrolled title from sliding under the status bar.
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (_, cons) {
          final rest = (cons.maxWidth - PageColumns.columnWidth) / 2;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              math.max(rest, _kColumnPad),
              0,
              math.max(rest, _kColumnPad),
              26,
            ),
            children: children,
          );
        },
      ),
    );
  }

  /// A page's title, with a glyph or the app icon above it and a sentence
  /// under it.
  static Widget _head(
    BuildContext ctx,
    double padTop, {
    required String title,
    required String lead,
    IconData? glyph,
    Widget? mark,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    return Padding(
      padding: _kHeadPad.copyWith(top: padTop, bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (glyph != null) Icon(glyph, size: 24, color: scheme.primary),
          ?mark,
          UIs.height13,
          Text(
            title,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 9),
          Text(lead, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  static Widget _note(BuildContext ctx, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _kColumnPad),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  static Widget _group(String title, List<SettingsRow> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: SettingsGroupView(SettingsGroup(title, rows)),
  );

  // — Pages —————————————————————————————————————————————————————————

  static Widget _buildAppSettings(
    BuildContext ctx,
    double padTop, {
    required bool bio,
  }) {
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;
    final privacyBlur = PlatformPublicSettings.privacyBlur;
    final themeLocked = ThemePackages.activeTheme?.lockedMode != null;

    return _introList(
      children: [
        _head(
          ctx,
          padTop,
          title: BuildData.name,
          lead: l10n.introWelcome,
          mark: Image.asset('assets/app_icon.png', width: 64, height: 64),
        ),
        _group(libL10n.general, [
          SettingsRow(
            libL10n.language,
            () => ListTile(
              leading: const Icon(IonIcons.language),
              title: Text(libL10n.language),
              onTap: () => _selectLocale(ctx),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ctx.localeNativeName, style: UIs.text15),
                  const Icon(Icons.chevron_right, size: 17),
                ],
              ),
            ),
          ),
          SettingsRow(
            libL10n.checkUpdate,
            () => ListTile(
              leading: const Icon(Icons.update),
              title: Text(libL10n.checkUpdate),
              subtitle: isAndroid
                  ? Text(l10n.fdroidReleaseTip, style: UIs.textGrey)
                  : null,
              trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
            ),
          ),
        ]),
        _group(libL10n.appearanceSettings, [
          if (!themeLocked)
            SettingsRow(libL10n.themeMode, () => _buildThemeMode(ctx)),
          SettingsRow(l10n.reduceMotion, () => _buildReduceMotion(ctx)),
        ]),
        _group(libL10n.servers, [
          SettingsRow(
            l10n.updateServerStatusInterval,
            () => _buildStatusInterval(ctx),
          ),
        ]),
        if (bio || privacyBlur != null)
          _group(l10n.security, [
            if (bio)
              SettingsRow(libL10n.bioAuth, PlatformPublicSettings.buildBioAuth),
            if (privacyBlur != null)
              SettingsRow(privacyBlur.label, privacyBlur.build),
          ]),
      ],
    );
  }

  static Widget _buildThemeMode(BuildContext ctx) {
    final libL10n = ctx.libL10n;
    final prop = ThemeHost.settings.themeMode;
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(libL10n.themeMode),
      subtitle: _choices(
        prop.listenable().listenVal(
          (mode) => SegmentedTabs<int>(
            selected: mode,
            onSelected: (mode) {
              prop.put(mode);
              unawaited(RNodes.app.notify());
            },
            segments: [
              SegmentedTab(
                value: ThemeMode.system.index,
                label: libL10n.followSystem,
              ),
              SegmentedTab(value: ThemeMode.light.index, label: libL10n.bright),
              SegmentedTab(value: ThemeMode.dark.index, label: libL10n.dark),
            ],
          ),
        ),
      ),
    );
  }

  /// A row's choices on a line of their own under its title: beside it, three
  /// labels in a long language leave the title no room on a phone.
  static Widget _choices(Widget control) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: control,
    ),
  );

  /// Shows what motion is now, whichever preference says so; a change that
  /// agrees with the device goes back to following it.
  static Widget _buildReduceMotion(BuildContext ctx) {
    final prop = _setting.motionPref;
    return ListTile(
      leading: const Icon(Icons.animation),
      title: Text(ctx.l10n.reduceMotion),
      trailing: ListenBuilder(
        listenable: AppMotion.changes,
        builder: () => Switch(
          value: AppMotion.reduces,
          onChanged: (on) => prop.put(
            on == AppMotion.system.value
                ? MotionPref.system
                : on
                ? MotionPref.reduce
                : MotionPref.full,
          ),
        ),
      ),
    );
  }

  static Widget _buildStatusInterval(BuildContext ctx) {
    final l10n = ctx.l10n;
    final prop = _setting.serverStatusUpdateInterval;
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(l10n.updateServerStatusInterval),
      subtitle: _choices(
        prop.listenable().listenVal(
          (val) => SegmentedTabs<int>(
            selected: val,
            onSelected: prop.put,
            segments: [
              // The stored value stays selectable when it is none of these.
              for (final s in {..._kStatusIntervals, val}.toList()..sort())
                SegmentedTab(
                  value: s,
                  label: s == 0 ? ctx.libL10n.manual : '$s${l10n.second}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where diagnostics collection is explained and chosen.
  ///
  /// The level starts at `none`, so going past this page sends nothing; the
  /// choice takes effect in [_onDone].
  static Widget _buildDiagnostics(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;

    return _introList(
      children: [
        _head(
          ctx,
          padTop,
          glyph: Icons.monitor_heart_outlined,
          title: l10n.crashCollect,
          lead: l10n.crashCollectIntro,
        ),
        // Stored only: nothing uploads until the intro is finished.
        const DiagnosticsLevelPicker(),
        UIs.height13,
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(l10n.privacyPolicy),
          trailing: const Icon(Icons.open_in_new, size: 17),
          onTap: Urls.privacyPolicy.launchUrl,
        ).cardx,
        UIs.height13,
        _note(ctx, l10n.crashCollectFooter),
      ],
    );
  }

  /// This device and every [SshDiscovery] this build has, to add as servers.
  static Widget _buildDiscovery(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;
    return SafeArea(
      bottom: false,
      child: SshDiscoveryView.batch(
        columnWidth: PageColumns.columnWidth,
        header: [
          _head(
            ctx,
            padTop,
            glyph: Icons.radar,
            title: l10n.discoverSshServers,
            lead: l10n.discoverIntro,
          ),
        ],
      ),
    );
  }

  // — Actions ———————————————————————————————————————————————————————

  static Future<void> _selectLocale(BuildContext ctx) async {
    final selected = await ctx.showPickSingleDialog(
      title: ctx.libL10n.language,
      items: AppLocalizations.supportedLocales,
      display: (locale) => locale.nativeName,
      initial: _setting.locale.fetch().toLocale,
    );
    if (selected == null || !ctx.mounted) return;

    _setting.locale.put(selected.code);
  }
}

/// The intro this launch would show, or null when none applies.
@visibleForTesting
Future<Widget?> introForTest() async {
  final pages = await _IntroPage.builders;
  return pages.isEmpty ? null : _IntroPage(pages);
}

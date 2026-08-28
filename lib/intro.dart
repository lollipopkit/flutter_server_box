part of 'app.dart';

/// One step of the intro, and the question of whether it applies.
///
/// The predicate travels with the page. It used to be a number keyed into a
/// map, tested in a `where` several methods away — so adding a step meant two
/// edits in two places, and the condition for a step was nowhere near the step
/// it belonged to.
typedef _IntroStep = ({Future<bool> Function() applies, IntroPageBuilder build});

final class _IntroPage extends StatelessWidget {
  const _IntroPage(this.pages);

  final List<IntroPageBuilder> pages;

  static final _setting = Stores.setting;

  static const _kIconSize = 23.0;
  static const _kIntroListPad = 17.0;
  static const _kMaxPadTop = 120.0;

  /// Horizontal room for a paragraph, and the gap above and below it.
  static const _kProsePad = EdgeInsets.symmetric(horizontal: 13, vertical: 8);

  /// Every step there is, in the order they are shown.
  ///
  /// A list rather than a map: the order is the list's, and nothing needs a
  /// number to refer to a step by.
  static List<_IntroStep> get _steps => [
    (applies: _isFirstLaunch, build: _buildAppSettings),
    (applies: _needsBackupPassword, build: _buildBackupPasswordMigration),
    (applies: _needsDiagnosticsConsent, build: _buildDiagnostics),
  ];

  /// The steps this launch should show.
  static Future<List<IntroPageBuilder>> get builders async {
    final builders = <IntroPageBuilder>[];
    for (final step in _steps) {
      if (await step.applies()) builders.add(step.build);
    }
    return builders;
  }

  // — When a step applies ————————————————————————————————————————————

  /// Nothing has ever completed the intro on this install.
  static Future<bool> _isFirstLaunch() async => _setting.introVer.fetch() == 0;

  /// Upgrading from a build that predates the backup password, without one set.
  ///
  /// `lastVer > 0` is what separates an upgrade from a first install: a fresh
  /// one has no data to protect and is offered the password elsewhere.
  static Future<bool> _needsBackupPassword() async {
    if (_setting.lastVer.fetch() == 0) return false;
    if (_setting.introVer.fetch() >= 2) return false;
    return (await SecureStoreProps.bakPwd.read())?.isNotEmpty != true;
  }

  /// The user has not seen the current diagnostics arrangement.
  ///
  /// Its own counter rather than [SettingStore.introVer], which [onDone] sets
  /// to the *build number* — so every step below it is permanently "already
  /// seen" for anyone who has completed an intro, and a newly added one could
  /// never appear. Keyed on the arrangement instead, which is also what lets a
  /// change to what is collected ask again.
  static Future<bool> _needsDiagnosticsConsent() async =>
      _setting.diagnosticsConsentVer.fetch() < kDiagnosticsConsentVer;

  // — Widget build ——————————————————————————————————————————————————

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        // Proportional on phones, capped so a tall desktop window doesn't push
        // the title halfway down the screen — it is used twice per page, above
        // and below the title.
        final padTop = (cons.maxHeight * .16).clamp(0.0, _kMaxPadTop);
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
      // without reaching the end counts as unanswered and asks again.
      _setting.diagnosticsConsentVer.putSync(kDiagnosticsConsentVer);
    });
    // Applies whatever was chosen a moment ago. Nothing has been uploaded
    // before this point — `DiagnosticsUpload.sync` refuses to start until the
    // consent counter above says the question was put.
    unawaited(DiagnosticsUpload.sync());
    Navigator.of(ctx).pushReplacement(
      MaterialPageRoute(builder: (_) => _buildHomeWithWindowFrame()),
    );
  }

  // — Shared pieces —————————————————————————————————————————————————

  /// Keeps the content in the same column the rest of the app reads in, while
  /// the scrollbar stays at the window edge.
  static Widget _introList({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (_, cons) {
        final rest = (cons.maxWidth - PageColumns.columnWidth) / 2;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: math.max(rest, _kIntroListPad),
          ),
          children: children,
        );
      },
    );
  }

  /// A page's title with the breathing room above and below it.
  static List<Widget> _head(String title, double padTop) => [
    SizedBox(height: padTop),
    IntroPage.title(text: title, big: true),
    SizedBox(height: padTop),
  ];

  /// A sentence of explanation, indented to line up with the tiles under it.
  static Widget _prose(String text) =>
      Padding(padding: _kProsePad, child: Text(text, style: UIs.textGrey));

  // — Pages —————————————————————————————————————————————————————————

  static Widget _buildAppSettings(BuildContext ctx, double padTop) {
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;

    return _introList(
      children: [
        ..._head(libL10n.init, padTop),
        ListTile(
          leading: const Icon(IonIcons.language),
          title: Text(libL10n.language),
          onTap: () => _selectLocale(ctx),
          trailing: Text(
            ctx.localeNativeName,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ).cardx,
        ListTile(
          leading: const Icon(Icons.update),
          title: Text(libL10n.checkUpdate),
          subtitle: isAndroid
              ? Text(l10n.fdroidReleaseTip, style: UIs.textGrey)
              : null,
          trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
        ).cardx,
        ListTile(
          leading: const Icon(MingCute.delete_2_fill),
          title: TipText('rm -r', l10n.sftpRmrDirSummary),
          trailing: StoreSwitch(prop: _setting.sftpRmrDir),
        ).cardx,
        ListTile(
          leading: const Icon(MingCute.chart_line_line, size: _kIconSize),
          title: TipText(l10n.dockerStatistics, l10n.parseContainerStatsTip),
          trailing: StoreSwitch(prop: _setting.containerParseStat),
        ).cardx,
        ListTile(
          leading: const Icon(Bootstrap.alphabet),
          title: TipText(l10n.letterCache, l10n.letterCacheTip),
          trailing: StoreSwitch(prop: _setting.letterCache),
        ).cardx,
        UIs.height77,
      ],
    );
  }

  static Widget _buildBackupPasswordMigration(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;

    return _introList(
      children: [
        SizedBox(height: padTop),
        IntroPage.title(text: l10n.backupPassword, big: true),
        SizedBox(height: padTop * 0.5),
        Text(
          l10n.backupTip,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: padTop * 0.5),
        ListTile(
          leading: const Icon(Icons.lock, color: Colors.orange),
          title: Text(l10n.backupPassword),
          subtitle: Text(l10n.backupPasswordTip, style: UIs.textGrey),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () => _askBackupPassword(ctx),
        ).cardx,
        // Nothing further here: the two lines above — `backupTip` under the
        // title and `backupPasswordTip` on the tile — already say what this
        // step is and why. A third sentence restating it was also the one
        // string on this page that was never translated.
        UIs.height77,
      ],
    );
  }

  /// Where diagnostics collection is explained and chosen.
  ///
  /// Shown before anything is uploaded, and that ordering is the point: the
  /// desktop default is `basic`, so without being asked first a user would be
  /// sending before they had been told. [_onDone] is what releases it.
  ///
  /// A radio list rather than a switch, because three levels do not read as
  /// one — and the middle level is the whole reason to offer a choice instead
  /// of an on/off.
  static Widget _buildDiagnostics(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;

    return _introList(
      children: [
        ..._head(l10n.crashCollect, padTop),
        _prose(l10n.crashCollectIntro),
        // Rebuilt on change so the selection is visible at once; the store is
        // the source of truth, not a field on this widget.
        _setting.diagnosticsLevel.listenable().listenVal((name) {
          // `RadioGroup` owns the selection — the per-tile `groupValue` and
          // `onChanged` are deprecated.
          return RadioGroup<DiagnosticsLevel>(
            groupValue: DiagnosticsLevel.fromName(name),
            onChanged: _onLevelPicked,
            child: Column(
              // Reversed, so the recommended answer is read first. The default
              // is the quiet end — `none` on Android, which is the only
              // platform F-Droid distributes — so the case for collecting has
              // to be made here rather than by pre-selecting it.
              children: DiagnosticsLevel.values.reversed
                  .map((e) => _levelTile(ctx, e))
                  .toList(),
            ),
          );
        }),
        _prose(l10n.crashCollectFooter),
        UIs.height77,
      ],
    );
  }

  /// One level, with its own sentence saying what it sends.
  static Widget _levelTile(BuildContext ctx, DiagnosticsLevel level) {
    final (title, tip) = _levelText(ctx.l10n, level);
    return RadioListTile<DiagnosticsLevel>(
      value: level,
      title: level == _kRecommendedLevel
          ? Row(
              children: [
                Flexible(child: Text(title)),
                UIs.width7,
                Text(
                  // The word this app already has. Its key names where it was
                  // first needed, not what it means.
                  ctx.l10n.sshKeyRecommended,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ],
            )
          : Text(title),
      subtitle: Text(tip, style: UIs.textGrey),
    ).cardx;
  }

  /// Which level the page argues for.
  static const _kRecommendedLevel = DiagnosticsLevel.full;

  /// A level's label and the sentence under it.
  ///
  /// One switch rather than two parallel ones: the pair belongs together, and
  /// a case added to the enum should fail to compile here once.
  static (String, String) _levelText(AppLocalizations l10n, DiagnosticsLevel l) {
    return switch (l) {
      DiagnosticsLevel.none => (l10n.crashCollectNone, l10n.crashCollectNoneTip),
      DiagnosticsLevel.basic => (
        l10n.crashCollectBasic,
        l10n.crashCollectBasicTip,
      ),
      DiagnosticsLevel.full => (l10n.crashCollectFull, l10n.crashCollectFullTip),
    };
  }

  // — Actions ———————————————————————————————————————————————————————

  static void _onLevelPicked(DiagnosticsLevel? level) {
    if (level == null) return;
    // Stored only. Nothing starts uploading until the intro is finished, which
    // is what makes leaving it early mean "not answered".
    _setting.diagnosticsLevel.put(level.name);
  }

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

  static Future<void> _askBackupPassword(BuildContext ctx) async {
    final controller = TextEditingController();
    final result = await ctx.showRoundDialog<bool>(
      title: ctx.l10n.backupPassword,
      // Disposed by the tree. It was never disposed at all before, which leaks
      // one controller per visit and — unlike the crash the same shape causes
      // elsewhere — says nothing about it.
      child: DisposeWith(
        notifiers: [controller],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.l10n.backupPasswordTip, style: UIs.textGrey),
            UIs.height13,
            Input(
              label: ctx.l10n.backupPassword,
              controller: controller,
              obscureText: true,
              // `popDialog`, not `pop`: the dialog is on the root navigator
              // and `ctx` is the page's. It happens to be the same one today
              // only because the intro is `MaterialApp.home` — under a pane or
              // a tab this would close the page, leave the dialog up, and
              // never complete the future the password is written from.
              onSubmitted: (_) => ctx.popDialog(true),
            ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    if (result != true) return;

    final pwd = controller.text.trim();
    if (pwd.isEmpty) return;
    await SecureStoreProps.bakPwd.write(pwd);
    Toast.show(ctx.l10n.backupPasswordSet);
  }
}

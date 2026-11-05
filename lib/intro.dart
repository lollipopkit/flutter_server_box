part of 'app.dart';

/// One step of the intro, and the question of whether it applies.
///
/// The predicate travels with the page. It used to be a number keyed into a
/// map, tested in a `where` several methods away — so adding a step meant two
/// edits in two places, and the condition for a step was nowhere near the step
/// it belonged to.
typedef _IntroStep = ({Future<bool> Function() applies, IntroPageBuilder build});

/// The latest revision of the feature pages — see
/// [SettingStore.featureIntroVer]. A page added later names the next number,
/// and this moves to it.
const _kFeatureIntroVer = 2;

/// The feature revision the Virtualization page arrived in.
const _kVirtIntroSince = 2;

/// The intro: a column of pages and a bar under them.
///
/// Its own shell rather than fl_lib's `IntroPage`, so that it is drawn with
/// the app's measurements — the type ladder tops out at 27, cards are grouped
/// rows with hairlines between them, and the bar carries a 3px progress line
/// in place of its top edge.
final class _IntroPage extends StatefulWidget {
  const _IntroPage(this.pages);

  final List<IntroPageBuilder> pages;

  static final _setting = Stores.setting;

  /// A row's leading glyph — the size of a card's connection affordance.
  static const _kIconSize = 21.0;

  /// The glyph over a page's title — the size the nav bar and rail use.
  static const _kGlyphSize = 24.0;

  /// A chevron or an external-link mark at a row's end.
  static const _kTrailSize = 17.0;

  static const _kListPad = 17.0;

  /// Room above a page's head: proportional on phones, bounded so a tall
  /// desktop window does not push the title halfway down.
  static const _kMinPadTop = 26.0;
  static const _kMaxPadTop = 77.0;

  /// The type ladder's largest step, for the one title a page leads with.
  static const _kTitleStyle = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Body, for anything that has to be read.
  static const _kBodyStyle = TextStyle(fontSize: 13, height: 1.5);

  /// A section's label over its card.
  static const _kLabelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);

  /// The bar's height, as the phone's bottom bar.
  static const _kBarHeight = 61.6;

  /// A card changing height, an I/O pair cross-fading: the app's step for a
  /// view that moves under the reader's eye.
  static const _kStepDuration = Duration(milliseconds: 377);

  /// Every step there is, in the order they are shown.
  ///
  /// A list rather than a map: the order is the list's, and nothing needs a
  /// number to refer to a step by.
  static List<_IntroStep> get _steps => [
    (applies: _isFirstLaunch, build: _buildAppSettings),
    (applies: _needsDiagnosticsConsent, build: _buildDiagnostics),
    // After the questions: these only say what the app can do.
    (applies: () async => _featureUnseen(1), build: _buildRemoteDesktop),
    (
      applies: () async => LocalServer.isSupported && _featureUnseen(1),
      build: _buildLocalServer,
    ),
    (applies: _virtUnseen, build: _buildVirt),
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

  /// The user has not seen the current diagnostics arrangement.
  ///
  /// Its own counter rather than [SettingStore.introVer], which [_onDone] sets
  /// to the *build number* — so every step below it is permanently "already
  /// seen" for anyone who has completed an intro, and a newly added one could
  /// never appear. Keyed on the arrangement instead, which is also what lets a
  /// change to what is collected ask again.
  ///
  /// Not asked at all in a build that cannot upload — one made with an empty
  /// `SENTRY_DSN`. Every level then behaves identically, so the page would put
  /// a question whose answer changes nothing, and the settings page already
  /// hides the same control under the same condition.
  static Future<bool> _needsDiagnosticsConsent() async {
    if (!DiagnosticsUpload.availableInBuild) return false;
    return _setting.diagnosticsConsentVer.fetch() < kDiagnosticsConsentVer;
  }

  /// A feature page introduced in revision [since] that this install has not
  /// been shown. Fresh installs included: the pages describe features, not
  /// changes, and a first launch knows neither.
  static bool _featureUnseen(int since) =>
      _setting.featureIntroVer.fetch() < since;

  static Future<bool> _virtUnseen() async => _featureUnseen(_kVirtIntroSince);

  /// What the Virtualization page adds for someone who had PVE configured.
  ///
  /// Read when the page is built, not stored: whether any server has a PVE
  /// row, and whether the tab is in the bar, are both facts about now — a
  /// flag written by the migration would go stale the moment either changed.
  static ({bool pveMoved, bool inBar}) _virtFacts() => (
    pveMoved: Stores.pve.fetchAll().isNotEmpty,
    inBar: _setting.homeTabs.fetch().contains(AppTab.virt),
  );

  @override
  State<_IntroPage> createState() => _IntroPageState();

  static void _onDone(BuildContext ctx) {
    SqliteStore.transact(() {
      _setting.introVer.putSync(BuildData.build);
      final lastVer = _setting.lastVer;
      if (lastVer.fetch() == 0) lastVer.putSync(BuildData.build);
      // Written here rather than on the page itself, so that leaving the intro
      // without reaching the end counts as unanswered and asks again. Only in
      // a build that shows the page: one without a DSN leaves it out, and its
      // having been finished must not be read as an answer by a later build
      // that can upload.
      if (DiagnosticsUpload.availableInBuild) {
        _setting.diagnosticsConsentVer.putSync(kDiagnosticsConsentVer);
      }
      _setting.featureIntroVer.putSync(_kFeatureIntroVer);
    });
    // Applies whatever was chosen a moment ago. Nothing has been uploaded
    // before this point — `DiagnosticsUpload.sync` refuses to start until the
    // consent counter above says the question was put.
    unawaited(DiagnosticsUpload.sync());
    Navigator.of(ctx).pushReplacement(
      AppPageRoute(builder: (_) => _buildHomeWithWindowFrame()),
    );
  }

  // — Shared pieces —————————————————————————————————————————————————

  /// A page: its head, then [children], in the column the rest of the app
  /// reads in, while the scrollbar stays at the window edge.
  static Widget _introList(
    BuildContext ctx, {
    required double padTop,
    required String title,
    IconData? glyph,
    Widget? mark,
    String? lead,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    // A page's viewport starts at the very top of the screen, so a list long
    // enough to scroll would draw its title over the clock and the status
    // icons. Bounding the viewport rather than padding the list is what clips
    // it there.
    //
    // `bottom: false` because the page already ends in the bar, and outside
    // the [LayoutBuilder] so the width the column is centred in is the one
    // left after a landscape cutout.
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (_, cons) {
          final rest = (cons.maxWidth - PageColumns.columnWidth) / 2;
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: math.max(rest, _kListPad),
            ),
            children: [
              SizedBox(height: padTop),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (glyph != null) ...[
                      Icon(glyph, size: _kGlyphSize, color: scheme.primary),
                      UIs.height13,
                    ],
                    // The mark rides the last line of the title: a heading is
                    // one or two lines depending on the width it is given.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(child: Text(title, style: _kTitleStyle)),
                        if (mark != null) ...[
                          const SizedBox(width: 9),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: mark,
                          ),
                        ],
                      ],
                    ),
                    if (lead != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        lead,
                        style: _kBodyStyle.copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 26),
              ...children,
              UIs.height77,
            ],
          );
        },
      ),
    );
  }

  /// Rows that belong together, in one card with hairlines between them,
  /// under an optional [label].
  static Widget _section(
    BuildContext ctx, {
    String? label,
    required List<Widget> rows,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    final hairline = Divider(
      height: 1,
      thickness: 1,
      indent: 17,
      endIndent: 17,
      color: scheme.outlineVariant.withValues(alpha: .35),
    );
    final children = <Widget>[];
    for (final (i, row) in rows.indexed) {
      if (i > 0) children.add(hairline);
      children.add(row);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 5),
              child: Text(
                label,
                style: _kLabelStyle.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          CardX(child: Column(children: children)),
        ],
      ),
    );
  }

  /// A row of a [_section]: a glyph, a name, and the sentence that explains
  /// it — shown, not kept behind a tooltip, since a first launch is when it is
  /// read.
  static Widget _row(
    BuildContext ctx, {
    required IconData icon,
    required Widget title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(ctx).colorScheme;
    return ListTile(
      leading: Icon(icon, size: _kIconSize),
      title: title,
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// A sentence under the cards: what follows from the choices above.
  static Widget _note(BuildContext ctx, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  // — Pages —————————————————————————————————————————————————————————

  /// The first launch: the product's name in plain type, the language, and
  /// the few defaults that change how the app behaves on a server.
  static Widget _buildAppSettings(BuildContext ctx, double padTop) {
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;
    final scheme = Theme.of(ctx).colorScheme;

    return _introList(
      ctx,
      padTop: padTop,
      title: BuildData.name,
      lead: l10n.introWelcome,
      children: [
        _section(
          ctx,
          label: libL10n.general,
          rows: [
            _row(
              ctx,
              icon: IonIcons.language,
              title: Text(libL10n.language),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ctx.localeNativeName,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  UIs.width7,
                  Icon(
                    Icons.chevron_right,
                    size: _kTrailSize,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: () => _selectLocale(ctx),
            ),
            _row(
              ctx,
              icon: Icons.update,
              title: Text(libL10n.checkUpdate),
              subtitle: isAndroid ? l10n.fdroidReleaseTip : null,
              trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
            ),
          ],
        ),
        _section(
          ctx,
          label: l10n.introDefaults,
          rows: [
            _row(
              ctx,
              icon: Bootstrap.alphabet,
              title: Text(l10n.letterCache),
              subtitle: l10n.letterCacheTip,
              trailing: StoreSwitch(prop: _setting.letterCache),
            ),
            _row(
              ctx,
              icon: MingCute.delete_2_line,
              title: const Text(
                'rm -r',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              subtitle: l10n.sftpRmrDirSummary,
              trailing: StoreSwitch(prop: _setting.sftpRmrDir),
            ),
            _row(
              ctx,
              icon: MingCute.chart_line_line,
              title: Text(l10n.dockerStatistics),
              subtitle: l10n.parseContainerStatsTip,
              trailing: StoreSwitch(prop: _setting.containerParseStat),
            ),
          ],
        ),
        _note(ctx, l10n.introSettingsLater),
      ],
    );
  }

  /// Where diagnostics collection is explained and chosen.
  ///
  /// Shown before anything is uploaded. The level starts at `none` on every
  /// platform, so going past this page without picking one sends nothing;
  /// picking one that uploads is the user's choice, and [_onDone] is what
  /// releases it.
  ///
  /// A radio list rather than a switch, so each level carries the sentence
  /// that says what it sends.
  static Widget _buildDiagnostics(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;
    final scheme = Theme.of(ctx).colorScheme;

    return _introList(
      ctx,
      padTop: padTop,
      glyph: Icons.monitor_heart_outlined,
      title: l10n.crashCollect,
      lead: l10n.crashCollectIntro,
      children: [
        // Stored only, so no callback: nothing starts uploading until the
        // intro is finished, which is what makes leaving it early mean "not
        // answered". Settings passes one, because there the change is now.
        const DiagnosticsLevelPicker(),
        const SizedBox(height: 17),
        // On the page where the question is put, not only in Settings
        // afterwards. A tile can say what a level sends; where it goes, how
        // long it is kept and what a report was checked not to contain need
        // somewhere to be written down, and an answer given without that is
        // an answer to the summary.
        _section(
          ctx,
          rows: [
            _row(
              ctx,
              icon: Icons.privacy_tip_outlined,
              title: Text(l10n.privacyPolicy),
              trailing: Icon(
                Icons.open_in_new,
                size: _kTrailSize,
                color: scheme.onSurfaceVariant,
              ),
              onTap: Urls.privacyPolicy.launchUrl,
            ),
          ],
        ),
        _note(ctx, l10n.crashCollectFooter),
      ],
    );
  }

  /// What remote desktop is and how it reaches a machine.
  ///
  /// The two things worth knowing before the first try: that nothing has to
  /// be opened to the network, and where the button is. How the touch
  /// controls work is the viewer's own guide, reused here.
  static Widget _buildRemoteDesktop(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;

    return _introList(
      ctx,
      padTop: padTop,
      glyph: Icons.desktop_windows_outlined,
      title: l10n.remoteDesktop,
      mark: Feature.remoteDesktop.mark(),
      lead: l10n.remoteDesktopIntro,
      children: [
        _section(
          ctx,
          rows: [
            _row(
              ctx,
              icon: Icons.bookmark_border,
              title: const Text('RDP · VNC'),
              subtitle: l10n.remoteDesktopIntroProfiles,
            ),
            _row(
              ctx,
              icon: Icons.touch_app_outlined,
              title: Text(l10n.remoteDesktopGuideTouch),
              subtitle: l10n.remoteDesktopGuideTouchTip,
            ),
            _row(
              ctx,
              icon: Icons.visibility_outlined,
              title: Text(l10n.remoteDesktopViewOnly),
              subtitle: l10n.remoteDesktopGuideViewOnlyTip,
            ),
          ],
        ),
      ],
    );
  }

  /// The device running the app, as a server — see `Spi.local`.
  ///
  /// Offers to add it here, since that is one tap and needs nothing typed.
  /// Only where [LocalServer.isSupported]: a page about a feature this build
  /// cannot use would be an advertisement.
  static Widget _buildLocalServer(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;
    // Not read from the servers here: building a page should not depend on
    // them being loaded. The tap finds out, and one already there counts.
    final added = ValueNotifier(false);

    return DisposeWith(
      notifiers: [added],
      child: _introList(
        ctx,
        padTop: padTop,
        glyph: Icons.computer,
        title: l10n.thisDevice,
        lead: l10n.localServerIntro,
        children: [
          added.listenVal(
            (done) => _section(
              ctx,
              rows: [
                _row(
                  ctx,
                  icon: Icons.dns_outlined,
                  title: Text(Platform.localHostname),
                  trailing: done
                      ? Icon(
                          Icons.check,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : FilledButton.tonal(
                          onPressed: () async {
                            if (await _addLocalServer(ctx)) added.value = true;
                          },
                          child: Text(l10n.localServerAdd),
                        ),
                ),
              ],
            ),
          ),
          _note(ctx, l10n.localServerIntroFooter),
        ],
      ),
    );
  }

  /// The Virtualization tab: libvirt and PVE hosts, over any transport.
  ///
  /// For someone who had PVE configured it also says where the old page went
  /// and where the tab is — the one thing they are otherwise left to find —
  /// and that an API token can replace the password.
  static Widget _buildVirt(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;
    final facts = _virtFacts();

    return _introList(
      ctx,
      padTop: padTop,
      glyph: Icons.view_in_ar_outlined,
      title: l10n.virtualization,
      mark: Feature.virt.mark(),
      lead: l10n.virtIntro,
      children: [
        _section(
          ctx,
          rows: [
            _row(
              ctx,
              icon: Icons.memory,
              title: const Text('libvirt · KVM'),
              subtitle: l10n.virtIntroLibvirt,
            ),
            _row(
              ctx,
              icon: Icons.swap_horiz,
              title: const Text('SSH · Monitor'),
              subtitle: l10n.virtIntroTransports,
            ),
          ],
        ),
        if (facts.pveMoved)
          _section(
            ctx,
            rows: [
              _row(
                ctx,
                icon: FontAwesome.server_solid,
                title: const Text('Proxmox VE'),
                subtitle:
                    '${l10n.virtIntroPveMoved} '
                    '${facts.inBar ? l10n.virtIntroInBar : l10n.virtIntroInMore}',
              ),
              _row(
                ctx,
                icon: Icons.key_outlined,
                title: Text(l10n.pveAuthToken),
                subtitle: l10n.virtIntroTokens,
              ),
            ],
          ),
      ],
    );
  }

  // — Actions ———————————————————————————————————————————————————————

  /// Adds this device as a server, unless one already is. False, after
  /// saying why, when that failed.
  static Future<bool> _addLocalServer(BuildContext ctx) async {
    final container = ProviderScope.containerOf(ctx, listen: false);
    final servers = container.read(serversProvider).servers.values;
    if (servers.any((e) => e.local)) return true;
    final notifier = container.read(serversProvider.notifier);
    try {
      await notifier.addServer(
        Spi(name: Platform.localHostname, id: ShortId.generate(), local: true),
      );
      return true;
    } catch (e, s) {
      Loggers.app.warning('Add this device from the intro', e, s);
      Toast.error(libL10n.fail, body: e.toString());
      return false;
    }
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
}

final class _IntroPageState extends State<_IntroPage> {
  final _controller = PageController();
  final _index = ValueNotifier(0);

  int get _count => widget.pages.length;
  bool get _hasPrev => _index.value > 0;
  bool get _hasNext => _index.value < _count - 1;

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = (cons.maxHeight * .1).clamp(
          _IntroPage._kMinPadTop,
          _IntroPage._kMaxPadTop,
        );
        return Scaffold(
          // Keyed on the locale: a language picked on the first page rebuilds
          // every page in it.
          key: ValueKey(Localizations.localeOf(context)),
          body: PageView.builder(
            controller: _controller,
            itemCount: _count,
            onPageChanged: (i) => _index.value = i,
            itemBuilder: (ctx, i) => widget.pages[i](ctx, padTop),
          ),
          bottomNavigationBar: _buildBar(context),
        );
      },
    );
  }

  /// A 3px progress line as the bar's top edge, then previous, the counter
  /// and the forward action, bounded by the content column so they line up
  /// with the page above.
  Widget _buildBar(BuildContext context) {
    final libL10n = context.libL10n;
    final scheme = Theme.of(context).colorScheme;

    return ValBuilder(
      listenable: _index,
      builder: (idx) {
        final last = !_hasNext;
        return Material(
          color: scheme.surface,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProgress(context, idx),
                SizedBox(
                  height: _IntroPage._kBarHeight,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: PageColumns.columnWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: AnimatedOpacity(
                                  opacity: _hasPrev ? 1 : 0,
                                  duration: context.motion(Durations.short4),
                                  child: TextButton(
                                    onPressed: _hasPrev ? _toPrev : null,
                                    child: Text(libL10n.previous),
                                  ),
                                ),
                              ),
                            ),
                            _buildCounter(context, idx),
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: FilledButton(
                                  onPressed: last
                                      ? () => _IntroPage._onDone(context)
                                      : _toNext,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        last ? libL10n.done : libL10n.next,
                                      ),
                                      UIs.width7,
                                      Icon(
                                        last
                                            ? Icons.done
                                            : Icons.arrow_forward,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// How far through the intro this page is. A plain hairline when there is
  /// one page: a full line would state nothing the page does not.
  Widget _buildProgress(BuildContext context, int idx) {
    final scheme = Theme.of(context).colorScheme;
    if (_count <= 1) {
      return Divider(
        height: 1,
        thickness: 1,
        color: scheme.outlineVariant.withValues(alpha: .35),
      );
    }
    return SizedBox(
      height: 3,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (idx + 1) / _count),
          duration: context.motion(_IntroPage._kStepDuration),
          curve: Curves.easeOutCubic,
          builder: (_, value, _) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              child: ColoredBox(color: scheme.primary),
            ),
          ),
        ),
      ),
    );
  }

  /// `2/4`, in tabular figures so the width holds as it counts.
  Widget _buildCounter(BuildContext context, int idx) {
    if (_count <= 1) return UIs.placeholder;
    final scheme = Theme.of(context).colorScheme;
    const figures = [FontFeature.tabularFigures()];
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${idx + 1}',
            style: TextStyle(color: scheme.onSurface),
          ),
          TextSpan(
            text: '/$_count',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        fontFeatures: figures,
      ),
    );
  }

  void _toPrev() => _goTo(_index.value - 1);

  void _toNext() => _goTo(_index.value + 1);

  /// A jump when motion is reduced: an animated scroll needs a duration above
  /// zero.
  void _goTo(int page) {
    final duration = context.motion(_IntroPage._kStepDuration);
    if (duration == Duration.zero) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }
}

/// Whether this launch's intro shows the Virtualization page.
@visibleForTesting
Future<bool> introShowsVirt() => _IntroPage._virtUnseen();

/// What that page adds, as it would be read now.
@visibleForTesting
({bool pveMoved, bool inBar}) introVirtFacts() => _IntroPage._virtFacts();

part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  final List<IntroPageBuilder> pages;

  const _IntroPage(this.pages);

  static const _builders = {
    1: _buildAppSettings,
    2: _buildBackupPasswordMigration,
    3: _buildCrashCollect,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        // Proportional on phones, capped so a tall desktop window doesn't push
        // the title halfway down the screen — it is used twice per page, above
        // and below the title.
        final padTop = (cons.maxHeight * .16).clamp(0.0, _kMaxPadTop);
        final pages_ = pages.map((e) => e(context, padTop)).toList();
        return IntroPage(
          key: ValueKey(Localizations.localeOf(context)),
          args: IntroPageArgs(
            pages: pages_,
            maxWidth: PageColumns.columnWidth,
            onDone: (ctx) {
              SqliteStore.transact(() {
                Stores.setting.introVer.putSync(BuildData.build);
                final lastVer = Stores.setting.lastVer;
                if (lastVer.fetch() == 0) lastVer.putSync(BuildData.build);
                // Marks the crash notice as seen, which is also what unblocks
                // uploading — see `DiagnosticsUpload.sync`. Written here rather than
                // on the page itself so that dismissing the intro without
                // reaching the last page leaves it unacknowledged, and asks
                // again next launch.
                Stores.setting.diagnosticsConsentVer.putSync(kDiagnosticsConsentVer);
              });
              // Applies whatever was chosen a moment ago. Until this runs the
              // app has uploaded nothing at all.
              unawaited(DiagnosticsUpload.sync());
              Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => _buildHomeWithWindowFrame()),
              );
            },
          ),
        );
      },
    );
  }

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

  /// Explains what a crash report carries, and lets the user pick how much of
  /// it leaves the device.
  ///
  /// Shown before anything is uploaded — `DiagnosticsUpload.sync` refuses to start
  /// until `diagnosticsConsentVer` says this page has been seen. The default is the
  /// fullest level, so this page is what turns "on by default" into "asked
  /// first", and it is the only thing that does.
  ///
  /// A radio list rather than a switch: three levels do not read as one, and
  /// the middle one is the whole reason to offer a choice instead of an
  /// on/off. Each option states what it sends, not how it feels.
  static Widget _buildCrashCollect(BuildContext ctx, double padTop) {
    final l10n = ctx.l10n;

    return _introList(
      children: [
        SizedBox(height: padTop),
        IntroPage.title(text: l10n.crashCollect, big: true),
        SizedBox(height: padTop),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(l10n.crashCollectIntro, style: UIs.textGrey),
        ),
        // Rebuilt on change so the selection is visible immediately; the store
        // is the source of truth, not a local field.
        _setting.diagnosticsLevel.listenable().listenVal((name) {
          final current = DiagnosticsLevel.fromName(name);
          // `RadioGroup` rather than a `groupValue` on each tile: the per-tile
          // form is deprecated, and the group owns the selection anyway.
          return RadioGroup<DiagnosticsLevel>(
            groupValue: current,
            onChanged: (v) {
              if (v == null) return;
              _setting.diagnosticsLevel.put(v.name);
            },
            child: Column(
            children: [
              for (final level in DiagnosticsLevel.values)
                RadioListTile<DiagnosticsLevel>(
                  value: level,
                  title: Text(switch (level) {
                    DiagnosticsLevel.none => l10n.crashCollectNone,
                    DiagnosticsLevel.basic => l10n.crashCollectBasic,
                    DiagnosticsLevel.full => l10n.crashCollectFull,
                  }),
                  subtitle: Text(
                    switch (level) {
                      DiagnosticsLevel.none => l10n.crashCollectNoneTip,
                      DiagnosticsLevel.basic => l10n.crashCollectBasicTip,
                      DiagnosticsLevel.full => l10n.crashCollectFullTip,
                    },
                    style: UIs.textGrey,
                  ),
                ).cardx,
            ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(l10n.crashCollectFooter, style: UIs.textGrey),
        ),
        UIs.height77,
      ],
    );
  }

  static Widget _buildAppSettings(BuildContext ctx, double padTop) {
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;

    return _introList(
      children: [
        SizedBox(height: padTop),
        IntroPage.title(text: libL10n.init, big: true),
        SizedBox(height: padTop),
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
          onTap: () async {
            final controller = TextEditingController();
            final result = await ctx.showRoundDialog<bool>(
              title: l10n.backupPassword,
              // Disposed by the tree. It was never disposed at all before,
              // which leaks one controller per visit and — unlike the crash
              // the same shape causes elsewhere — says nothing about it.
              child: DisposeWith(
                notifiers: [controller],
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.backupPasswordTip, style: UIs.textGrey),
                  UIs.height13,
                  Input(
                    label: l10n.backupPassword,
                    controller: controller,
                    obscureText: true,
                    // `popDialog`, not `pop`: the dialog is on the root
                    // navigator and `ctx` is the page's. It happens to be the
                    // same one today only because the intro is
                    // `MaterialApp.home` — under a pane or a tab this would
                    // close the page, leave the dialog up, and never complete
                    // the future the password is written from.
                    onSubmitted: (_) => ctx.popDialog(true),
                  ),
                ],
                ),
              ),
              actions: Btnx.cancelOk,
            );
            if (result == true) {
              final pwd = controller.text.trim();
              if (pwd.isNotEmpty) {
                await SecureStoreProps.bakPwd.write(pwd);
                Toast.show(l10n.backupPasswordSet);
              }
            }
          },
        ).cardx,
        // Nothing further here: the two lines above — `backupTip` under the
        // title and `backupPasswordTip` on the tile — already say what this
        // step is and why. A third sentence restating it was also the one
        // string on this page that was never translated.
        UIs.height77,
      ],
    );
  }

  static Future<List<IntroPageBuilder>> get builders async {
    final storedVer = _setting.introVer.fetch();
    final lastVer = _setting.lastVer.fetch();

    // If user is upgrading from older version and doesn't have backup password set,
    // show the backup password migration page
    final hasBackupPwd =
        (await SecureStoreProps.bakPwd.read())?.isNotEmpty == true;
    final isUpgrading =
        lastVer > 0 && storedVer < 2; // lastVer > 0 means not first install

    final builders = _builders.entries
        .where((e) {
          if (e.key == 2 && (!isUpgrading || hasBackupPwd)) {
            return false; // Skip backup password migration if not upgrading or already has password
          }
          // Its own counter, because `e.key > storedVer` cannot work for a
          // newly added page: `onDone` writes the *build number* into
          // `introVer`, so every key here is permanently below it for anyone
          // who has ever completed an intro. Keyed on what the page is about
          // rather than on when it was added, which is also what lets a change
          // in what is collected ask again.
          if (e.key == 3) {
            return _setting.diagnosticsConsentVer.fetch() < kDiagnosticsConsentVer;
          }
          return e.key > storedVer;
        })
        .map((e) => e.value)
        .toList();

    return builders;
  }

  static final _setting = Stores.setting;
  static const _kIconSize = 23.0;
  static const _kIntroListPad = 17.0;
  static const _kMaxPadTop = 120.0;
}

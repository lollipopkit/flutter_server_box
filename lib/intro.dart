part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  final List<IntroPageBuilder> pages;

  const _IntroPage(this.pages);

  static const _builders = {
    1: _buildAppSettings,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = cons.maxHeight * .16;
        final pages_ = pages.map((e) => e(context, padTop)).toList();
        return IntroPage(
          args: IntroPageArgs(
            pages: pages_,
            onDone: (ctx) {
              Stores.setting.introVer.put(BuildData.build);
              Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildAppSettings(BuildContext ctx, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        IntroPage.title(text: l10n.init, big: true),
        SizedBox(height: padTop),
        ListTile(
          leading: const Icon(IonIcons.language),
          title: Text(libL10n.language),
          onTap: () async {
            final selected = await ctx.showPickSingleDialog(
              title: libL10n.language,
              items: AppLocalizations.supportedLocales,
              display: (p0) => p0.nativeName,
              initial: _setting.locale.fetch().toLocale,
            );
            if (selected != null) {
              _setting.locale.put(selected.code);
              RNodes.app.notify();
            }
          },
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
          title: TipText('Docker ${l10n.stat}', l10n.parseContainerStatsTip),
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

  static List<IntroPageBuilder> get builders {
    final storedVer = _setting.introVer.fetch();
    return _builders.entries
        .where((e) => e.key > storedVer)
        .map((e) => e.value)
        .toList();
  }

  static final _setting = Stores.setting;
  static const _kIconSize = 23.0;
  static const _introListPad = EdgeInsets.symmetric(horizontal: 17);
}

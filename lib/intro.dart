part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  final List<IntroPageBuilder> pages;

  const _IntroPage(this.pages);

  static const _builders = {
    1: _buildAppSettings,
    2: _buildRecommended,
    1006: _buildTermLetterCache,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = cons.maxHeight * .16;
        final pages_ = pages.map((e) => e(context, padTop)).toList();
        return IntroPage(
          pages: pages_,
          onDone: (ctx) {
            Stores.setting.introVer.put(BuildData.build);
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        );
      },
    );
  }

  static Widget _buildTermLetterCache(BuildContext context, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        IntroPage.title(icon: BoxIcons.bxs_terminal, big: true),
        SizedBox(height: padTop),
        ListTile(
          leading: const Icon(Bootstrap.input_cursor),
          title: Text(l10n.letterCache),
          subtitle: Text(l10n.letterCacheTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.letterCache),
        ).cardx,
      ],
    );
  }

  static Widget _buildRecommended(BuildContext context, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        IntroPage.title(icon: Bootstrap.stars, big: true),
        SizedBox(height: padTop),
        ListTile(
          leading: const Icon(MingCute.delete_2_fill),
          title: const Text('rm -r'),
          subtitle: Text(l10n.sftpRmrDirSummary, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.sftpRmrDir),
        ).cardx,
        ListTile(
          leading: const Icon(IonIcons.stats_chart, size: _kIconSize),
          title: Text(l10n.parseContainerStats),
          subtitle: Text(l10n.parseContainerStatsTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.containerParseStat),
        ).cardx,
        ListTile(
          leading: const Icon(OctIcons.cpu),
          title: Text(l10n.noLineChartForCpu),
          subtitle: Text(l10n.cpuViewAsProgressTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.cpuViewAsProgress),
        ).cardx,
      ],
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
          title: Text(l10n.language),
          onTap: () async {
            final selected = await ctx.showPickSingleDialog(
              title: l10n.language,
              items: AppLocalizations.supportedLocales,
              name: (p0) => p0.code,
              initial: _setting.locale.fetch().toLocale,
            );
            if (selected != null) {
              _setting.locale.put(selected.code);
              RNodes.app.notify();
            }
          },
          trailing: Text(
            l10n.languageName,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ).cardx,
        ListTile(
          leading: const Icon(Icons.update),
          title: Text(l10n.autoCheckUpdate),
          subtitle: Text(l10n.fdroidReleaseTip, style: UIs.textGrey),
          trailing: StoreSwitch(prop: _setting.autoCheckAppUpdate),
        ).cardx,
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

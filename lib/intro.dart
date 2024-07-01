part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  const _IntroPage();

  static final _setting = Stores.setting;
  static const _kIconSize = 23.0;
  static const _introListPad = EdgeInsets.symmetric(horizontal: 17);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = cons.maxHeight * .2;
        return IntroPage(
          pages: [
            _buildAppSettings(context, padTop),
            _buildRecommended(context, padTop),
          ],
          onDone: (ctx) {
            Stores.setting.showIntro.put(false);
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        );
      },
    );
  }

  Widget _buildRecommended(BuildContext context, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        const Icon(Bootstrap.stars, size: 35),
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

  Widget _buildAppSettings(BuildContext ctx, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        _buildTitle(l10n.init, big: true),
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
              RNodes.app.build();
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

  Widget _buildTitle(String text, {bool big = false}) {
    return Center(
      child: Text(
        text,
        style: big
            ? const TextStyle(fontSize: 41, fontWeight: FontWeight.w500)
            : UIs.textGrey,
      ),
    );
  }
}

part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  final List<IntroPageBuilder> pages;

  const _IntroPage(this.pages);

  static const _builders = {1: _buildAppSettings, 2: _buildBackupPasswordMigration};

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
              Navigator.of(ctx).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
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
        // Prompt to set backup password after migration or on first launch
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(l10n.backupPassword),
          subtitle: Text(l10n.backupPasswordTip, style: UIs.textGrey),
          trailing: const Icon(Icons.keyboard_arrow_right),
          onTap: () async {
            final currentPwd = await SecureStoreProps.bakPwd.read();
            final controller = TextEditingController(text: currentPwd ?? '');
            final result = await ctx.showRoundDialog<bool>(
              title: l10n.backupPassword,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.backupPasswordTip, style: UIs.textGrey),
                  UIs.height13,
                  Input(
                    label: l10n.backupPassword,
                    controller: controller,
                    obscureText: true,
                    onSubmitted: (_) => ctx.pop(true),
                  ),
                ],
              ),
              actions: Btnx.oks,
            );
            if (result == true) {
              final pwd = controller.text.trim();
              if (pwd.isEmpty) {
                ctx.showSnackBar(libL10n.empty);
                return;
              }
              await SecureStoreProps.bakPwd.write(pwd);
              ctx.showSnackBar(l10n.backupPasswordSet);
            }
          },
        ).cardx,
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
          trailing: Text(ctx.localeNativeName, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ).cardx,
        ListTile(
          leading: const Icon(Icons.update),
          title: Text(libL10n.checkUpdate),
          subtitle: isAndroid ? Text(l10n.fdroidReleaseTip, style: UIs.textGrey) : null,
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

  static Widget _buildBackupPasswordMigration(BuildContext ctx, double padTop) {
    return ListView(
      padding: _introListPad,
      children: [
        SizedBox(height: padTop),
        IntroPage.title(text: l10n.backupPassword, big: true),
        SizedBox(height: padTop * 0.5),
        Text(
          '${l10n.backupTip}\n\n${l10n.backupPasswordTip}',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.backupPasswordTip, style: UIs.textGrey),
                  UIs.height13,
                  Input(
                    label: l10n.backupPassword,
                    controller: controller,
                    obscureText: true,
                    onSubmitted: (_) => ctx.pop(true),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => ctx.pop(false), child: Text(libL10n.cancel)),
                TextButton(onPressed: () => ctx.pop(true), child: Text(libL10n.ok)),
              ],
            );
            if (result == true) {
              final pwd = controller.text.trim();
              if (pwd.isNotEmpty) {
                await SecureStoreProps.bakPwd.write(pwd);
                ctx.showSnackBar(l10n.backupPasswordSet);
              }
            }
          },
        ).cardx,
        SizedBox(height: padTop),
        Text(
          'This step is recommended for secure backup functionality.',
          style: UIs.textGrey,
          textAlign: TextAlign.center,
        ),
        UIs.height77,
      ],
    );
  }

  static Future<List<IntroPageBuilder>> get builders async {
    final storedVer = _setting.introVer.fetch();
    final lastVer = _setting.lastVer.fetch();

    // If user is upgrading from older version and doesn't have backup password set,
    // show the backup password migration page
    final hasBackupPwd = (await SecureStoreProps.bakPwd.read())?.isNotEmpty == true;
    final isUpgrading = lastVer > 0 && storedVer < 2; // lastVer > 0 means not first install

    final builders = _builders.entries
        .where((e) {
          if (e.key == 2 && (!isUpgrading || hasBackupPwd)) {
            return false; // Skip backup password migration if not upgrading or already has password
          }
          return e.key > storedVer;
        })
        .map((e) => e.value)
        .toList();

    return builders;
  }

  static final _setting = Stores.setting;
  static const _kIconSize = 23.0;
  static const _introListPad = EdgeInsets.symmetric(horizontal: 17);
}

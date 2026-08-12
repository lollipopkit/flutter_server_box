part of 'app.dart';

final class _IntroPage extends StatelessWidget {
  final List<IntroPageBuilder> pages;

  const _IntroPage(this.pages);

  static const _builders = {
    1: _buildAppSettings,
    2: _buildBackupPasswordMigration,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final padTop = cons.maxHeight * .16;
        final pages_ = pages.map((e) => e(context, padTop)).toList();
        return IntroPage(
          key: ValueKey(Localizations.localeOf(context)),
          args: IntroPageArgs(
            pages: pages_,
            onDone: (ctx) {
              Stores.setting.introVer.put(BuildData.build);
              Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => _buildHomeWithWindowFrame()),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _buildAppSettings(BuildContext ctx, double padTop) {
    final theme = Theme.of(ctx);
    final scheme = theme.colorScheme;
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;

    return ListView(
      padding: _introListPad,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: padTop * .38),
                _buildWelcomeHeader(ctx),
                const SizedBox(height: 26),
                Text(
                  libL10n.setting,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                CardX(
                  color: scheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      ListTile(
                        leading: _buildSettingIcon(ctx, IonIcons.language),
                        title: Text(libL10n.language),
                        subtitle: Text(
                          ctx.localeNativeName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectLocale(ctx),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      ListTile(
                        leading: _buildSettingIcon(ctx, Icons.update),
                        title: Text(libL10n.checkUpdate),
                        subtitle: isAndroid
                            ? Text(l10n.fdroidReleaseTip, style: UIs.textGrey)
                            : null,
                        trailing: StoreSwitch(
                          prop: _setting.autoCheckAppUpdate,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      ListTile(
                        leading: _buildSettingIcon(
                          ctx,
                          MingCute.delete_2_fill,
                        ),
                        title: TipText('rm -r', l10n.sftpRmrDirSummary),
                        trailing: StoreSwitch(prop: _setting.sftpRmrDir),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      ListTile(
                        leading: _buildSettingIcon(
                          ctx,
                          MingCute.chart_line_line,
                          size: _kIconSize,
                        ),
                        title: TipText(
                          l10n.dockerStatistics,
                          l10n.parseContainerStatsTip,
                        ),
                        trailing: StoreSwitch(
                          prop: _setting.containerParseStat,
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      ListTile(
                        leading: _buildSettingIcon(
                          ctx,
                          Bootstrap.alphabet,
                        ),
                        title: TipText(
                          l10n.letterCache,
                          l10n.letterCacheTip,
                        ),
                        trailing: StoreSwitch(prop: _setting.letterCache),
                      ),
                    ],
                  ),
                ),
                UIs.height77,
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildWelcomeHeader(BuildContext ctx) {
    final theme = Theme.of(ctx);
    final scheme = theme.colorScheme;
    final libL10n = ctx.libL10n;
    final l10n = ctx.l10n;

    return Column(
      children: [
        Container(
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: scheme.primary.withValues(alpha: .16)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset('assets/app_icon.png'),
        ),
        const SizedBox(height: 20),
        Text(
          BuildData.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          libL10n.init,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeatureChip(ctx, Icons.dns_outlined, libL10n.server),
            _buildFeatureChip(ctx, Icons.terminal, l10n.ssh),
            _buildFeatureChip(ctx, Icons.folder_outlined, l10n.sftp),
            _buildFeatureChip(
              ctx,
              Icons.inventory_2_outlined,
              libL10n.container,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildFeatureChip(
    BuildContext ctx,
    IconData icon,
    String label,
  ) {
    final scheme = Theme.of(ctx).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Text(label, style: Theme.of(ctx).textTheme.labelLarge),
        ],
      ),
    );
  }

  static Widget _buildSettingIcon(
    BuildContext ctx,
    IconData icon, {
    double? size,
  }) {
    final scheme = Theme.of(ctx).colorScheme;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size ?? 21, color: scheme.onPrimaryContainer),
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

    return ListView(
      padding: _introListPad,
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
              actions: Btnx.cancelOk,
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
    final hasBackupPwd =
        (await SecureStoreProps.bakPwd.read())?.isNotEmpty == true;
    final isUpgrading =
        lastVer > 0 && storedVer < 2; // lastVer > 0 means not first install

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

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/motion.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/dmg_notice.dart';

/// Rows shared by Settings and the intro. Each picks from a list (a sheet on a
/// phone) and shows the value it holds.

final class LocaleTile extends StatelessWidget {
  const LocaleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final label = libL10n.language;
    final prop = Stores.setting.locale;
    return ListTile(
      leading: const Icon(IonIcons.language),
      title: Text(label),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: label,
          items: AppLocalizations.supportedLocales,
          display: (p0) => p0.nativeName,
          initial: prop.fetch().toLocale,
        );
        if (selected == null) return;
        prop.put(selected.code);
        // The picker has closed already; `notify` applies the language.
        unawaited(RNodes.app.notify());
      },
      trailing: ListenBuilder(
        listenable: prop.listenable(),
        builder: () => Text(context.localeNativeName, style: UIs.text15),
      ),
    );
  }
}

/// The installed version against the newest, a tap to check now, and the
/// switch for checking at launch.
final class CheckUpdateTile extends StatelessWidget {
  const CheckUpdateTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.update),
      title: Text(libL10n.checkUpdate),
      subtitle: ValBuilder(
        listenable: AppUpdateIface.newestBuild,
        builder: (val) {
          final display = switch (val) {
            null => libL10n.versionUnknownUpdate(BuildData.build),
            _ when val > BuildData.build => libL10n.versionHasUpdate(val),
            _ => libL10n.versionUpdated(BuildData.build),
          };
          return Text(
            isAndroid ? '$display\n${l10n.fdroidReleaseTip}' : display,
            style: UIs.textGrey,
          );
        },
      ),
      onTap: () => Fns.throttle(
        () => AppUpdateIface.doUpdate(
          context: context,
          build: BuildData.build,
          githubReleasesUrl: Urls.githubReleasesApi,
          storeUrl: Urls.appStore,
          force: BuildMode.isDebug,
          noticeBuilder: (ctx) => DmgNotice.forUpdate(
            ctx,
            build: AppUpdateIface.newestBuild.value ?? BuildData.build,
          ),
        ),
      ),
      trailing: StoreSwitch(prop: Stores.setting.autoCheckAppUpdate),
    );
  }
}

/// How often a server's status is fetched; 0 is by hand.
final class UpdateIntervalTile extends StatelessWidget {
  const UpdateIntervalTile({super.key});

  static String _display(int val) =>
      val == 0 ? libL10n.manual : '$val ${l10n.second}';

  @override
  Widget build(BuildContext context) {
    final label = l10n.updateServerStatusInterval;
    final prop = Stores.setting.serverStatusUpdateInterval;
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(label),
      onTap: () async {
        final val = await context.showPickSingleDialog(
          title: label,
          items: [0, for (var i = 2; i <= 10; i++) i],
          initial: prop.fetch(),
          display: _display,
        );
        if (val != null) prop.put(val);
      },
      trailing: ValBuilder(
        listenable: prop.listenable(),
        builder: (val) => Text(_display(val), style: UIs.text15),
      ),
    );
  }
}

/// Over the device's own "reduce motion", in either direction — see
/// `AppMotion`.
final class MotionPrefTile extends StatelessWidget {
  const MotionPrefTile({super.key});

  static String _name(MotionPref pref) => switch (pref) {
    MotionPref.system => libL10n.followSystem,
    MotionPref.reduce => libL10n.enabled,
    MotionPref.full => libL10n.disabled,
  };

  @override
  Widget build(BuildContext context) {
    final label = l10n.reduceMotion;
    final prop = Stores.setting.motionPref;
    return ListTile(
      leading: const Icon(Icons.animation),
      title: Text(label),
      onTap: () async {
        final selected = await context.showPickSingleDialog(
          title: label,
          items: MotionPref.values,
          display: _name,
          initial: prop.fetch(),
        );
        if (selected != null) prop.put(selected);
      },
      trailing: ValBuilder(
        listenable: prop.listenable(),
        builder: (pref) => Text(_name(pref), style: UIs.text15),
      ),
    );
  }
}

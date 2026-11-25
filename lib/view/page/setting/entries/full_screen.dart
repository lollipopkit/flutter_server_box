import 'package:fl_lib/fl_lib.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/page/setting/helpers.dart';

extension FullScreenSettingEntries on AppSettingsHost {
  List<SettingsGroup> buildFullScreenSettings() {
    return [
      SettingsGroup(libL10n.general, [
        if (isMobile) _buildFullScreenSwitch(),
        _buildFullScreenJitter(),
      ]),
    ];
  }

  SettingsRow _buildFullScreenSwitch() {
    final label = l10n.fullScreen;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Bootstrap.phone_landscape_fill),
        title: TipText(label, l10n.fullScreenTip),
        trailing: StoreSwitch(
          prop: setting.fullScreen,
          callback: (_) => RNodes.app.notify(),
        ),
      ),
      keywords: l10n.fullScreenTip,
    );
  }

  SettingsRow _buildFullScreenJitter() {
    final label = l10n.fullScreenJitter;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(AntDesign.shake_outline),
        title: Text(label),
        trailing: StoreSwitch(
          prop: setting.fullScreenJitter,
        ),
      ),
    );
  }
}

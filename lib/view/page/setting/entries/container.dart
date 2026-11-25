import 'package:fl_lib/fl_lib.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/page/setting/helpers.dart';

extension ContainerSettingEntries on AppSettingsHost {
  List<SettingsGroup> buildContainerSettings() {
    return [
      SettingsGroup(libL10n.general, [
        _buildUsePodman(),
        _buildContainerTrySudo(),
        _buildContainerParseStat(),
      ]),
    ];
  }

  SettingsRow _buildUsePodman() {
    final label = l10n.usePodmanByDefault;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(IonIcons.logo_docker),
        title: Text(label),
        trailing: StoreSwitch(prop: setting.usePodman),
      ),
      keywords: 'podman docker',
    );
  }

  SettingsRow _buildContainerTrySudo() {
    final label = l10n.trySudo;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(EvaIcons.person_done),
        title: TipText(label, l10n.containerTrySudoTip),
        trailing: StoreSwitch(prop: setting.containerTrySudo),
      ),
      keywords: 'sudo ${l10n.containerTrySudoTip}',
    );
  }

  SettingsRow _buildContainerParseStat() {
    final label = libL10n.stat;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(MingCute.chart_line_line),
        title: TipText(label, l10n.parseContainerStatsTip),
        trailing: StoreSwitch(prop: setting.containerParseStat),
      ),
      keywords: l10n.parseContainerStatsTip,
    );
  }
}

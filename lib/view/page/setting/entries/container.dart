part of '../entry.dart';

extension _Container on _AppSettingsPageState {
  List<SettingsGroup> _buildContainer() {
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
        trailing: StoreSwitch(prop: _setting.usePodman),
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
        trailing: StoreSwitch(prop: _setting.containerTrySudo),
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
        trailing: StoreSwitch(prop: _setting.containerParseStat),
      ),
      keywords: l10n.parseContainerStatsTip,
    );
  }
}

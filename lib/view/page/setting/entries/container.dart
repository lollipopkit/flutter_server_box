part of '../entry.dart';

extension _Container on _AppSettingsPageState {
  Widget _buildContainer() {
    return Column(
      children: [
        _buildUsePodman(),
        _buildContainerTrySudo(),
        _buildContainerParseStat(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildUsePodman() {
    return ListTile(
      leading: const Icon(IonIcons.logo_docker),
      title: Text(l10n.usePodmanByDefault),
      trailing: StoreSwitch(prop: _setting.usePodman),
    );
  }

  Widget _buildContainerTrySudo() {
    return ListTile(
      leading: const Icon(EvaIcons.person_done),
      title: TipText(l10n.trySudo, l10n.containerTrySudoTip),
      trailing: StoreSwitch(prop: _setting.containerTrySudo),
    );
  }

  Widget _buildContainerParseStat() {
    return ListTile(
      leading: const Icon(MingCute.chart_line_line, size: _kIconSize),
      // title: Text(l10n.parseContainerStats),
      // subtitle: Text(l10n.parseContainerStatsTip, style: UIs.textGrey),
      title: TipText(l10n.stat, l10n.parseContainerStatsTip),
      trailing: StoreSwitch(prop: _setting.containerParseStat),
    );
  }
}

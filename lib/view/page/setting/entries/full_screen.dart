part of '../entry.dart';

extension _Fullscreen on _AppSettingsPageState {
  List<SettingsGroup> _buildFullScreen() {
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
          prop: _setting.fullScreen,
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
          prop: _setting.fullScreenJitter,
        ),
      ),
    );
  }
}

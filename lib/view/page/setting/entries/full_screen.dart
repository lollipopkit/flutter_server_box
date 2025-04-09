part of '../entry.dart';

extension _Fullscreen on _AppSettingsPageState {
  Widget _buildFullScreen() {
    return Column(
      children: [
        _buildFullScreenSwitch(),
        _buildFullScreenJitter(),
      ].map((e) => CardX(child: e)).toList(),
    );
  }

  Widget _buildFullScreenSwitch() {
    return ListTile(
      leading: const Icon(Bootstrap.phone_landscape_fill),
      // title: Text(l10n.fullScreen),
      // subtitle: Text(l10n.fullScreenTip, style: UIs.textGrey),
      title: TipText(l10n.fullScreen, l10n.fullScreenTip),
      trailing: StoreSwitch(
        prop: _setting.fullScreen,
        callback: (_) => RNodes.app.notify(),
      ),
    );
  }

  Widget _buildFullScreenJitter() {
    return ListTile(
      leading: const Icon(AntDesign.shake_outline),
      title: Text(l10n.fullScreenJitter),
      subtitle: Text(l10n.fullScreenJitterHelp, style: UIs.textGrey),
      trailing: StoreSwitch(
        prop: _setting.fullScreenJitter,
        callback: (_) {
          context.showSnackBar(l10n.needRestart);
        },
      ),
    );
  }
}

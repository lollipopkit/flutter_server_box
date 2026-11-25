import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/page/setting/helpers.dart';

extension RemoteDesktopSettingEntries on AppSettingsHost {
  List<SettingsGroup> buildRemoteDesktopSettings() {
    return [
      SettingsGroup(libL10n.general, [_buildRemoteSessionIdleTimeout()]),
    ];
  }

  /// What the idle timeout can be set to, in seconds; 0 is never, the
  /// default.
  static const _idleTimeouts = [0, 30, 60, 300, 900, 1800];

  String _idleTimeoutLabel(int seconds) =>
      seconds <= 0 ? l10n.userNever : Duration(seconds: seconds).toAgoStr;

  SettingsRow _buildRemoteSessionIdleTimeout() {
    final label = l10n.remoteSessionIdleTimeout;
    final prop = setting.remoteSessionIdleTimeout;
    return SettingsRow(
      label,
      () => ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: TipText(label, l10n.remoteSessionIdleTimeoutTip),
        onTap: () async {
          final current = prop.fetch();
          final val = await context.showPickSingleSheet(
            title: label,
            // A value set some other way — a restored backup — is offered
            // beside the usual ones rather than shown as none of them.
            items: [
              ..._idleTimeouts,
              if (!_idleTimeouts.contains(current)) current,
            ],
            initial: current,
            display: _idleTimeoutLabel,
          );
          if (val != null) prop.put(val);
        },
        trailing: ValBuilder(
          listenable: prop.listenable(),
          builder: (val) => Text(_idleTimeoutLabel(val), style: UIs.text15),
        ),
      ),
      keywords:
          '${l10n.remoteSessionIdleTimeoutTip} ${l10n.remoteSessionKeepAlive} '
          'vnc rdp ${l10n.virtConsole}',
    );
  }
}

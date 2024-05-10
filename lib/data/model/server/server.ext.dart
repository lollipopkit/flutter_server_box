part of 'server.dart';

extension ServerX on Server {
  String getTopRightStr(ServerPrivateInfo spi) {
    switch (conn) {
      case ServerConn.disconnected:
        return l10n.disconnected;
      case ServerConn.finished:
        // Highest priority of temperature display
        final cmdTemp = () {
          final val = status.customCmds['server_card_top_right'];
          if (val == null) return null;
          // This returned value is used on server card top right, so it should
          // be a single line string.
          return val.split('\n').lastOrNull;
        }();
        final temperatureVal = () {
          // Second priority
          final preferTempDev = spi.custom?.preferTempDev;
          if (preferTempDev != null) {
            final preferTemp = status.sensors
                .firstWhereOrNull((e) => e.device == preferTempDev)
                ?.summary
                ?.split(' ')
                .firstOrNull;
            if (preferTemp != null) {
              return double.tryParse(preferTemp.replaceFirst('°C', ''));
            }
          }
          // Last priority
          final temp = status.temps.first;
          if (temp != null) {
            return temp;
          }
          return null;
        }();
        final upTime = status.more[StatusCmdType.uptime];
        final items = [
          cmdTemp ??
              (temperatureVal != null
                  ? '${temperatureVal.toStringAsFixed(1)}°C'
                  : null),
          upTime
        ];
        final str = items.where((e) => e != null && e.isNotEmpty).join(' | ');
        if (str.isEmpty) return l10n.noResult;
        return str;
      case ServerConn.loading:
        return l10n.serverTabLoading;
      case ServerConn.connected:
        return l10n.connected;
      case ServerConn.connecting:
        return l10n.serverTabConnecting;
      case ServerConn.failed:
        return status.err != null ? l10n.viewErr : l10n.serverTabFailed;
    }
  }
}

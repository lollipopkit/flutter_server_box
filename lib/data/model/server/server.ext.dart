part of 'server.dart';

extension ServerX on Server {
  String getTopRightStr(ServerPrivateInfo spi) {
    switch (state) {
      case ServerState.disconnected:
        return l10n.disconnected;
      case ServerState.finished:
        // Highest priority of temperature display
        final cmdTemp = status.customCmds['server_card_top_right'];
        final temperatureVal = () {
          // Second priority
          final preferTempDev = spi.custom?.preferTempDev;
          if (preferTempDev != null) {
            final preferTemp = status.sensors
                .firstWhereOrNull(
                  (e) => e.device == preferTempDev,
                )
                ?.props
                .values
                .firstOrNull
                ?.current;
            if (preferTemp != null) return preferTemp;
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
      case ServerState.loading:
        return l10n.serverTabLoading;
      case ServerState.connected:
        return l10n.connected;
      case ServerState.connecting:
        return l10n.serverTabConnecting;
      case ServerState.failed:
        return status.err ?? l10n.serverTabFailed;
    }
  }
}

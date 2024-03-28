part of 'server.dart';

extension ServerX on Server {
  String get topRightStr {
    switch (state) {
      case ServerState.disconnected:
        return l10n.disconnected;
      case ServerState.finished:
        final cmdTemp = status.customCmds['temperature'];
        final temp = status.temps.first;
        final sensorTemp = SensorItem.findPreferTempVal(status.sensors);
        final temperatureVal = () {
          if (temp != null) {
            return temp;
          }
          if (sensorTemp != null) {
            return sensorTemp;
          }
          return null;
        }();
        final tempVal = temperatureVal != null
            ? '${temperatureVal.toStringAsFixed(1)}°C'
            : null;
        final upTime = status.more[StatusCmdType.uptime];
        final items = [tempVal ?? cmdTemp, upTime];
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

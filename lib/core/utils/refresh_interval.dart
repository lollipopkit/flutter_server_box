import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/store.dart';

int? normalizeServerStatusRefreshSeconds(int seconds) {
  if (seconds == 0) return null;
  if (seconds <= 1 || seconds > 10) return Defaults.updateInterval;
  return seconds;
}

Duration? serverStatusRefreshInterval() {
  final seconds = normalizeServerStatusRefreshSeconds(
    Stores.setting.serverStatusUpdateInterval.fetch(),
  );
  return seconds == null ? null : Duration(seconds: seconds);
}

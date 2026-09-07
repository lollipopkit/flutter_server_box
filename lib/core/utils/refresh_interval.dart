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

/// What the custom-command interval actually comes out as, in seconds.
///
/// The commands run on a status poll and nowhere else — that is what keeps a
/// second timer, a second connection and a second failure mode out of this —
/// so an interval that is not a whole number of poll intervals cannot happen.
/// Asking for 7 seconds against a 3-second poll means the first poll at or
/// after 7 seconds, which is the one at 9.
///
/// A [requested] of 0 is one poll — the behaviour before this was configurable,
/// and the way back to it.
///
/// `null` means every refresh, and happens only when the status poll is itself
/// manual: there is then no interval to align to and the only refreshes are the
/// ones a person asks for.
///
/// [requested] and [poll] are passed in rather than read here so the settings
/// page can show the answer for a value the user is still choosing.
int? effectiveCustomCmdSeconds({required int requested, required int? poll}) {
  if (poll == null || poll <= 0) return null;
  if (requested <= 0) return poll;
  final polls = (requested + poll - 1) ~/ poll;
  return polls * poll;
}

/// [effectiveCustomCmdSeconds] for what is stored now.
Duration? customCmdRefreshInterval() {
  final seconds = effectiveCustomCmdSeconds(
    requested: Stores.setting.customCmdInterval.fetch(),
    poll: normalizeServerStatusRefreshSeconds(
      Stores.setting.serverStatusUpdateInterval.fetch(),
    ),
  );
  return seconds == null ? null : Duration(seconds: seconds);
}

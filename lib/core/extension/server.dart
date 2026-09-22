import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/dist_icon.dart';

extension LogoExt on ServerState {
  /// The large image at the top of this server's page, or null for none.
  ///
  /// Put through the same two steps as a mark: a GitHub *page* address is
  /// rewritten to the one that serves bytes, and anything whose scheme is not
  /// http or https is refused. The per-server value took neither — only the
  /// global one did, and only on the way in — so a `logoUrl` set on a server,
  /// or restored from a backup written before that check existed, reached the
  /// image loader unexamined.
  String? getLogoUrl(BuildContext context) {
    final configured =
        spi.custom?.logoUrl ??
        Stores.setting.serverLogoUrl.fetch().selfNotEmptyOrNull;
    if (configured == null) return null;

    // Every occurrence, not the first. A template naming one twice is ordinary
    // — `.../{DIST}/{DIST}-{BRIGHT}.png` is how one collection is laid out —
    // and substituting once left the literal `{DIST}` in the address that
    // reached the image loader.
    var logoUrl = resolveLogoUrl(configured);
    final dist = status.dist;
    if (logoUrl.contains('{DIST}')) {
      // Nothing to put there yet, so there is no address — the same answer
      // `distMarkUrl` gives, rather than fetching one with the braces still in
      // it and showing whatever a 404 renders as.
      if (dist == null) return null;
      logoUrl = logoUrl.replaceAll('{DIST}', distFileName(dist));
    }
    logoUrl = logoUrl.replaceAll('{BRIGHT}', context.isDark ? 'dark' : 'light');
    return isFetchableLogoUrl(logoUrl) ? logoUrl : null;
  }
}

extension ServerStateUi on ServerState {
  /// Whether what stopped the connection was the far end asking a question.
  ///
  /// Not a failure to report but a prompt to answer, which is why the card
  /// offers a lock rather than a retry: the same attempt again would ask the
  /// same question.
  bool get needsInteractiveAuth {
    final error = status.err;
    return error is SSHErr && error.type == SSHErrType.interactiveAuth;
  }

  /// The one line a list of servers carries beside a name.
  ///
  /// Temperature and uptime, and nothing else. The latency belongs to the
  /// detail page's About card: this is read while scanning a list of machines,
  /// and a number that changes on every poll is noise there.
  ///
  /// Null when there is nothing to say, which is every state but the two that
  /// have an answer — one that failed, and one that has been sampled.
  String? get listLine {
    if (status.err != null) return libL10n.viewErr;
    switch (conn) {
      case ServerConn.disconnected:
      case ServerConn.loading:
      case ServerConn.connected:
      case ServerConn.connecting:
        return null;
      case ServerConn.failed:
        return libL10n.fail;
      case ServerConn.finished:
        // Highest priority: whatever the user's own command printed.
        final cmdTemp = () {
          final val = status.customCmds['server_card_top_right'];
          if (val == null) return null;
          // Used on one line, so only the last one is of any use.
          return val.split('\n').lastOrNull;
        }();
        final temperatureVal = () {
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
          return status.temps.first;
        }();
        final upTime = status.more[StatusCmdType.uptime];
        final items = [
          cmdTemp ??
              (temperatureVal != null
                  ? '${temperatureVal.toStringAsFixed(1)}°C'
                  : null),
          upTime,
        ];
        final str = items.where((e) => e != null && e.isNotEmpty).join(' | ');
        if (str.isEmpty) return libL10n.empty;
        return str;
    }
  }
}

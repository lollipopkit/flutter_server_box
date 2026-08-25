import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/utils/logo_url.dart';
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

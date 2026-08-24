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

    var logoUrl = resolveLogoUrl(configured);
    final dist = status.dist;
    if (dist != null) {
      logoUrl = logoUrl.replaceFirst('{DIST}', distFileName(dist));
    }
    logoUrl = logoUrl.replaceFirst(
      '{BRIGHT}',
      context.isDark ? 'dark' : 'light',
    );
    return isFetchableLogoUrl(logoUrl) ? logoUrl : null;
  }
}

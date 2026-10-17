import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_desk_app.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/view/page/server/detail/readout.dart';

/// What a deployed web app's row says about it, and the colour of its dot:
/// the server page's card and the Web apps tab say the same.
(String, ReadoutVerdict) webAppStatus(MonitorWebApp app) => switch ((app.state, app.health)) {
  ('installing', _) => (l10n.webAppInstalling, ReadoutVerdict.idle),
  ('failed', _) => (libL10n.fail, ReadoutVerdict.bad),
  (_, 'healthy') => (libL10n.running, ReadoutVerdict.ok),
  (_, 'starting') => (l10n.starting, ReadoutVerdict.warn),
  (_, 'unhealthy') => (l10n.webAppUnhealthy, ReadoutVerdict.bad),
  (_, 'down') => (l10n.webAppDown, ReadoutVerdict.bad),
  (_, 'stopped') => (libL10n.stopped, ReadoutVerdict.idle),
  _ => (libL10n.unknown, ReadoutVerdict.idle),
};

/// Opens app [id] of server [serverId] in the device's browser: asks the
/// agent for a ticket and hands the browser the address that spends it. The
/// ticket is single use and lives seconds, so it is never kept or logged.
///
/// The browser then talks to the agent's proxy itself, with a session of its
/// own: nothing of this app stays in the path, so it may go to the
/// background or be closed.
Future<void> openWebApp(WidgetRef ref, String serverId, String id) async {
  try {
    final uri = await ref.read(webAppsProvider(serverId).notifier).enter(id);
    if (uri == null) return;
    if (!await uri.toString().launchUrl()) Toast.error(libL10n.fail);
  } catch (e) {
    Toast.error(libL10n.fail, body: '$e');
  }
}

/// Opens desk app [app] of server [serverId] in the device's browser: the
/// panel at the agent, which opens it once signed in. The browser signs in
/// to the panel itself.
Future<void> openDeskApp(WidgetRef ref, String serverId, MonitorDeskApp app) async {
  final uri = ref.read(webAppsProvider(serverId).notifier).deskUri(app);
  if (uri == null) return;
  if (!await uri.toString().launchUrl()) Toast.error(libL10n.fail);
}

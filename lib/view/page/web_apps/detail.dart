import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/web_apps.dart';
import 'package:server_box/view/page/web_apps/status.dart';

final class WebAppPageArgs {
  const WebAppPageArgs({required this.serverId, required this.appId});

  final String serverId;
  final String appId;
}

/// One deployed web app: its health, what it is, and the way into it. Beside
/// the Web apps tab's list on a wide window, over it on a narrow one.
///
/// Read live from the server's list, so it follows the agent's next look at
/// the app; an app removed meanwhile leaves the page saying so.
class WebAppPage extends ConsumerWidget {
  const WebAppPage({super.key, this.args});

  final WebAppPageArgs? args;

  static const route = AppRoute<void, WebAppPageArgs>(page: WebAppPage.new, path: '/web-apps/app');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = this.args;
    if (args == null) return const EmptyPane(icon: Icons.apps);
    final server = ref.watch(serversProvider.select((s) => s.servers[args.serverId]?.name));
    final app = ref.watch(webAppsProvider(args.serverId)).apps?.firstWhereOrNull((a) => a.id == args.appId);
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (app == null) {
      return Scaffold(
        appBar: CustomAppBar(title: Text(l10n.webApps)),
        body: EmptyPane(icon: Icons.apps, label: libL10n.empty),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final (status, tone) = webAppStatus(app);
    final description = app.descriptionIn(locale);
    return Scaffold(
      appBar: CustomAppBar(title: Text(app.titleIn(locale))),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          CardX(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.circle, size: 13, color: tone.color(scheme)),
                  title: Text(status),
                  subtitle: Text(
                    [?server, if (app.failing.isNotEmpty) app.failing.join(', ')].join(' · '),
                    style: UIs.text12Grey,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 0, 17, 13),
                    child: Text(description),
                  ),
              ],
            ),
          ),
          if (app.version != null || app.homepage != null)
          CardX(
            child: Column(
              children: [
                if (app.version case final version?)
                  ListTile(
                    title: Text(l10n.webAppVersion),
                    trailing: Text(version, style: UIs.text13Grey),
                    subtitle: app.updatable ? Text(l10n.webAppUpdate(app.latest!), style: UIs.text12Grey) : null,
                  ),
                if (app.homepage case final homepage?)
                  ListTile(
                    title: Text(l10n.webAppHomepage),
                    subtitle: Text(homepage, style: UIs.text12Grey),
                    trailing: const Icon(Icons.open_in_new, size: 19),
                    onTap: () => homepage.launchUrl(),
                  ),
              ],
            ),
          ),
          UIs.height13,
          // Not offered while the proxy is not in front of it (being
          // deployed, failed): the row above says why.
          FilledButton.icon(
            onPressed: app.proxy ? () => openWebApp(ref, args.serverId, app.id) : null,
            icon: const Icon(Icons.open_in_new),
            label: Text(libL10n.open),
          ),
        ],
      ),
    );
  }
}

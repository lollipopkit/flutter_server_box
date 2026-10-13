part of 'view.dart';

// --- The web apps the server's monitor agent deployed ---

extension on _ServerDetailPageState {
  /// The agent's deployed web apps, each opened in a browser through the
  /// agent's proxy. Absent unless the agent has some: deploying is the
  /// panel's.
  Widget? _buildWebApps(ServerState si) {
    final state = ref.watch(webAppsProvider(si.spi.id));
    final apps = state.apps;
    if (apps == null || apps.isEmpty) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    return _buildReadoutCard(
      cardKey: 'webApps',
      icon: ServerDetailCards.webApps.icon,
      title: l10n.webApps,
      mark: Feature.webApps.mark(),
      verdict: state.error == null ? null : (text: libL10n.fail, tone: ReadoutVerdict.bad),
      // Not `rows`, which a card cuts at [kReadoutCardRows]: each is the way
      // to its app, and none may be hidden.
      extra: [
        for (final app in apps)
          if (webAppStatus(app) case (final status, final tone))
            ServerDetailReadoutRow(
              k: app.titleIn(locale),
              v: status,
              sub: app.failing.isEmpty ? null : app.failing.join(', '),
              dot: tone.color(scheme),
              onTap: app.proxy ? () => openWebApp(ref, si.spi.id, app.id) : null,
            ),
      ],
      initiallyExpanded: true,
    );
  }
}

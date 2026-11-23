part of '../entry.dart';

enum _McpListenPreset { all, lan, local, custom }

extension _McpSettings on _AppSettingsPageState {
  List<SettingsGroup> _buildMcp() {
    final l10n = context.l10n;
    return [
      SettingsGroup(l10n.connection, [
        SettingsRow(
          l10n.enable,
          () => ValueListenableBuilder(
            valueListenable: appMcpListener,
            builder: (context, server, _) => SwitchListTile(
              secondary: const Icon(Icons.power_settings_new),
              title: Text(l10n.enable),
              value: server != null,
              onChanged: (enabled) async {
                try {
                  await configureAppMcp(
                    ProviderScope.containerOf(context, listen: false),
                    enabled: enabled,
                  );
                } catch (e, s) {
                  if (context.mounted) context.showErrSheet(e, s, 'MCP');
                }
              },
            ),
          ),
        ),
        SettingsRow(
          l10n.virtHwListen,
          () => ListenBuilder(
            listenable: Stores.setting.appMcp.listenable(),
            builder: () => ListTile(
              leading: const Icon(Icons.settings_ethernet),
              title: Text(l10n.virtHwListen),
              subtitle: Text(appMcpListen),
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseMcpListen,
            ),
          ),
          keywords: 'IP port Wi-Fi LAN Tailscale',
        ),
        SettingsRow(
          l10n.monitorMcpEndpoint,
          () => ListenBuilder(
            listenable: Stores.setting.appMcp.listenable(),
            builder: () => const _McpEndpoints(),
          ),
        ),
      ]),
      SettingsGroup(l10n.monitorMcpTokens, [
        SettingsRow(
          l10n.monitorMcpNewToken,
          () => const _McpTokens(),
          keywords: 'API token',
        ),
      ]),
    ];
  }

  Future<void> _chooseMcpListen() async {
    final l10n = context.l10n;
    final current = appMcpListen;
    final endpoint = appMcpEndpoint(current);
    final ipv6 = endpoint.host.contains(':');
    final all = ipv6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4;
    final local = ipv6
        ? InternetAddress.loopbackIPv6
        : InternetAddress.loopbackIPv4;
    final preset = await context.showPickSingleSheet(
      title: l10n.virtHwListen,
      items: _McpListenPreset.values,
      display: (preset) => switch (preset) {
        _McpListenPreset.all => '${libL10n.all} (${all.address})',
        _McpListenPreset.lan => '${l10n.lan} (Wi-Fi / Tailscale)',
        _McpListenPreset.local => '${l10n.thisDevice} (${local.address})',
        _McpListenPreset.custom => libL10n.custom,
      },
    );
    if (preset == null || !mounted) return;
    try {
      final listen = switch (preset) {
        _McpListenPreset.all => appMcpListenAt(all, endpoint.port),
        _McpListenPreset.local => appMcpListenAt(local, endpoint.port),
        _McpListenPreset.lan => await _chooseMcpInterface(endpoint.port),
        _McpListenPreset.custom => await context.showInputSheet(
          title: l10n.virtHwListen,
          label: l10n.appMcpAddress,
          initial: current,
        ),
      };
      if (listen == null || !mounted) return;
      await configureAppMcp(
        ProviderScope.containerOf(context, listen: false),
        enabled: appMcpListener.value != null,
        listen: listen,
      );
    } catch (e, s) {
      if (mounted) context.showErrSheet(e, s, 'MCP');
    }
  }

  Future<String?> _chooseMcpInterface(int port) async {
    final interfaces = await appMcpInterfaces();
    if (!mounted) return null;
    if (interfaces.isEmpty) {
      await context.showSheet(
        title: context.l10n.lan,
        child: Text(libL10n.empty),
      );
      return null;
    }
    final selected = await context.showPickSingleSheet(
      title: context.l10n.lan,
      items: interfaces,
      display: (item) => '${item.interfaceName} · ${item.address.address}',
    );
    return selected == null ? null : appMcpListenAt(selected.address, port);
  }
}

/// Where a client reaches the listener: the address it is bound to, or on
/// a wildcard every address another machine can reach.
class _McpEndpoints extends StatelessWidget {
  const _McpEndpoints();

  @override
  Widget build(BuildContext context) {
    final bound = appMcpEndpoint(appMcpListen);
    if (bound.host != '0.0.0.0' && bound.host != '::') {
      return _tile(context, bound);
    }
    return FutureBuilder(
      future: appMcpInterfaces(),
      builder: (context, snapshot) {
        final ipv6 = bound.host == '::';
        final urls = [
          for (final item in snapshot.data ?? const [])
            if (ipv6 || item.address.type == InternetAddressType.IPv4)
              bound.replace(host: item.address.address),
        ];
        if (urls.isEmpty) return _tile(context, null);
        return Column(children: [for (final url in urls) _tile(context, url)]);
      },
    );
  }

  Widget _tile(BuildContext context, Uri? url) => ListTile(
    leading: const Icon(Icons.link),
    title: Text(context.l10n.monitorMcpEndpoint),
    subtitle: url == null ? Text(libL10n.empty) : SelectableText('$url'),
    trailing: url == null
        ? null
        : IconButton(
            icon: const Icon(Icons.copy),
            tooltip: libL10n.copy,
            onPressed: () => Pfs.copy('$url'),
          ),
  );
}

String _mcpScopeName(String scope) => switch (scope) {
  'read' => l10n.monitorMcpScopeRead,
  'exec' => l10n.monitorMcpScopeExec,
  'process' => l10n.monitorMcpScopeProcess,
  'service' => l10n.monitorMcpScopeService,
  'container' => l10n.monitorMcpScopeContainer,
  'settings' => libL10n.setting,
  _ => scope,
};

class _McpTokens extends StatefulWidget {
  const _McpTokens();
  @override
  State<_McpTokens> createState() => _McpTokensState();
}

class _McpTokensState extends State<_McpTokens> {
  late var _registry = loadMcpRegistry(appMcpRegistryFile);

  void _refresh() =>
      setState(() => _registry = loadMcpRegistry(appMcpRegistryFile));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: Text(l10n.monitorMcpNewToken),
          onTap: _add,
        ),
        FutureBuilder(
          future: _registry,
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return ListTile(
                title: Text('${snapshot.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: libL10n.retry,
                  onPressed: _refresh,
                ),
              );
            }
            final registry = snapshot.data;
            if (registry == null) return const LinearProgressIndicator();
            if (registry.tokens.isEmpty) {
              return ListTile(
                title: Text(l10n.monitorMcpNoTokens, style: UIs.textGrey),
              );
            }
            return Column(
              children: [
                for (final token in registry.tokens)
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(token.name),
                    subtitle: Text(
                      token.scopes?.map(_mcpScopeName).join(' · ') ??
                          libL10n.all,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.monitorMcpRevoke,
                      onPressed: () => _revoke(token),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _revoke(AppMcpToken token) async {
    final ok = await context.showSheet<bool>(
      title: l10n.monitorMcpRevoke,
      child: Text(l10n.monitorMcpRevokeHint(token.name)),
      actions: Btnx.cancelOk,
    );
    if (ok != true || !mounted) return;
    try {
      await revokeMcpToken(appMcpRegistryFile, token.id);
      if (mounted) _refresh();
    } catch (e, s) {
      if (mounted) context.showErrSheet(e, s, 'MCP');
    }
  }

  Future<void> _add() async {
    final name = await context.showInputSheet(
      title: l10n.monitorMcpNewToken,
      label: libL10n.name,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final all = appMcpScopes();
    final scopes = await context.showPickSheet<String>(
      title: name.trim(),
      items: all,
      display: _mcpScopeName,
      initial: all,
    );
    if (scopes == null || scopes.isEmpty || !mounted) return;
    try {
      final token = await createMcpToken(
        appMcpRegistryFile,
        name,
        // Every scope is stored as none named, so a newer build's reach too.
        scopes: scopes.length == all.length ? null : scopes,
      );
      if (!mounted) return;
      _refresh();
      await context.showSheet<void>(
        title: name.trim(),
        child: SelectableText(token),
        actions: [
          Btn.text(text: libL10n.copy, onTap: () => Pfs.copy(token)),
          Btn.ok(onTap: () => context.popSheet()),
        ],
      );
    } catch (e, s) {
      if (mounted) context.showErrSheet(e, s, 'MCP');
    }
  }
}

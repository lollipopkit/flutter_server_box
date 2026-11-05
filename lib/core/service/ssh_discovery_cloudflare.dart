import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// The `ssh://` hostnames of the Cloudflare Tunnels an API token can read,
/// added with `cloudflared access ssh` as their ProxyCommand.
///
/// Only remotely managed tunnels: a locally managed one keeps its ingress in
/// a `config.yml` the API never sees.
final class CloudflareDiscovery implements SshDiscovery {
  const CloudflareDiscovery([this._client]);

  final Dio? _client;

  static const _api = 'https://api.cloudflare.com/client/v4';

  /// Where `cloudflared` can run as the ProxyCommand: a desktop that starts
  /// processes. A phone's userland does not ship it.
  static bool get isSupported => isDesktop && ProcessExec.isSupported;
  static const proxyCommand = 'cloudflared access ssh --hostname %h';

  @override
  String get id => 'cloudflare';

  @override
  String get label => 'Cloudflare';

  @override
  IconData get icon => Icons.cloud_outlined;

  @override
  bool get auto => false;

  @override
  SshDiscoveryCredential get credential => SshDiscoveryCredential(
    label: l10n.cloudflareApiToken,
    hint: l10n.cloudflareApiTokenTip,
  );

  @override
  Future<String?> scope() async => null;

  @override
  Future<SshDiscoveryRun> discover({String? input}) async {
    final token = input?.trim() ?? '';
    if (token.isEmpty) {
      throw SshDiscoveryException(l10n.cloudflareApiToken);
    }
    final dio =
        _client ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            validateStatus: (_) => true,
          ),
        );
    try {
      return await _discover(dio, token);
    } finally {
      if (_client == null) dio.close();
    }
  }

  Future<SshDiscoveryRun> _discover(Dio dio, String token) async {
    final headers = {'Authorization': 'Bearer $token'};

    Future<Map<String, dynamic>> request(
      String path, [
      Map<String, Object>? query,
    ]) async {
      final res = await dio.get<Map<String, dynamic>>(
        '$_api$path',
        queryParameters: query,
        options: Options(headers: headers, responseType: ResponseType.json),
      );
      final body = res.data;
      if (body == null || body['success'] != true) {
        final errors = (body?['errors'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((e) => e['message'])
            .join('; ');
        throw SshDiscoveryException(
          errors?.selfNotEmptyOrNull ?? 'HTTP ${res.statusCode}',
          tip: l10n.cloudflareApiTokenTip,
        );
      }
      return body;
    }

    /// Every page of a list endpoint.
    Future<List<Map<String, dynamic>>> all(
      String path, [
      Map<String, Object> query = const {},
    ]) async {
      final items = <Map<String, dynamic>>[];
      for (var page = 1; ; page++) {
        final body = await request(path, {...query, 'page': page, 'per_page': 50});
        items.addAll((body['result'] as List).cast<Map<String, dynamic>>());
        final info = body['result_info'] as Map<String, dynamic>?;
        final pages = info?['total_pages'] as int? ?? 1;
        if (page >= pages) break;
      }
      return items;
    }

    final accounts = await all('/accounts');
    final hosts = <DiscoveredSshHost>[];
    for (final account in accounts) {
      final accountId = account['id'] as String;
      final tunnels = await all('/accounts/$accountId/cfd_tunnel', {
        'is_deleted': 'false',
      });
      final found = await Future.wait([
        for (final tunnel in tunnels)
          request(
            '/accounts/$accountId/cfd_tunnel/${tunnel['id']}/configurations',
          ).then(
            (body) => hostsOf(tunnel, body['result']),
            // One tunnel whose configuration cannot be read is left out, not
            // the account.
            onError: (Object e, StackTrace s) {
              Loggers.app.warning('Cloudflare tunnel configuration', e, s);
              return const <DiscoveredSshHost>[];
            },
          ),
      ]);
      hosts.addAll(found.expand((e) => e));
    }
    hosts.sort((a, b) => a.host.compareTo(b.host));
    return (
      hosts: hosts,
      scope: accounts.map((e) => e['name']).whereType<String>().join(', '),
    );
  }

  /// The `ssh://` ingress rules of one tunnel's configuration.
  @visibleForTesting
  static List<DiscoveredSshHost> hostsOf(
    Map<String, dynamic> tunnel,
    Object? configuration,
  ) {
    final config = switch (configuration) {
      {'config': final Map<String, dynamic> c} => c,
      _ => null,
    };
    final ingress = (config?['ingress'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final online = switch (tunnel['status']) {
      'healthy' || 'degraded' => true,
      'down' || 'inactive' => false,
      _ => null,
    };
    final hosts = <DiscoveredSshHost>[];
    for (final rule in ingress) {
      final service = rule['service'] as String? ?? '';
      final hostname = rule['hostname'] as String? ?? '';
      if (!service.startsWith('ssh://')) continue;
      // A wildcard names no one machine to connect to.
      if (hostname.isEmpty || hostname.contains('*')) continue;
      hosts.add(
        DiscoveredSshHost(
          key: hostname,
          server: Spi(
            name: hostname,
            id: ShortId.generate(),
            ssh: SshCredential(ip: hostname, proxyCommand: proxyCommand),
          ),
          detail: [?tunnel['name'] as String?, service].join(' · '),
          online: online,
        ),
      );
    }
    return hosts;
  }
}

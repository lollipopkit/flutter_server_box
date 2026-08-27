import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// How a server's live status is obtained: SSH+shell or monitor's HTTP API.
/// The two are peer connection methods in the data-fetch (network) layer —
/// see `Spi.monitorHttp`'s doc comment — not "SSH plus an optional feature".
///
/// `ServerNotifier._getData()` switches on this instead of scattering
/// `spi.monitorHttp != null` checks across the fetch logic.
///
/// A server may carry both. [fromSpi] then answers whichever
/// [Spix.transport] names, and [fallbackOf] answers the other — the two
/// together are what lets a feature run over whichever transport can carry it
/// without any caller learning that there were two.
sealed class ServerConnectCredential {
  const ServerConnectCredential();

  /// The way this server is reached first.
  factory ServerConnectCredential.fromSpi(Spi spi) =>
      _of(spi, spi.transport) ??
      // Only reachable for a server with neither configured, which
      // `Spix.validate` refuses and the editor will not save. An SSH
      // credential with no host fails at connect with something that names the
      // server, which beats throwing here — out of a factory called while a
      // list is building.
      ServerConnectCredentialSsh(spi: spi);

  /// The other way in, or null when there is only one.
  static ServerConnectCredential? fallbackOf(Spi spi) {
    final fallback = spi.fallbackTransport;
    return fallback == null ? null : _of(spi, fallback);
  }

  static ServerConnectCredential? _of(Spi spi, ServerTransport transport) {
    switch (transport) {
      case ServerTransport.ssh:
        return spi.ssh == null ? null : ServerConnectCredentialSsh(spi: spi);
      case ServerTransport.monitorHttp:
        final monitor = spi.monitor;
        return monitor == null
            ? null
            : ServerConnectCredentialMonitorHttp(spi: spi, monitor: monitor);
    }
  }
}

final class ServerConnectCredentialSsh extends ServerConnectCredential {
  final Spi spi;

  const ServerConnectCredentialSsh({required this.spi});
}

final class ServerConnectCredentialMonitorHttp extends ServerConnectCredential {
  final Spi spi;

  final MonitorHttpCredential monitor;

  const ServerConnectCredentialMonitorHttp({
    required this.spi,
    required this.monitor,
  });
}

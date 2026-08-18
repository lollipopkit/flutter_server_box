import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// How a server's live status is obtained: SSH+shell or monitor's HTTP API.
/// The two are peer connection methods in the data-fetch (network) layer —
/// see `Spi.monitorHttp`'s doc comment — not "SSH plus an optional feature".
///
/// `ServerNotifier._getData()` switches on this instead of scattering
/// `spi.monitorHttp != null` checks across the fetch logic.
sealed class ServerConnectCredential {
  const ServerConnectCredential();

  factory ServerConnectCredential.fromSpi(Spi spi) {
    final monitor = spi.monitorHttp;
    if (monitor != null && monitor.addr.trim().isNotEmpty) {
      return ServerConnectCredentialMonitorHttp(spi: spi, monitor: monitor);
    }
    return ServerConnectCredentialSsh(spi: spi);
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

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';

extension ServerTcpDialerRef on Ref {
  /// The dialer for [spi], connecting through its `ServerNotifier`: the SSH
  /// client it holds, and the relay grant it last read from the agent.
  ServerTcpDialer serverTcpDialer(
    Spi spi, {
    Set<ServerTransport> transports = const {...ServerTransport.values},
  }) => ServerTcpDialer(
    spi: spi,
    ssh: () async => ServerTcpSsh.client(
      await read(serverProvider(spi.id).notifier).ensureShellClient(),
    ),
    relayGrant: () => read(serverProvider(spi.id)).agentAccess,
    transports: transports,
  );
}

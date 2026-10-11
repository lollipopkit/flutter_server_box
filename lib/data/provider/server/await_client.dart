import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';

/// The status poller's connection to a server, once it has one; null when it
/// is not making one, or has not made it within [timeout].
///
/// For something about to dial the same server — a terminal restored at
/// launch, which opens while the poller is still authenticating and finds
/// nothing yet to adopt. A second connection from the same address at that
/// moment is one sshd may refuse outright — `PerSourceMaxStartups`, or
/// `PerSourcePenalties` — with "Not allowed at this time", and keep refusing
/// for a while after. Waiting for the poller and sharing its connection is
/// what that caller does anyway once the poller is up.
///
/// [current] is the server's state now; [listen] subscribes to it, as
/// `WidgetRef.listenManual` or `ProviderContainer.listen` do.
Future<SSHClient?> awaitServerClient(
  ServerState current, {
  required ProviderSubscription<ServerState> Function(
    void Function(ServerState? previous, ServerState next) listener,
  )
  listen,
  Duration timeout = const Duration(seconds: 20),
}) async {
  SSHClient? ready(ServerState state) => switch (state.client) {
    final client? when !client.isClosed => client,
    _ => null,
  };
  if (ready(current) case final client?) return client;
  if (current.conn != ServerConn.connecting) return null;

  final done = Completer<SSHClient?>();
  final sub = listen((_, next) {
    if (done.isCompleted) return;
    if (ready(next) case final client?) {
      done.complete(client);
    } else if (next.conn != ServerConn.connecting) {
      done.complete(null);
    }
  });
  try {
    return await done.future.timeout(timeout, onTimeout: () => null);
  } finally {
    sub.close();
  }
}

/// [awaitServerClient] for server [id], from a widget.
Future<SSHClient?> awaitServerClientOf(WidgetRef ref, String id) =>
    awaitServerClient(
      ref.read(serverProvider(id)),
      listen: (listener) => ref.listenManual(serverProvider(id), listener),
    );

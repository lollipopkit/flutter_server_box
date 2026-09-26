import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';

extension PresentServerX on WidgetRef {
  /// [serverProvider] for [id], or null once that server is gone.
  ///
  /// A terminal outlives its server: the route carries a snapshot, and a tab
  /// restored after the server was deleted — here or by a sync — has nothing
  /// behind it. Asked anyway, the provider's first build throws "not found"
  /// (SERVERBOX-D). Nothing connected is what a missing server has, and
  /// connecting from the snapshot then fails the ordinary way, on screen.
  ServerState? readPresentServer(String id) =>
      read(serversProvider).servers[id] == null
      ? null
      : read(serverProvider(id));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';

/// How many servers are up, over the server tab's icon.
///
/// It used to be a line of text above the server list — "2/4 Connection" —
/// which is a heading for a page you are already looking at. On the tab it
/// answers the question it is actually asked: whether anything is down, from
/// wherever in the app you happen to be.
///
/// Bare "2/4" with no word after it. The icon underneath already says what is
/// being counted, and a badge is read at a glance or not at all.
class ConnCountBadge extends ConsumerWidget {
  const ConnCountBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    // No servers, no count. "0/0" over an icon says less than nothing there.
    if (order.isEmpty) return child;

    // Watched one at a time, and only the connection state of each, so a
    // status arriving for a server nobody is looking at does not rebuild this.
    var connected = 0;
    for (final id in order) {
      final conn = ref.watch(serverProvider(id).select((v) => v.conn));
      if (conn.index >= ServerConn.connected.index) connected++;
    }

    return Badge(label: Text('$connected/${order.length}'), child: child);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/widget/nav_rail.dart';

/// How many servers are up, as the two places that draw it need it.
///
/// It used to be a line of text above the server list — "2/4 Connection" —
/// which is a heading for a page you are already looking at. On the tab it
/// answers the question it is actually asked: whether anything is down, from
/// wherever in the app you happen to be.
///
/// Bare "2/4" with no word after it. The icon underneath already says what is
/// being counted, and a badge is read at a glance or not at all. [count] is
/// null when there are no servers at all — "0/0" over an icon says less than
/// nothing.
class ConnCountBuilder extends ConsumerWidget {
  const ConnCountBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, String? count) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    if (order.isEmpty) return builder(context, null);

    // Watched one at a time, and only the connection state of each, so a
    // status arriving for a server nobody is looking at does not rebuild this.
    var connected = 0;
    for (final id in order) {
      final conn = ref.watch(serverProvider(id).select((v) => v.conn));
      if (conn.index >= ServerConn.connected.index) connected++;
    }

    return builder(context, '$connected/${order.length}');
  }
}

/// The count over whatever it wraps, for the bottom bar.
class ConnCountBadge extends StatelessWidget {
  const ConnCountBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConnCountBuilder(
      builder: (_, count) =>
          count == null ? child : Badge(label: Text(count), child: child),
    );
  }
}

/// The same count for the rail, which positions it itself.
///
/// [ConnCountBadge] hangs Material's badge off what it wraps, and in the rail
/// that is the icon — inside the indicator, over the glyph. Here the badge is
/// the whole widget and the rail puts it on the indicator's corner.
class ConnCountRailBadge extends StatelessWidget {
  const ConnCountRailBadge({super.key, this.opacity = 1});

  /// How far the rail has it faded — see [NavRailBadge.opacity].
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ConnCountBuilder(
      builder: (_, count) => count == null
          ? const SizedBox.shrink()
          : NavRailBadge(label: count, opacity: opacity),
    );
  }
}

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/arrival.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/reading_text.dart';
import 'package:server_box/view/widget/built_from.dart';
import 'package:server_box/view/widget/dist_icon.dart';

/// The name row, and how much of it is left.
///
/// It goes as the card becomes the page: by then the window's own bar names
/// the machine and carries the switcher to the others, and a second name
/// under it would be the page saying what it is twice. Collapsed rather than
/// faded alone, or the block below would arrive 23pt lower than the page
/// puts it.
class ServerCardTitle extends StatelessWidget {
  const ServerCardTitle({
    super.key,
    required this.srv,
    required this.openness,
    this.selected,
  });

  final ServerState srv;

  /// How far the card is on its way to the page — see `ServerCard.openness`.
  final double openness;

  /// Whether this machine is one of the ones being acted on, or null when
  /// nothing is — see `ServerCard.selected`.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final t = openness;
    if (t <= 0) return _title();
    if (t >= 1) return const SizedBox.shrink();
    return ServerCardReveal(shown: 1 - t, child: _title());
  }

  /// Kept between polls while it says the same thing — see [BuiltFrom]. A
  /// machine's name, what it runs and how it is reached are a fifth of its
  /// card, and none of it is what a poll is about; the line on the right is
  /// its uptime, which changes once a minute. What the control on the right
  /// does is of the record, which is listed.
  Widget _title() {
    final line = srv.needsInteractiveAuth ? libL10n.tapToAuth : srv.listLine;
    return BuiltFrom(
      [
        srv.spi,
        line,
        srv.conn,
        srv.needsInteractiveAuth,
        selected,
        Stores.setting.showDistMark.fetch(),
      ],
      builder: (_) => _titleRow(line),
    );
  }

  Widget _titleRow(String? line) {
    return LayoutBuilder(
      builder: (_, cons) => Row(
        children: [
          // The name and its arrow take what is left after the line on the
          // right, and no more: in a row a text is given its intrinsic width,
          // so a long name never gets to elide — it pushes the row past the
          // card instead.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected case final selected?)
                  ServerCardCheck(selected: selected),
                // Before the name, at the size of it: which distribution a
                // machine runs is what a list of servers is scanned for, and
                // it reads faster as a shape than as a word. The gap goes with
                // it — marks switched off has to mean no pixels.
                ...?switch (distIcon(srv.spi.id, size: 17)) {
                  final mark? => [mark, const SizedBox(width: 7)],
                  null => null,
                },
                Flexible(
                  child: Text(
                    srv.spi.name,
                    style: const TextStyle(
                      fontSize: ServerCardSizes.name,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 17, color: Colors.grey),
              ],
            ),
          ),
          if (line != null)
            ConstrainedBox(
              // Capped because it is the unbounded one now, and its length is
              // not ours to choose: a long uptime, or whatever
              // `server_card_top_right` prints.
              constraints: BoxConstraints(
                maxWidth: cons.maxWidth.isFinite
                    ? cons.maxWidth * 0.5
                    : double.infinity,
              ),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: Colors.grey,
                  fontFeatures: kTabularFigures,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(width: 7),
          ServerCardConnAction(srv: srv),
        ],
      ),
    );
  }
}

/// What the right of the title offers, which is different in every
/// connection state and is the only control a collapsed card has.
class ServerCardConnAction extends ConsumerWidget {
  const ServerCardConnAction({super.key, required this.srv});

  final ServerState srv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (child, onTap) = switch (srv.conn) {
      ServerConn.connecting ||
      ServerConn.loading ||
      ServerConn.connected => (
        const SizedBox.square(dimension: 19, child: SizedLoading(19, padding: 2)),
        null,
      ),
      ServerConn.failed => (
        Icon(
          srv.needsInteractiveAuth ? Icons.lock_outline : Icons.refresh,
          size: 19,
          color: Colors.grey,
        ),
        () {
          // The user asking again *is* the new information: without this the
          // request is dropped by the backoff the previous failures installed.
          TryLimiter.reset(srv.spi.id);
          ref.read(serversProvider.notifier).refresh(spi: srv.spi);
        },
      ),
      ServerConn.disconnected => (
        const Icon(MingCute.link_3_line, size: 19, color: Colors.grey),
        () => ref.read(serversProvider.notifier).refresh(spi: srv.spi),
      ),
      ServerConn.finished => (
        const Icon(MingCute.unlink_2_line, size: 17, color: Colors.grey),
        () => ref.read(serversProvider.notifier).closeServer(id: srv.spi.id),
      ),
    };

    final wrapped = SizedBox(
      height: 23,
      width: ServerCardSizes.action,
      child: Center(child: child),
    );
    if (onTap == null) return wrapped;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: wrapped,
    );
  }
}

/// The box that says whether this machine is one of the ones being acted
/// on. Not built at all when nothing is.
class ServerCardCheck extends StatelessWidget {
  const ServerCardCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: Icon(
        selected ? Icons.check_box : Icons.check_box_outline_blank,
        size: 19,
        color: selected ? scheme.primary : Colors.grey,
      ),
    );
  }
}

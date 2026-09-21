import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/self_addr.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/widget/built_from.dart';

/// One line of an info card: what it is, what it is at, and whether it stays
/// off screen until asked for — see [SecretText].
typedef ServerInfoRow = ({String k, String v, bool secret});

/// A card of facts about the machine: a title, then a name and a value a line.
///
/// Built again when one of its rows says something else. What a machine is
/// built of never does, and what it is called and running changes with its
/// uptime: once a minute, on a page rebuilt every few seconds.
class ServerDetailInfoCard extends StatelessWidget {
  const ServerDetailInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<ServerInfoRow> rows;

  /// The About card's rows: how the app reaches the machine, what the machine
  /// says of itself, and its public address.
  static List<ServerInfoRow> aboutRows(ServerState si) {
    final ss = si.status;
    final publicIp = SelfAddr.pick(ss.ips);
    // One row, not two: how the app reaches this machine and how long that
    // took are the same fact — a delay means nothing without knowing whether
    // it timed an HTTP request or a shell script on a loaded box.
    final connection = [
      _transportName(si),
      if (si.agentVersion case final version?) 'v$version',
    ].join(' ');
    return <ServerInfoRow>[
      (
        k: libL10n.conn,
        v: si.latencyMs == null
            ? connection
            : '$connection · ${si.latencyMs}ms',
        secret: false,
      ),
      for (final e in ss.more.entries) (k: e.key.i18n, v: e.value, secret: false),
      if (publicIp != null)
        (k: l10n.publicIp, v: publicIp.address, secret: true),
    ];
  }

  /// The Hardware card's rows: what the machine is built of.
  static List<ServerInfoRow> hardwareRows(ServerState si) {
    final ss = si.status;
    final cores = ss.cpu.coresCount;
    final usage = ss.disk.isEmpty ? null : DiskUsage.parse(ss.disk);
    return <ServerInfoRow>[
      if (ss.cpu.brand.keys.firstOrNull case final brand?)
        (k: 'CPU', v: brand, secret: false),
      if (cores > 0) (k: l10n.cores, v: '×$cores', secret: false),
      if (ss.mem.total > 0)
        (k: libL10n.memory, v: (ss.mem.total * 1024).bytes2Str, secret: false),
      if (ss.swap.total > 0)
        (k: 'Swap', v: (ss.swap.total * 1024).bytes2Str, secret: false),
      if (usage != null)
        (k: libL10n.disk, v: usage.size.kb2Str, secret: false),
      // What the machine has, not what it is doing with it: the load is the
      // GPU row above, and which cards are in the box belongs with the CPU
      // and the memory.
      if (ss.gpus.isNotEmpty) (k: 'GPU', v: _modelsOf(ss.gpus), secret: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: BuiltFrom([icon, title, ...rows], builder: _card),
    );
  }

  Widget _card(BuildContext context) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            UIs.height7,
            for (final row in rows)
              Padding(
                key: ValueKey('info-${row.k}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(row.k, style: UIs.text12Grey),
                    UIs.width13,
                    Expanded(
                      child: row.secret
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: SecretText(row.v),
                            )
                          : Text(
                              row.v,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UIs.text13,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How the app reaches this machine — the transport that leads, which is
/// the one a poll uses unless it fails over.
String _transportName(ServerState si) {
  return switch (si.spi.transport) {
    ServerTransport.monitorHttp => 'monitor',
    ServerTransport.ssh => 'SSH',
  };
}

/// The models in a set of cards, counted rather than repeated: two of the
/// same card is one line about a machine, and four lines of the same name is
/// four lines of nothing.
String _modelsOf(List<GpuItem> gpus) {
  final counts = <String, int>{};
  for (final gpu in gpus) {
    counts[gpu.name] = (counts[gpu.name] ?? 0) + 1;
  }
  return [
    for (final e in counts.entries) e.value > 1 ? '${e.key} ×${e.value}' : e.key,
  ].join(', ');
}

/// A value that is on screen only once someone asks for it.
///
/// A public address is not a secret — anything the server talks to already has
/// it — but it is the one line on this page that identifies the machine to
/// someone reading over a shoulder or watching a screen share, and it is on a
/// card people open for the uptime. Hidden by default costs one tap and
/// removes that.
///
/// **The row that holds this is keyed by its label**, because it is one child
/// of a list whose length is `ss.more.entries.length + 1`. Matched by index, a
/// later poll that adds a `more` entry lines it up against a different
/// subtree, the element is rebuilt from scratch, and an address the user
/// revealed hides itself again mid-session. By label rather than by value, so
/// that an address changing does not count as a different row — see
/// [ServerDetailInfoCard].
///
/// The placeholder has the same number of characters as the address, not the
/// same width — `•` is not the width of a digit in a proportional face, so
/// revealing does re-flow the row a little. Monospacing the placeholder alone
/// would swap that for a bullet run that does not look like the text it stands
/// for, which is worse on a card people are scanning.
class SecretText extends StatefulWidget {
  const SecretText(this.value, {super.key});

  final String value;

  @override
  State<SecretText> createState() => _SecretTextState();
}

class _SecretTextState extends State<SecretText> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _shown ? widget.value : '•' * widget.value.length,
          style: UIs.text13Grey,
          overflow: TextOverflow.ellipsis,
        ),
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 15,
          icon: Icon(
            _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          tooltip: _shown ? libL10n.close : libL10n.open,
          onPressed: () => setState(() => _shown = !_shown),
        ),
      ],
    );
  }
}

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';

/// Which machine to look at, when there are more of them than pills that fit.
///
/// The strip over an open card is the list itself and answers this for a
/// handful; past that it stops fitting, and what is wanted instead is exactly
/// what a long list wants — something to type into and the tags to group by.
///
/// Answers the chosen server's id, or null if the sheet was simply closed.
Future<String?> showServerSwitcher(
  BuildContext context, {
  required List<String> ids,
  required String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    // Above whatever navigator raised it: this is opened from a tab, and a
    // tab's own navigator would clip the sheet to the tab.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SwitcherSheet(ids: ids, current: current),
  );
}

class _SwitcherSheet extends ConsumerStatefulWidget {
  const _SwitcherSheet({required this.ids, required this.current});

  final List<String> ids;
  final String? current;

  @override
  ConsumerState<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends ConsumerState<_SwitcherSheet> {
  final _controller = TextEditingController();
  var _needle = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Name and address, as everywhere else this list is searched — and a `#`
  /// searches the tags instead, which is the one thing a list of servers is
  /// grouped by.
  bool _matches(ServerState srv) {
    if (_needle.isEmpty) return true;
    if (_needle.startsWith('#')) {
      final tag = _needle.substring(1);
      if (tag.isEmpty) return true;
      return srv.spi.tags?.any((t) => t.toLowerCase().contains(tag)) ?? false;
    }
    return srv.spi.name.toLowerCase().contains(_needle) ||
        srv.spi.displayAddr.toLowerCase().contains(_needle);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Grouped by tag, and a machine with several is under each of them: a tag
    // is not a folder, so putting it in only the first would hide it from the
    // others.
    final groups = <String, List<ServerState>>{};
    final untagged = <ServerState>[];
    for (final id in widget.ids) {
      final srv = ref.watch(serverProvider(id));
      if (!_matches(srv)) continue;
      final tags = srv.spi.tags;
      if (tags == null || tags.isEmpty) {
        untagged.add(srv);
        continue;
      }
      for (final tag in tags) {
        groups.putIfAbsent(tag, () => []).add(srv);
      }
    }
    final names = groups.keys.toList()..sort();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 9),
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13, height: 1),
                    // Off, or the field's own baseline makes the hint and the
                    // value sit at two different heights in a 34pt pill.
                    strutStyle: StrutStyle.disabled,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      hintText: '${libL10n.search} · #${libL10n.tag}',
                      hintStyle: const TextStyle(fontSize: 13, height: 1),
                      prefixIcon: const Icon(Icons.search, size: 17),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(17)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _needle = value.trim().toLowerCase()),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 17),
                  children: [
                    for (final name in names) ...[
                      _heading('#$name'),
                      for (final srv in groups[name]!) _row(srv),
                    ],
                    if (untagged.isNotEmpty) ...[
                      // Named rather than left as a gap at the end: a list
                      // with headings and then rows under no heading reads as
                      // the headings having run out.
                      if (names.isNotEmpty) _heading(libL10n.all),
                      for (final srv in untagged) _row(srv),
                    ],
                    if (names.isEmpty && untagged.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(26),
                        child: Text(
                          _needle,
                          textAlign: TextAlign.center,
                          style: UIs.text12Grey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 11, 17, 5),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(height: 1, color: Hairline.color(context)),
          ),
        ],
      ),
    );
  }

  Widget _row(ServerState srv) {
    final id = srv.spi.id;
    final current = id == widget.current;
    return ListTile(
      selected: current,
      dense: true,
      leading: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _dot(srv)),
      ),
      title: Text(srv.spi.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        srv.listLine ?? srv.spi.displayAddr,
        style: UIs.text11Grey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: current ? const Icon(Icons.check, size: 17) : null,
      onTap: () => Navigator.of(context).pop(id),
    );
  }

  Color _dot(ServerState srv) => switch (srv.conn) {
    ServerConn.finished =>
      serverCardReadings(srv).all.any((m) => m.over)
          ? StatePalette.warn
          : StatePalette.running,
    ServerConn.failed => StatePalette.failed,
    _ => StatePalette.idle,
  };
}

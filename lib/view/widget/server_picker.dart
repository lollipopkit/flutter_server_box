// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/sort.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/server_sort_rows.dart';

/// Which servers a picker offers, asked with the picker's own [ref] so an
/// answer read from a server's state follows it while the sheet is up.
typedef ServerFilter = bool Function(WidgetRef ref, Spi spi);

/// A row ahead of the servers that answers [value] rather than a server:
/// this device, every server.
final class ServerPickerExtra<T> {
  const ServerPickerExtra({
    required this.icon,
    required this.title,
    required this.value,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final T value;
  final bool selected;
}

/// What [pickServerOr] answers: a server, or one of its extra rows.
sealed class ServerPick<T> {
  const ServerPick();
}

final class PickedServer<T> extends ServerPick<T> {
  const PickedServer(this.spi);
  final Spi spi;
}

final class PickedExtra<T> extends ServerPick<T> {
  const PickedExtra(this.value);
  final T value;
}

/// Asks which server, in a sheet.
///
/// One implementation because a picker over this list is not a small thing:
/// somebody with thirty servers needs to search, somebody who groups by tag
/// needs the tags, and the order has to be the one they arranged rather than
/// whatever a caller happened to iterate. Every one of those was missing from
/// the first hand-rolled dropdown, and each would have been missing again from
/// the next one.
///
/// Returns the chosen server, or null if the sheet was dismissed.
///
/// [where] narrows the servers offered; the order stays the user's.
/// [trailingOf] marks a row with something only the caller knows — a benchmark
/// in flight, a transfer in progress. The tick for [selectedId] is drawn
/// regardless.
Future<Spi?> pickServer(
  BuildContext context, {
  String? title,
  ServerFilter? where,
  String? selectedId,
  Widget? Function(Spi spi)? trailingOf,
}) async {
  final pick = await pickServerOr<Never>(
    context,
    title: title,
    where: where,
    selectedId: selectedId,
    trailingOf: trailingOf,
  );
  return switch (pick) {
    PickedServer(:final spi) => spi,
    _ => null,
  };
}

/// [pickServer] with [extras] listed ahead of the servers.
///
/// Null only when dismissed.
Future<ServerPick<T>?> pickServerOr<T>(
  BuildContext context, {
  String? title,
  ServerFilter? where,
  String? selectedId,
  Widget? Function(Spi spi)? trailingOf,
  List<ServerPickerExtra<T>> extras = const [],
}) {
  // The list is as long as the user's server list, and there is a search
  // field in it — so it can take the window.
  return showResizableSheet<ServerPick<T>>(
    context,
    builder: (_) => _ServerPickerSheet(
      title: title,
      where: where,
      trailingOf: trailingOf,
      single: _Single(
        selectedId: selectedId,
        answerOf: PickedServer<T>.new,
        extras: [
          for (final e in extras)
            (
              icon: e.icon,
              title: e.title,
              selected: e.selected,
              answer: PickedExtra<T>(e.value),
            ),
        ],
      ),
    ),
  );
}

/// Asks which servers, ticked in a sheet and confirmed by OK.
///
/// Null when dismissed; a list, possibly empty, once confirmed. Without
/// [clearable] the last ticked server cannot be unticked. Ids in [initial]
/// that [where] does not offer are left out of the answer.
Future<List<Spi>?> pickServers(
  BuildContext context, {
  String? title,
  ServerFilter? where,
  Iterable<String> initial = const [],
  bool clearable = false,
  List<Widget> actions = const [],
}) {
  return showResizableSheet<List<Spi>>(
    context,
    builder: (_) => _ServerPickerSheet(
      title: title,
      where: where,
      multi: _Multi(initial: initial.toSet(), clearable: clearable, actions: actions),
    ),
  );
}

typedef _ExtraRow = ({IconData icon, String title, bool selected, Object answer});

final class _Single {
  const _Single({required this.selectedId, required this.answerOf, required this.extras});

  final String? selectedId;
  final Object Function(Spi spi) answerOf;
  final List<_ExtraRow> extras;
}

final class _Multi {
  const _Multi({required this.initial, required this.clearable, required this.actions});

  final Set<String> initial;
  final bool clearable;
  final List<Widget> actions;
}

class _ServerPickerSheet extends ConsumerStatefulWidget {
  const _ServerPickerSheet({this.title, this.where, this.trailingOf, this.single, this.multi})
    : assert((single == null) != (multi == null));

  final String? title;
  final ServerFilter? where;
  final Widget? Function(Spi spi)? trailingOf;
  final _Single? single;
  final _Multi? multi;

  @override
  ConsumerState<_ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends ConsumerState<_ServerPickerSheet> {
  final _searchCtrl = TextEditingController();
  var _needle = '';
  var _tag = TagSwitcher.kDefaultTag;

  /// The tag list is a `ValueNotifier` because `TagSwitcher` takes one.
  final _tags = ValueNotifier(<String>{});

  /// Held so its own preferred height can bound it — see where it is used.
  late TagSwitcher _tagSwitcher;

  /// Ticked ids, for [_ServerPickerSheet.multi].
  late final _chosen = {...?widget.multi?.initial};

  /// The servers offered, in order, as of the last build.
  var _all = const <Spi>[];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    final byId = {for (final spi in Stores.server.fetch()) spi.id: spi};

    // The arrangement the user made, viewed however their sort setting says —
    // the same call the server tab makes, so the two lists never disagree.
    // Per tag, as there: the order under a tag is the one the tab shows
    // under it.
    final sort = ServerSortOrder.of(_tag);
    // Watched for an order that reads a machine's state, as the tab does: a
    // reading that changes while this is open moves the row.
    final sorted = sort.apply(
      order,
      byId,
      (id) => sort.field.readsStatus
          ? ref.watch(serverProvider(id))
          : ref.read(serverProvider(id)),
    );

    final where = widget.where;
    _all = [
      for (final id in sorted)
        if (byId[id] case final spi? when where == null || where(ref, spi)) spi,
    ];

    // Assigned after the frame and only when it actually differs. Writing a
    // `ValueNotifier` during build notifies its listeners mid-build, and a
    // fresh `Set` is never equal to the last one — so assigning unconditionally
    // told the switcher to rebuild on every frame, forever.
    final tags = {for (final spi in _all) ...?spi.tags};
    if (!setEquals(_tags.value, tags)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tags.value = tags;
      });
    }

    final shown = [
      for (final spi in _all)
        if (_matchesTag(spi) && _matchesNeedle(spi)) spi,
    ];
    // Rows with fixed names: under a filter they would read as results.
    final extras = _needle.isEmpty && _tag == TagSwitcher.kDefaultTag
        ? widget.single?.extras ?? const <_ExtraRow>[]
        : const <_ExtraRow>[];

    _tagSwitcher = TagSwitcher(
      tags: _tags,
      initTag: _tag,
      onTagChanged: (tag) => setState(() => _tag = tag),
      singleLine: true,
    );

    return SheetScaffold(
      title: switch (widget.title) {
        final title? => Text(title),
        null => null,
      },
      contentPadding: EdgeInsets.zero,
      actions: switch (widget.multi) {
        final multi? => [
          ...multi.actions,
          TextButton(onPressed: _confirm, child: Text(libL10n.ok)),
        ],
        null => null,
      },
      headerPadding: EdgeInsets.zero,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearch(),
          // Height-bounded: on one line `TagSwitcher` is a horizontal
          // `ListView`, and a horizontal viewport in a `Column` has no height
          // to expand into. It carries its own — it is built to be an app
          // bar's `bottom`.
          if (tags.isNotEmpty)
            SizedBox(
              height: _tagSwitcher.preferredSize.height,
              child: _tagSwitcher,
            ),
        ],
      ),
      child: shown.isEmpty && extras.isEmpty
          ? Center(child: Text(libL10n.empty, style: UIs.textGrey))
          : _buildList(extras, shown),
    );
  }

  /// Name, tags and address, because a server is remembered by whichever of
  /// them the person happens to hold on to.
  bool _matchesNeedle(Spi spi) {
    if (_needle.isEmpty) return true;
    if (spi.name.toLowerCase().contains(_needle)) return true;
    if (spi.id.toLowerCase().contains(_needle)) return true;
    if (spi.tags?.any((t) => t.toLowerCase().contains(_needle)) ?? false) {
      return true;
    }
    return _addrOf(spi).toLowerCase().contains(_needle);
  }

  /// This device has no address of its own; one parked in its settings is
  /// another machine's.
  static String _addrOf(Spi spi) =>
      spi.local ? 'localhost' : spi.ssh?.ip ?? spi.monitor?.addr ?? '';

  bool _matchesTag(Spi spi) =>
      _tag == TagSwitcher.kDefaultTag || (spi.tags?.contains(_tag) ?? false);
}

extension _Actions on _ServerPickerSheetState {
  bool _isSelected(Spi spi) => switch (widget.multi) {
    null => spi.id == widget.single?.selectedId,
    _ => _chosen.contains(spi.id),
  };

  void _onTap(Spi spi) {
    if (widget.single case final single?) {
      context.pop(single.answerOf(spi));
      return;
    }
    final on = _chosen.contains(spi.id);
    final last = _all.where((s) => _chosen.contains(s.id)).length == 1;
    if (on && last && !widget.multi!.clearable) return;
    setState(() => on ? _chosen.remove(spi.id) : _chosen.add(spi.id));
  }

  void _confirm() => context.pop([
    for (final spi in _all)
      if (_chosen.contains(spi.id)) spi,
  ]);
}

extension _Widgets on _ServerPickerSheetState {
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 7),
      child: Row(
        children: [
          Expanded(
            child: Input(
              controller: _searchCtrl,
              hint: libL10n.search,
              icon: Icons.search,
              suggestion: false,
              noWrap: true,
              onChanged: (v) => setState(() => _needle = v.trim().toLowerCase()),
            ),
          ),
          IconButton(
            icon: Icon(ServerSortOrder.of(_tag).icon),
            tooltip: libL10n.sort,
            onPressed: _showSort,
          ),
        ],
      ),
    );
  }

  /// The server tab's own setting: one answer for both lists.
  Future<void> _showSort() => showRowsSheet<void>(
    context,
    rows: (ctx) => serverSortRows(ctx, _tag, () {
      if (mounted) setState(() {});
    }),
  );

  Widget _buildList(List<_ExtraRow> extras, List<Spi> shown) {
    final divided = extras.isNotEmpty && shown.isNotEmpty;
    final lead = extras.length + (divided ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      itemCount: lead + shown.length,
      itemBuilder: (_, i) {
        if (i < extras.length) return _buildExtra(extras[i]);
        if (i < lead) return const Divider(height: 1);
        return _buildTile(shown[i - lead]);
      },
    );
  }

  Widget _buildExtra(_ExtraRow extra) {
    return ListTile(
      leading: Icon(extra.icon),
      title: Text(extra.title, style: UIs.text15),
      selected: extra.selected,
      trailing: extra.selected ? _tick() : null,
      onTap: () => context.pop(extra.answer),
    );
  }

  Widget _buildTile(Spi spi) {
    final selected = _isSelected(spi);
    final trailing = widget.trailingOf?.call(spi);
    // Null rather than an empty box when marks are off — see [distIcon]: a
    // zero-sized widget still reserves the whole leading column.
    final mark = distIcon(spi.id);

    return ListTile(
      leading: mark,
      title: Text(
        spi.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text15,
      ),
      subtitle: Text(
        [
          _ServerPickerSheetState._addrOf(spi),
          ...?spi.tags,
        ].where((e) => e.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.text12Grey,
      ),
      selected: selected,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          if (selected) _tick(),
        ],
      ),
      onTap: () => _onTap(spi),
    );
  }

  Widget _tick() => Icon(Icons.check, color: Theme.of(context).colorScheme.primary);
}

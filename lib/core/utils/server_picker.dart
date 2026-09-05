// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/dist_icon.dart';

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
/// [trailingOf] marks a row with something only the caller knows — a benchmark
/// in flight, a transfer in progress. The tick for [selectedId] is drawn
/// regardless.
Future<Spi?> pickServer(
  BuildContext context, {
  String? selectedId,
  Widget? Function(Spi spi)? trailingOf,
}) {
  return showModalBottomSheet<Spi>(
    context: context,
    // Above whatever navigator raised it: these are raised from tabs, and a
    // tab's own navigator would clip the sheet to the tab.
    useRootNavigator: true,
    useSafeArea: true,
    // The list is as long as the user's server list, and there is a search
    // field in it — so it has to be able to take the height, and to move out
    // of the keyboard's way.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _ServerPickerSheet(
        selectedId: selectedId,
        trailingOf: trailingOf,
      ),
    ),
  );
}

class _ServerPickerSheet extends ConsumerStatefulWidget {
  const _ServerPickerSheet({this.selectedId, this.trailingOf});

  final String? selectedId;
  final Widget? Function(Spi spi)? trailingOf;

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
    final sorted = ServerSortOrder.stored.apply(
      order,
      byId,
      (id) => ref.read(serverProvider(id)).conn,
    );

    final all = [for (final id in sorted) ?byId[id]];

    // Assigned after the frame and only when it actually differs. Writing a
    // `ValueNotifier` during build notifies its listeners mid-build, and a
    // fresh `Set` is never equal to the last one — so assigning unconditionally
    // told the switcher to rebuild on every frame, forever.
    final tags = {for (final spi in all) ...?spi.tags};
    if (!setEquals(_tags.value, tags)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tags.value = tags;
      });
    }

    final shown = [
      for (final spi in all)
        if (_matchesTag(spi) && _matchesNeedle(spi)) spi,
    ];

    _tagSwitcher = TagSwitcher(
      tags: _tags,
      initTag: _tag,
      onTagChanged: (tag) => setState(() => _tag = tag),
      singleLine: true,
    );

    return Column(
      children: [
        _buildSearch(),
        // Height-bounded: on one line `TagSwitcher` is a horizontal `ListView`,
        // and a horizontal viewport in a `Column` has no height to expand into.
        // It carries its own — it is built to be an app bar's `bottom`.
        if (tags.isNotEmpty)
          SizedBox(
            height: _tagSwitcher.preferredSize.height,
            child: _tagSwitcher,
          ),
        Expanded(
          child: shown.isEmpty
              ? Center(child: Text(libL10n.empty, style: UIs.textGrey))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _buildTile(shown[i]),
                ),
        ),
      ],
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
    final addr = spi.ssh?.ip ?? spi.monitor?.addr ?? '';
    return addr.toLowerCase().contains(_needle);
  }

  bool _matchesTag(Spi spi) =>
      _tag == TagSwitcher.kDefaultTag || (spi.tags?.contains(_tag) ?? false);
}

extension _Widgets on _ServerPickerSheetState {
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 7),
      child: Input(
        controller: _searchCtrl,
        hint: libL10n.search,
        icon: Icons.search,
        suggestion: false,
        noWrap: true,
        onChanged: (v) => setState(() => _needle = v.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildTile(Spi spi) {
    final selected = spi.id == widget.selectedId;
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
          spi.ssh?.ip ?? spi.monitor?.addr ?? '',
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
          if (selected)
            Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
        ],
      ),
      onTap: () => context.pop(spi),
    );
  }
}

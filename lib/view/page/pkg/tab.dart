// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/pkg_updates.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/pkg/page.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// Which machines are behind on their packages, and what each one is behind on.
///
/// **The list is the tab, in both layouts.** Every other two-column tab here
/// answers "do this to one thing"; this one answers "which of them needs
/// attention", and the answer is the column of counts. So the narrow layout
/// keeps the list and pushes the machine's own page, rather than making the
/// list a sheet behind a button the way the benchmark and Agent tabs do — what
/// a single-column window would gain there it loses here, because the list is
/// what somebody opened the tab to read.
///
/// A tab rather than only a card on each server's page, for the reason the
/// card cannot cover: a fleet is behind on updates one machine at a time, and
/// visiting nine detail pages to find the one is how it stays that way.
class PkgTabPage extends ConsumerStatefulWidget {
  const PkgTabPage({super.key});

  @override
  ConsumerState<PkgTabPage> createState() => _PkgTabPageState();
}

class _PkgTabPageState extends ConsumerState<PkgTabPage> {
  /// The machine the right column is showing, or null for none.
  ///
  /// Null while the root is showing, which is what `NestedNavigator` reads as
  /// the detail closing — an id that is never null makes every return one
  /// non-null id replacing another, which is a way *in*, and the pane slides
  /// off the wrong edge.
  String? _viewingId;

  final _search = InlineSearchController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Every server, in the order the server tab shows them.
  ///
  /// Not filtered by whether a reading has arrived: a machine that has not
  /// been polled yet is exactly the one worth showing as unknown, and dropping
  /// it would make the list shorter the less the app knows.
  List<Spi> get _servers {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    final byId = {for (final spi in Stores.server.fetch()) spi.id: spi};
    return [
      for (final id in order) ?byId[id],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
        detailId: _viewingId,
        onCloseDetail: () => setState(() => _viewingId = null),
        detailBuilder: (_) => _buildDetail(),
        listBuilder: (_, split) => _buildList(servers, split),
      );
    });
  }
}

// --- Widgets ---

extension _Widgets on _PkgTabPageState {
  Widget _buildList(List<Spi> servers, bool split) {
    return ListenBuilder(
      listenable: _search,
      builder: () => _buildListWith(servers, split),
    );
  }

  Widget _buildListWith(List<Spi> servers, bool split) {
    final needle = _search.needle;
    final shown = [
      for (final spi in servers)
        if (needle.isEmpty || spi.name.toLowerCase().contains(needle)) spi,
    ];

    return Scaffold(
      // No title: the nav rail beside this already names the tab. An explicit
      // leading because `CustomAppBar` otherwise supplies a back button wired
      // to `onCloseDetail`, and this column is not a detail — it is the thing
      // a detail is closed back to.
      appBar: CustomAppBar(
        leading: const SizedBox.shrink(),
        title: InlineSearchBar(
          controller: _search,
          hint: libL10n.server,
          child: const SizedBox.shrink(),
        ),
        actions: [
          Btn.icon(
            text: libL10n.search,
            icon: const Icon(Icons.search, size: 18),
            onTap: _search.start,
          ),
        ],
      ),
      body: shown.isEmpty
          ? Center(child: Text(libL10n.empty, style: UIs.textGrey))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final spi = shown[i];
                return _ServerTile(
                  key: ValueKey(spi.id),
                  spi: spi,
                  selected: split && _viewingId == spi.id,
                  onTap: () => _open(spi, split),
                );
              },
            ),
    );
  }

  /// The right column.
  ///
  /// A widget with its own `ref`, not a `ref.watch` here: this method runs on
  /// the pane's element rather than the page's, and watching from it would
  /// subscribe the wrong one — which is not an error, only wrong.
  Widget _buildDetail() {
    final id = _viewingId;
    if (id == null) {
      return const EmptyPane(icon: Icons.system_update_alt_outlined);
    }
    return PkgUpdatesPage(
      key: ValueKey(id),
      args: PkgUpdatesPageArgs(serverId: id),
      inPane: true,
    );
  }
}

// --- Actions ---

extension _Actions on _PkgTabPageState {
  /// The right column when there is one, a pushed page when there is not.
  ///
  /// Pushed on this tab's own navigator, so back returns to the list and the
  /// bottom bar stays put — the same scope every other tab's detail uses.
  void _open(Spi spi, bool split) {
    if (split) {
      setState(() => _viewingId = spi.id);
      return;
    }
    PkgUpdatesPage.route.go(
      context,
      args: PkgUpdatesPageArgs(serverId: spi.id),
    );
  }
}

/// One machine's row: what it runs, and how far behind it is.
///
/// Its own consumer so the list rebuilds a row at a time. The whole list
/// watching every server would rebuild all of them on every poll of any one,
/// which on a page whose only content is a count per machine is the page.
class _ServerTile extends ConsumerWidget {
  const _ServerTile({
    super.key,
    required this.spi,
    required this.selected,
    required this.onTap,
  });

  final Spi spi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverProvider(spi.id));
    final pkg = state.status.pkg;

    return CardX(
      child: ListTile(
        selected: selected,
        leading: DistIcon(spi.id, size: 27),
        title: Text(spi.name, style: UIs.text15),
        subtitle: Text(_subtitle(pkg), style: UIs.text12Grey),
        trailing: _PkgSummary(pkg: pkg),
        onTap: onTap,
      ),
    );
  }

  /// What the row says under the name.
  ///
  /// The manager and the index's age, because between them they are why the
  /// count is what it is. A machine reporting none off a five-month-old index
  /// is not up to date; it is unasked, and the row is where that has to show —
  /// the count beside it says the opposite.
  String _subtitle(PkgUpdates pkg) {
    if (!pkg.supported) return l10n.pkgNoManager;
    final parts = [
      pkg.manager,
      if (pkg.indexAge case final age?) l10n.pkgIndexAge(age.toAgoStr),
    ];
    return parts.join(' · ');
  }
}

/// The count, with its security half told apart.
///
/// A single number reads as one thing to deal with; two say which part cannot
/// wait. The security half is omitted rather than shown as zero where the
/// manager cannot tell — see [PkgUpdates.security].
class _PkgSummary extends StatelessWidget {
  const _PkgSummary({required this.pkg});

  final PkgUpdates pkg;

  @override
  Widget build(BuildContext context) {
    if (!pkg.supported) {
      return const Icon(Icons.remove, size: 17, color: Colors.grey);
    }
    if (pkg.total == 0) {
      // Orange where the index is old: zero is the count a stale index
      // misleads about most, and this row is the whole of what the tab says
      // about that machine.
      return Icon(
        pkg.stale ? Icons.help_outline : Icons.check_circle_outline,
        size: 19,
        color: pkg.stale ? Colors.orange : Colors.green,
      );
    }

    final security = pkg.security ?? 0;
    final urgent = security > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        if (urgent)
          const Icon(Icons.shield_outlined, size: 17, color: Colors.orange),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: (urgent ? Colors.orange : UIs.primaryColor).withValues(
              alpha: 0.17,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '${pkg.total}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: urgent ? Colors.orange : UIs.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

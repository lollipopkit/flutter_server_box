// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/pkg_updates.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/pkg_hook.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/pkg/page.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';

/// Which machines are behind on their packages, and what each one is behind on.
///
/// The terminal tab's shape, which is what every tab holding one of a set uses:
/// a rail that is always there beside a surface, and on a narrow window the
/// surface alone with the rail's contents behind the switcher in its bar. Not
/// the benchmark tab's — there the list is a history of records and the single
/// column is the run, where here the list *is* the subject and a machine is
/// what you open out of it.
///
/// A tab rather than only a card on each server's page, for the reason the card
/// cannot cover: a fleet is behind on updates one machine at a time, and
/// visiting nine detail pages to find the one is how it stays that way.
class PkgTabPage extends ConsumerStatefulWidget {
  const PkgTabPage({super.key});

  @override
  ConsumerState<PkgTabPage> createState() => _PkgTabPageState();
}

class _PkgTabPageState extends ConsumerState<PkgTabPage>
    with PkgHookOnEnter<PkgTabPage> {
  /// Every machine: the tab's whole content is a count per one, so a reading
  /// that has not been taken is a row that says nothing.
  @override
  PkgHookScope get pkgHookScope => PkgHookScope.fleet;

  /// The machine the surface is showing, or null for the overview.
  ///
  /// Null is a real state and not an unset one: with two columns it is the
  /// empty pane, and with one it is the list of every machine — which is what
  /// somebody opening this tab came to read.
  String? _selectedId;

  /// The rail's search. The same controller every other tab that searches
  /// uses, so the field arrives and leaves the same way here as there.
  final _search = InlineSearchController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Every server, in the order the server tab shows them.
  ///
  /// Not filtered by whether a reading has arrived: a machine that has not been
  /// polled yet is exactly the one worth showing as unknown, and dropping it
  /// would make the list shorter the less the app knows.
  List<Spi> get _servers {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    final byId = {for (final spi in Stores.server.fetch()) spi.id: spi};
    return [
      for (final id in order) ?byId[id],
    ];
  }

  Spi? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    return _servers.firstWhereOrNull((s) => s.id == id);
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    return SbPaneList(
      // There from the start, empty surface or not: folding it away until a
      // machine was chosen would greet a wide window with a full-width list and
      // then rearrange itself into a rail the moment one was — two layouts for
      // one page, the first of which is not what the page looks like.
      sideBuilder: (_) => _buildRail(servers),
      builder: (_, split) => _buildSurface(servers, split),
    );
  }
}

// --- Widgets ---

extension _Widgets on _PkgTabPageState {
  /// The left column: every machine, compactly.
  ///
  /// [SideBarTile] rather than the cards the full-width list uses. A column
  /// this narrow is an index — you are reading down it for a name — and a card
  /// per row spends most of the width on its own edges.
  Widget _buildRail(List<Spi> servers) {
    return ListenBuilder(
      listenable: _search,
      builder: () {
        final shown = _filtered(servers);
        // Its own, rather than the one the home page's `Scaffold` happens to
        // put above every tab: the rows are ink responses, and a column that
        // only works inside a particular ancestor fails as a red screen rather
        // than as a compile error. Transparent, so the rail keeps the pane's
        // background and looks like the other tabs' rails.
        return Material(
          type: MaterialType.transparency,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              SideBarActions(
                search: _search,
                actions: [
                  Btn.icon(
                    text: libL10n.search,
                    icon: const Icon(Icons.search, size: 18),
                    onTap: _search.start,
                  ),
                ],
              ),
              for (final spi in shown)
                _ServerTile(
                  key: ValueKey(spi.id),
                  spi: spi,
                  compact: true,
                  selected: _selectedId == spi.id,
                  onTap: () => _select(spi.id),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The right column, or the whole tab where there is only one.
  Widget _buildSurface(List<Spi> servers, bool split) {
    final spi = _selected;

    if (spi == null) {
      // Two columns: the rail beside this is already the list, and drawing it
      // twice is what a grid of cards next to an index would be.
      if (split) {
        return const EmptyPane(icon: Icons.system_update_alt_outlined);
      }
      return _buildOverview(servers);
    }

    return PkgUpdatesPage(
      key: ValueKey(spi.id),
      args: PkgUpdatesPageArgs(serverId: spi.id),
      inPane: true,
      // With a rail beside it the rail says which machine is on screen and how
      // to reach another, so the page needs no switcher of its own. With one
      // column it is the only way there is.
      leading: split
          ? null
          : SessionSwitcherLabel(
              name: spi.name,
              icon: Icons.system_update_alt_outlined,
              onTap: () => _showListSheet(servers),
            ),
    );
  }

  /// The whole tab, when there is only room for one column and nothing is
  /// open. The same rows the rail has, at full width, where a card reads
  /// better than an index line.
  Widget _buildOverview(List<Spi> servers) {
    return ListenBuilder(
      listenable: _search,
      builder: () => _buildOverviewWith(servers, inSheet: false),
    );
  }

  Widget _buildOverviewWith(List<Spi> servers, {required bool inSheet}) {
    final shown = _filtered(servers);
    return Scaffold(
      // No title: the nav rail beside this already names the tab. An explicit
      // leading because `CustomAppBar` otherwise supplies a back button wired
      // to `onCloseDetail`, and this column is not a detail — it is the thing a
      // detail is closed back to. In the sheet the way out is dragging it away
      // or the control that opened it; a back arrow there would be a third
      // answer to a question already answered twice.
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
                  compact: false,
                  selected: _selectedId == spi.id,
                  onTap: () {
                    if (inSheet) context.popDialog();
                    _select(spi.id);
                  },
                );
              },
            ),
    );
  }

  List<Spi> _filtered(List<Spi> servers) {
    final needle = _search.needle;
    if (needle.isEmpty) return servers;
    return [
      for (final spi in servers)
        if (spi.name.toLowerCase().contains(needle)) spi,
    ];
  }
}

// --- Actions ---

extension _Actions on _PkgTabPageState {
  void _select(String id) => setState(() => _selectedId = id);

  /// The list, for the layout that has no column to put it in.
  ///
  /// The same rows in a sheet — the Agent and benchmark tabs do this for the
  /// same reason. Tall, because it is a list of machines rather than a short
  /// set of choices, and it carries the counts, which is what makes choosing
  /// from it the same act as reading the overview.
  Future<void> _showListSheet(List<Spi> servers) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ListenBuilder(
          listenable: _search,
          builder: () => _buildOverviewWith(servers, inSheet: true),
        ),
      ),
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
    required this.compact,
  });

  final Spi spi;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverProvider(spi.id));
    final pkg = state.status.pkg;

    if (compact) {
      return SideBarTile(
        title: spi.name,
        selected: selected,
        leading: DistIcon(spi.id, size: 17),
        trailing: _PkgSummary(pkg: pkg),
        onTap: onTap,
      );
    }

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
  ///
  /// Only at full width. A rail line has room for a name and a number, and
  /// what it leaves out is a tap away in the page it opens.
  String _subtitle(PkgUpdates pkg) {
    if (!pkg.supported) return l10n.pkgNoManager;
    return [
      pkg.manager,
      if (pkg.indexAge case final age?) l10n.pkgIndexAge(age.toAgoStr),
    ].join(' · ');
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
      // Orange where the index is old: zero is the count a stale index misleads
      // about most, and this row is the whole of what the tab says about that
      // machine.
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

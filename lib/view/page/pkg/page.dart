import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/pkg_updates.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/pkg_hook.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

/// Every pending update on one machine.
///
/// **Keyed by a server id rather than handed a reading.** It is opened from
/// three places — the detail card's "more", the updates tab's pane, and the
/// same tab pushed on a narrow window — and a reading passed in would be the
/// one that existed at the moment of the tap. A poll lands every few seconds
/// and an extended run every few minutes, so a snapshot goes stale while it is
/// being read, and the "upgrade" button under it would offer a command for a
/// list the machine no longer has.
class PkgUpdatesPage extends ConsumerStatefulWidget {
  const PkgUpdatesPage({
    super.key,
    this.args,
    this.inPane = false,
    this.leading,
  });

  final PkgUpdatesPageArgs? args;

  /// Whether it is a column of the updates tab rather than a page.
  ///
  /// A pane has the tab's own way back and the rail beside it, so a back
  /// button here would be a second answer to a question already answered.
  final bool inPane;

  /// The switcher that leads the bar, for the layout with no rail.
  ///
  /// A `SessionSwitcherLabel` when this is the whole of a narrow window: it is
  /// the only thing on screen saying which of the set is showing and the only
  /// way to another. With a rail beside it the rail says both, and this is
  /// null.
  ///
  /// Given here rather than as an `AppBar.leading`, because that slot is one
  /// toolbar height wide and a switcher is a name — it overflows. Non-null
  /// replaces the whole bar with the terminal tab's: the switcher in an
  /// `Expanded` on the left, this page's own actions on the right.
  final Widget? leading;

  static const route = AppRoute<void, PkgUpdatesPageArgs>(
    page: PkgUpdatesPage.new,
    path: '/server/pkg',
  );

  @override
  ConsumerState<PkgUpdatesPage> createState() => _PkgUpdatesPageState();
}

class _PkgUpdatesPageState extends ConsumerState<PkgUpdatesPage>
    with PkgHookOnEnter<PkgUpdatesPage> {
  /// This one machine. Asked again on the way in even when the tab already
  /// did: a page opened minutes later is looking at a reading minutes old, and
  /// the notifier refuses a second collection while one is in flight anyway.
  @override
  PkgHookScope get pkgHookScope => PkgHookScope.server;

  @override
  String? get pkgHookServerId => widget.args?.serverId;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    if (args == null) return const Scaffold(body: SizedBox.shrink());

    final state = ref.watch(serverProvider(args.serverId));
    final spi = state.spi;
    final pkg = state.status.pkg;

    final query = _search.text.trim().toLowerCase();
    final items = [
      // Security first: it is the only ordering anybody reads this list for,
      // and the manager's own order carries no meaning.
      ...pkg.items.where((i) => i.security),
      ...pkg.items.where((i) => !i.security),
    ].where((i) => query.isEmpty || i.name.toLowerCase().contains(query)).toList();

    final actions = [
      if (pkg.upgradeCommand != null)
        Btn.icon(
          icon: const Icon(Icons.terminal, size: 18),
          text: l10n.pkgUpgrade,
          onTap: () => openPkgUpgrade(context, spi, pkg),
        ),
    ];

    return Scaffold(
      appBar: switch (widget.leading) {
        // The terminal tab's bar, in shape as well as in detail: the switcher
        // on the left saying which of the set is on screen and opening the
        // rest, the other ways out as actions on the right at 18pt.
        final leading? => PreferredSize(
          preferredSize: const Size.fromHeight(SessionTabBar.height),
          child: SizedBox(
            height: SessionTabBar.height,
            child: Row(
              children: [
                Expanded(child: leading),
                ...actions,
                const SizedBox(width: 7),
              ],
            ),
          ),
        ),
        // The rail is to the left of this and the tab bar above it; a back
        // arrow in a pane would have nowhere to go. `SizedBox.shrink` is how
        // `CustomAppBar` is told to supply none.
        _ => CustomAppBar(
          leading: widget.inPane ? const SizedBox.shrink() : null,
          title: Text(widget.inPane ? spi.name : l10n.pkgUpdates),
          actions: actions,
        ),
      },
      body: Column(
        children: [
          _Header(pkg: pkg),
          if (pkg.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 7),
              child: Input(
                controller: _search,
                hint: libL10n.search,
                icon: Icons.search,
                onChanged: (_) => setState(() {}),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      // Three states, and they are not the same thing: a
                      // machine with no manager this build can read, one that
                      // is up to date, and a search that matched nothing.
                      !pkg.supported
                          ? l10n.pkgNoManager
                          : (pkg.items.isEmpty
                                ? l10n.pkgUpToDate
                                : libL10n.empty),
                      style: UIs.textGrey,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 27),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _Item(item: items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pkg});

  final PkgUpdates pkg;

  @override
  Widget build(BuildContext context) {
    if (!pkg.supported) return UIs.placeholder;
    final security = pkg.security;
    final parts = [
      '${pkg.total} · ${pkg.manager}',
      // Null is not zero, and the difference is the point: only some managers
      // name the archive an update comes from.
      if (security != null && security > 0) l10n.pkgSecurityCount(security),
      if (security == null) l10n.pkgSecurityUnknown(pkg.manager),
      if (pkg.indexAge case final age?) l10n.pkgIndexAge(age.toAgoStr),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 11, 17, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 3,
        children: [
          Text(parts.join(' · '), style: UIs.text12Grey),
          if (pkg.stale)
            Text(
              l10n.pkgIndexStale(pkg.indexAge!.toAgoStr),
              style: UIs.text12Grey.copyWith(color: Colors.orange),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final PkgUpdate item;

  @override
  Widget build(BuildContext context) {
    final from = item.from;
    return ListTile(
      dense: true,
      leading: item.security
          ? const Icon(Icons.shield_outlined, size: 19, color: Colors.orange)
          : Icon(ServerDetailCards.pkg.icon, size: 19, color: Colors.grey),
      title: Text(item.name, style: UIs.text13),
      subtitle: Text(
        [from == null ? item.to : '$from → ${item.to}', ?item.repo].join(
          '  ·  ',
        ),
        style: UIs.text12Grey,
      ),
    );
  }
}

class PkgUpdatesPageArgs {
  const PkgUpdatesPageArgs({required this.serverId});

  final String serverId;
}

/// Opens a terminal with the upgrade command typed and **not sent**.
///
/// The one place that decides this, so the card, the page and the tab cannot
/// disagree. Typed rather than run because the managers disagree about whether
/// they ask first: `apt` and `dnf` print a plan and wait, `apk upgrade` and
/// `brew upgrade` just do it. Leaving the line in the prompt makes the promise
/// the same on every server, and leaves it editable — which matters, because
/// `sudo` may not be installed or permitted.
void openPkgUpgrade(BuildContext context, Spi spi, PkgUpdates pkg) {
  final cmd = pkg.upgradeCommand;
  if (cmd == null) return;
  SSHPage.route.go(
    context,
    SshPageArgs(source: ServerSource(spi), initCmd: cmd, initCmdRun: false),
  );
}

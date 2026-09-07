import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/pkg_updates.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

/// Every pending update, where the detail card shows the first few.
///
/// A page rather than a taller card: a machine that has not been touched in a
/// month has hundreds, and a card that grows to hold them pushes everything
/// else on the detail page off the bottom.
class PkgUpdatesPage extends StatefulWidget {
  const PkgUpdatesPage({super.key, this.args});

  final PkgUpdatesPageArgs? args;

  static const route = AppRoute<void, PkgUpdatesPageArgs>(
    page: PkgUpdatesPage.new,
    path: '/server/pkg',
  );

  @override
  State<PkgUpdatesPage> createState() => _PkgUpdatesPageState();
}

class _PkgUpdatesPageState extends State<PkgUpdatesPage> {
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
    final pkg = args.pkg;

    final query = _search.text.trim().toLowerCase();
    final items = [
      // Security first, as on the card: it is the only ordering anybody reads
      // this list for, and the manager's own order carries no meaning.
      ...pkg.items.where((i) => i.security),
      ...pkg.items.where((i) => !i.security),
    ].where((i) => query.isEmpty || i.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.pkgUpdates),
        actions: [
          if (pkg.upgradeCommand != null)
            Btn.icon(
              icon: const Icon(Icons.terminal, size: 18),
              text: l10n.pkgUpgrade,
              onTap: () => openPkgUpgrade(context, args.spi, pkg),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 7, 13, 0),
            child: Input(
              controller: _search,
              hint: libL10n.search,
              icon: Icons.search,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _Header(pkg: pkg),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(libL10n.empty, style: UIs.textGrey))
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
    final security = pkg.security;
    final lines = [
      '${pkg.total} · ${pkg.manager}',
      // Null is not zero, and the difference is the whole point: only some
      // managers name the archive an update comes from.
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
          Text(lines.join(' · '), style: UIs.text12Grey),
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
        [
          from == null ? item.to : '$from → ${item.to}',
          ?item.repo,
        ].join('  ·  '),
        style: UIs.text12Grey,
      ),
    );
  }
}

class PkgUpdatesPageArgs {
  const PkgUpdatesPageArgs({required this.spi, required this.pkg});

  final Spi spi;
  final PkgUpdates pkg;
}

/// Opens a terminal with the upgrade command typed and **not sent**.
///
/// The one place that decides this, so the card and the page cannot disagree.
/// Typed rather than run because the managers disagree about whether they ask
/// first: `apt` and `dnf` print a plan and wait, `apk upgrade` and `brew
/// upgrade` just do it. Leaving the line in the prompt makes the promise the
/// same on every server, and leaves it editable — which matters, because
/// `sudo` may not be installed or permitted.
void openPkgUpgrade(BuildContext context, Spi spi, PkgUpdates pkg) {
  final cmd = pkg.upgradeCommand;
  if (cmd == null) return;
  SSHPage.route.go(
    context,
    SshPageArgs(
      source: ServerSource(spi),
      initCmd: cmd,
      initCmdRun: false,
    ),
  );
}

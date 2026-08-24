import 'package:extended_image/extended_image.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// The address a server's mark is fetched from, or null if there is none.
///
/// **This app ships no distribution marks.** It works out which distribution a
/// machine runs and expands that into an address the user configured; the
/// picture at the other end is not this repository's, and it is fetched only
/// because someone asked for it by writing the address down.
///
/// [override] is the per-server address (`Spi.custom.logoUrl`), which wins over
/// the global setting exactly as it does for the large logo on the detail page.
///
/// Null in three cases, all of which draw nothing: no address configured, an
/// address that wants `{DIST}` for a machine whose distribution is not known,
/// and one that is not http. The last is a guard rather than a nicety — the
/// value is user-entered and reaches an image loader.
String? distMarkUrl({
  required Dist? dist,
  String? override,
  required bool dark,
}) {
  final configured = override ?? Stores.setting.serverLogoUrl.fetch();
  if (configured.isEmpty) return null;

  var url = resolveLogoUrl(configured);
  if (url.contains(_distToken)) {
    if (dist == null) return null;
    url = url.replaceAll(_distToken, distFileName(dist));
  }
  url = url.replaceAll(_brightToken, dark ? 'dark' : 'light');
  if (!url.startsWith('http')) return null;
  return url;
}

/// What `{DIST}` becomes for [dist] — its own case name unless the user has
/// said otherwise.
///
/// The case name is the app's published contract and cannot change. But it
/// only matches the file names of the collection it was written against, and
/// the collection is now the user's choice: font-logos names Arch `archlinux`
/// and RHEL `redhat`, so somebody pointing `{DIST}` at it needs those two
/// renamed and the other sixty-odd left alone.
///
/// No table is shipped for this on purpose. There is no single right one — a
/// mapping correct for one collection is wrong for the next — and a wrong
/// entry would be worse than none, since it silently fetches the wrong logo
/// rather than nothing. `Stores.setting.distNameMap` is where the exceptions
/// go, edited by hand.
String distFileName(Dist dist) =>
    Stores.setting.distNameMap.fetch()[dist.name] ?? dist.name;

/// Whether the address names an SVG, which needs a different loader.
///
/// The path rather than the whole string: a query or a fragment after it is
/// common on a CDN and says nothing about the format.
bool _isSvgUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.svg');
}

const _distToken = '{DIST}';
const _brightToken = '{BRIGHT}';

/// Which distribution a server runs, as the mark its own project publishes —
/// fetched from wherever the person using this app pointed it.
///
/// Nothing in a `Spi` says what is installed on the far end; it is observed,
/// not configured. So this reads the live status when there is one and the
/// cache when there is not, which is what lets a mark appear on rows that
/// never hold a status: the known-hosts page, the order page, and every picker
/// showing a server that is not currently connected.
///
/// Draws nothing at all when there is no address, which out of the box is
/// every server. That is the arrangement, not a gap — see [distMarkUrl].
class DistIcon extends ConsumerWidget {
  const DistIcon(this.serverId, {super.key, this.size = 20});

  /// `Spi.id`. An id and not a `Dist`, so a caller holding only the record it
  /// is listing does not have to reach for the status itself.
  final String serverId;

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Stores.setting.showDistIcon.fetch()) {
      return SizedBox.square(dimension: size);
    }

    // Read off the map rather than `serverProvider(id)`, which throws for an
    // id it does not know — the known-hosts page lists ids of servers that may
    // since have been deleted.
    final spi = ref.watch(serversProvider).servers[serverId];
    // The live reading first: it is the newer of the two, and on a server
    // being polled right now it is what the cache is about to be set to.
    final live = spi == null
        ? null
        : ref.watch(serverProvider(serverId)).status.dist;

    // Rebuilt when the cache changes, so a row drawn before the first poll
    // picks up the answer when it lands rather than staying blank until
    // something else happens to rebuild it.
    return StreamBuilder<void>(
      stream: Stores.serverDist.changes,
      builder: (_, _) => DistIconOf(
        live ?? Stores.serverDist.get(serverId),
        logoUrl: spi?.custom?.logoUrl,
        size: size,
      ),
    );
  }
}

/// [DistIcon] for a caller that already knows the distribution.
///
/// Split out so a widget test, and any code path that has the `Dist` in hand,
/// does not need a provider scope with a server in it.
class DistIconOf extends StatelessWidget {
  const DistIconOf(this.dist, {super.key, this.size = 20, this.logoUrl});

  final Dist? dist;
  final double size;

  /// The per-server address, when the caller has one.
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (!Stores.setting.showDistIcon.fetch()) {
      return SizedBox.square(dimension: size);
    }

    final url = distMarkUrl(
      dist: dist,
      override: logoUrl,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    // A blank of the same size rather than nothing at all: a leading slot that
    // collapses shifts the row's text sideways, and in a list where some
    // servers are recognised and some are not, that is every other row moving.
    if (url == null) return SizedBox.square(dimension: size);

    // Not tinted, unlike the glyphs this replaces. The address points at a
    // project's own artwork in whatever colours that project uses, and
    // recolouring a logo is the thing several trademark policies name.
    return SizedBox.square(
      dimension: size,
      child: _isSvgUrl(url)
          ? SvgPicture.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.contain,
              // Named for the reader that speaks the row aloud: the mark is
              // the only thing on it that says which distribution.
              semanticsLabel: dist?.name,
              placeholderBuilder: (_) => SizedBox.square(dimension: size),
            )
          : ExtendedImage.network(
              url,
              cache: true,
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: dist?.name,
              // Nothing while it loads and nothing if it fails. A broken-image
              // box on every row reads as the app being wrong, and the address
              // is the user's to fix.
              loadStateChanged: (state) =>
                  state.extendedImageLoadState == LoadState.completed
                  ? null
                  : SizedBox.square(dimension: size),
            ),
    );
  }
}

/// What the marks are and what they are not.
///
/// One string, used in both a markdown slot and a plain one — it carries no
/// link any more, because there is no bundled source to point at.
String distLegalMarkdown(AppLocalizations l10n) => l10n.distIconIntroLegal;

/// The same notice for a plain-text slot.
String distLegalPlain(AppLocalizations l10n) => l10n.distIconIntroLegal;

/// Puts the terms up and answers whether the person accepted them.
///
/// Here rather than in the settings page because this is where the wording
/// already lives, and because a page that is `part of entry.dart` cannot be
/// pumped on its own — the decision is worth a test of its own.
Future<bool> confirmDistIconTerms(BuildContext context) async {
  final l10n = context.l10n;
  final agreed = await context.showRoundDialog<bool>(
    title: l10n.distIcon,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SimpleMarkdown(data: distLegalMarkdown(l10n)),
          UIs.height13,
          Text(l10n.distIconConsent),
        ],
      ),
    ),
    actions: Btnx.cancelOk,
  );
  // Dismissing by tapping outside is not agreement.
  return agreed == true;
}

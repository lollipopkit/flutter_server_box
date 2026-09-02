import 'dart:async';

import 'package:extended_image/extended_image.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/logo_url.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/generated/l10n/l10n.dart';

/// The address a server's mark is fetched from, or null if there is none.
///
/// Four marks ship with the app — the ones whose artwork carries a licence
/// permitting it, see [Dist.markAsset] — and everything else is drawn from an
/// address the user configured. This resolves that address; the shipped files
/// are the fallback when there is none.
///
/// **A mark is not the logo.** The logo is the large image at the top of a
/// server's own page and comes from `serverLogoUrl`; this is the small one
/// beside its name in a list, and comes from `serverMarkUrl`. Two addresses
/// because they want two pictures: artwork that reads at full width is a
/// smudge at 20px, and an icon that works at 20px is lost on a detail page.
///
/// Null in three cases, all of which draw nothing: no address configured, an
/// address that wants `{DIST}` for a machine whose distribution is not known,
/// and one whose scheme is neither http nor https. The last is a guard rather
/// than a nicety — the value is user-entered and reaches an image loader.
String? distMarkUrl({required Dist? dist, required bool dark}) {
  final configured = Stores.setting.serverMarkUrl.fetch();
  if (configured.isEmpty) return null;

  var url = resolveLogoUrl(configured);
  if (url.contains(_distToken)) {
    if (dist == null) return null;
    url = url.replaceAll(_distToken, distFileName(dist));
  }
  url = url.replaceAll(_brightToken, dark ? 'dark' : 'light');
  if (!isFetchableLogoUrl(url)) return null;
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

/// The mark for a server, or **null** when marks are switched off.
///
/// Null rather than an empty widget, and that is the whole point: a
/// zero-sized box still occupies a `leading` slot, and `ListTile` reserves
/// width for one whatever it holds. Off has to mean no pixels, so the decision
/// belongs to the caller — every one of them omits the slot on null.
Widget? distIcon(String serverId, {double size = 20}) =>
    Stores.setting.showDistMark.fetch() ? DistIcon(serverId, size: size) : null;

/// [distIcon] for a caller that already knows the distribution.
Widget? distIconOf(Dist? dist, {double size = 20}) =>
    Stores.setting.showDistMark.fetch() ? DistIconOf(dist, size: size) : null;

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
    if (!Stores.setting.showDistMark.fetch()) return const SizedBox.shrink();

    // Read off the map rather than `serverProvider(id)`, which throws for an
    // id it does not know — the known-hosts page lists ids of servers that may
    // since have been deleted.
    final known = ref.watch(serversProvider).servers.containsKey(serverId);
    // The live reading first: it is the newer of the two, and on a server
    // being polled right now it is what the cache is about to be set to.
    final live = known
        ? ref.watch(serverProvider(serverId)).status.dist
        : null;

    // Rebuilt when the cache changes, so a row drawn before the first poll
    // picks up the answer when it lands rather than staying blank until
    // something else happens to rebuild it.
    return StreamBuilder<void>(
      stream: Stores.serverDist.changes,
      builder: (_, _) =>
          DistIconOf(live ?? Stores.serverDist.get(serverId), size: size),
    );
  }
}

/// [DistIcon] for a caller that already knows the distribution.
///
/// Split out so a widget test, and any code path that has the `Dist` in hand,
/// does not need a provider scope with a server in it. Prefer [DistIcon] where
/// there is a server id: it also reads the cache, so a mark is drawn for a
/// server that has been seen before but not yet polled — which is every server
/// for the first few seconds after a restart.
class DistIconOf extends StatelessWidget {
  const DistIconOf(this.dist, {super.key, this.size = 20});

  final Dist? dist;
  final double size;

  /// One colour for every mark, taken from the text beside it.
  ///
  /// The mark only. The large logo on a server's own page is drawn as
  /// published — see `_buildLogo` in `view/page/server/detail/view.dart`,
  /// which says why the two differ.
  ///
  /// The marks are drawn in a list, at the size of a line of text, next to
  /// icons that all follow the row's colour; a column of full-colour logos at
  /// 20px reads as noise rather than as information. Each of the four shipped
  /// licences permits modification and none of those four projects forbids it
  /// — Rocky's did, in as many words, which is why Rocky is no longer among
  /// them. A fetched mark is whatever the user pointed at, and is treated the
  /// same.
  ColorFilter _tint(BuildContext context) =>
      ColorFilter.mode(_tintColor(context), BlendMode.srcIn);

  Color _tintColor(BuildContext context) =>
      IconTheme.of(context).color ??
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Drawn wherever there is no mark: no address and no shipped file, an
  /// address that could not be fetched, or a distribution nothing recognised.
  ///
  /// A blank of the same size would keep the row from shifting just as well,
  /// but it reads as something missing; an icon reads as "not known", which is
  /// the truth.
  ///
  /// Two of them, because there are two different things not to know. A
  /// distribution that *was* recognised and simply has no mark here — Ubuntu
  /// is the case most people will meet — is a Linux for certain, and a penguin
  /// says so. One that was not recognised at all might be a BSD, macOS or
  /// Windows, all of which `uname -or` reaches, so the penguin would be a
  /// guess and the machine is all that can be claimed.
  ///
  /// Takes the same colour as the marks, so a column of them is one column.
  Widget _fallback(BuildContext context) => Icon(
    dist?.isLinux == true ? MingCute.linux_fill : BoxIcons.bxs_server,
    size: size,
    color: _tintColor(context),
  );

  @override
  Widget build(BuildContext context) {
    // Belt and braces. Every call site goes through `distIconOf`, which answers
    // null and lets the slot be omitted — but a widget built directly must not
    // draw a mark the switch says is off.
    if (!Stores.setting.showDistMark.fetch()) return const SizedBox.shrink();

    final url = distMarkUrl(
      dist: dist,
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    // No address: the mark shipped for this distribution, if there is one.
    // Four have a logo whose licence permits redistribution — see
    // `Dist.markAsset`. An address, once set, wins over all of them: somebody
    // who chose a collection wants it used for every row, not four exceptions.
    if (url == null) {
      final asset = dist?.markAsset;
      if (asset == null) return _fallback(context);
      return SvgPicture.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: _tint(context),
        semanticsLabel: dist?.name,
      );
    }

    return SizedBox.square(
      dimension: size,
      child: _isSvgUrl(url)
          ? SvgPicture.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.contain,
              colorFilter: _tint(context),
              // Named for the reader that speaks the row aloud: the mark is
              // the only thing on it that says which distribution.
              semanticsLabel: dist?.name,
              // Blank while it loads rather than the outline: a fallback that
              // appears and is replaced a moment later reads as a glitch, and
              // most of these come from a cache and never draw this at all.
              placeholderBuilder: (_) => SizedBox.square(dimension: size),
              errorBuilder: (_, _, _) => _fallback(context),
            )
          : ExtendedImage.network(
              url,
              cache: true,
              cacheWidth: (size * 2).toInt(),
              cacheHeight: (size * 2).toInt(),
              clearMemoryCacheWhenDispose: true,
              width: size,
              height: size,
              fit: BoxFit.contain,
              // Same tint. On a raster it works off the alpha channel, so a
              // PNG with a solid background becomes a solid block — a thing to
              // know when configuring an address, not something to correct
              // for here.
              color: _tintColor(context),
              colorBlendMode: BlendMode.srcIn,
              semanticLabel: dist?.name,
              // Blank while it loads, the outline if it fails. A broken-image
              // box on every row reads as the app being wrong; the outline
              // reads as "not known", which is what a failed address means.
              loadStateChanged: (state) => switch (state
                  .extendedImageLoadState) {
                LoadState.completed => null,
                LoadState.failed => _fallback(context),
                LoadState.loading => SizedBox.square(dimension: size),
              },
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
/// The terms are `assets/distro/README.md` itself, rendered as markdown — the
/// same file that records, per shipped mark, which licence permits shipping it
/// and what the four rejected ones say instead. A paraphrase would be a second
/// thing to keep true; this way there is one.
///
/// Capped in height and scrollable, because it is long. And the accept button
/// waits [_kReadPause] before it can be pressed: the point of putting this up
/// is that somebody looks at it, and a dialog whose only button is already
/// under the thumb is one that gets dismissed without a glance.
Future<bool> confirmDistIconTerms(BuildContext context) async {
  final l10n = context.l10n;
  final agreed = await context.showRoundDialog<bool>(
    title: l10n.distIcon,
    childBuilder: (ctx) => ConstrainedBox(
      // Half the window, so the dialog never grows past what it can scroll
      // inside — and on a phone in landscape it is the height that runs out.
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.5),
      child: SingleChildScrollView(child: _DistTerms(l10n: l10n)),
    ),
    actionsBuilder: (_) => [Btn.cancel(), const _DelayedOk()],
  );
  // Dismissing by tapping outside is not agreement.
  return agreed == true;
}

/// How long the accept button stays out of reach.
const _kReadPause = Duration(seconds: 3);

/// The README, or the short notice if it cannot be read.
///
/// It is an asset, so reading it is a future; a `FutureBuilder` rather than
/// loading it before the dialog opens, which would leave a gap between the tap
/// and anything appearing.
class _DistTerms extends StatelessWidget {
  const _DistTerms({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/distro/README.md'),
      builder: (_, snapshot) {
        // The short notice while it loads and if it fails. Never nothing:
        // an empty dialog with a countdown on its button is a puzzle.
        final data = snapshot.data ?? distLegalMarkdown(l10n);
        return SimpleMarkdown(
          data: data,
          styleSheet: MarkdownStyleSheet(
            p: UIs.text13Grey,
            h1: UIs.text15Bold,
            h2: UIs.text13Bold,
            tableBody: UIs.text12Grey,
          ),
        );
      },
    );
  }
}

/// An OK button that cannot be pressed for [_kReadPause], counting down.
///
/// Its own widget so the timer lives with the thing it disables, and so the
/// dialog around it stays a plain `showRoundDialog` call.
class _DelayedOk extends StatefulWidget {
  const _DelayedOk();

  @override
  State<_DelayedOk> createState() => _DelayedOkState();
}

class _DelayedOkState extends State<_DelayedOk> {
  Timer? _timer;
  int _left = _kReadPause.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _left <= 0;
    return TextButton(
      // Null, not a no-op: a button that looks pressable and does nothing is
      // worse than one that looks unavailable.
      onPressed: ready ? () => Navigator.of(context).pop(true) : null,
      child: Text(ready ? libL10n.ok : '${libL10n.ok} ($_left)'),
    );
  }
}

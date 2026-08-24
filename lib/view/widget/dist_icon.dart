import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

/// Which distribution a server runs, as a glyph beside its name.
///
/// Nothing in a `Spi` says what is installed on the far end — it is observed,
/// not configured — so this reads the live status when there is one and the
/// cache when there is not. The cache is what makes the mark appear on rows
/// that never hold a status: the known-hosts page, the order page, and every
/// picker showing a server that is not currently connected.
///
/// A server this device has never polled has neither, and draws the fallback,
/// as do the distributions with no mark of their own.
///
/// Single-colour on purpose. These are redrawn glyphs, not each project's own
/// artwork; see `assets/distro/README.md` for where they come from and why
/// using them here needs nobody's permission.
class DistIcon extends ConsumerWidget {
  const DistIcon(this.serverId, {super.key, this.size = 20, this.color});

  /// `Spi.id`. An id and not a `Dist`, so a caller holding only the record it
  /// is listing does not have to reach for the status itself — which most of
  /// them are, since the pickers list servers that may never have connected.
  final String serverId;

  final double size;

  /// Defaults to the row's own foreground colour, at the weight an icon in a
  /// list is drawn at. Tinting is not a change to the mark: an icon font has
  /// always taken the colour it is set in.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The live reading first: it is the newer of the two, and on a server
    // being polled right now it is what the cache is about to be set to.
    if (!Stores.setting.showDistIcon.fetch()) return const SizedBox.shrink();

    final live = ref
        .watch(serverProvider(serverId))
        .status
        .more[StatusCmdType.sys]
        ?.dist;
    // Rebuilt when the cache changes, so a row drawn before the first poll
    // picks up the answer when it lands rather than staying neutral until
    // something else happens to rebuild it.
    return StreamBuilder<void>(
      stream: Stores.serverDist.changes,
      builder: (_, _) => DistIconOf(
        live ?? Stores.serverDist.get(serverId),
        size: size,
        color: color,
      ),
    );
  }
}

/// [DistIcon] for a caller that already knows the distribution.
///
/// Split out so a widget test, and any code path that has the `Dist` in hand,
/// does not need a provider scope with a server in it.
class DistIconOf extends StatelessWidget {
  const DistIconOf(this.dist, {super.key, this.size = 20, this.color});

  final Dist? dist;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Nothing at all when it is off, rather than the neutral outline: the
    // point of turning it off is that the rows carry no mark, and a column of
    // identical outlines is still a column.
    if (!Stores.setting.showDistIcon.fetch()) return const SizedBox.shrink();

    final tint =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    // Nothing known at all draws the neutral outline rather than a penguin:
    // a server that has not been asked may not be running Linux, and the
    // penguin would be a guess. A distribution that *is* known but has no mark
    // of its own picks its own fallback — see `Dist.iconPath`.
    final path = dist?.iconPath ?? kServerIcon;
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      // Named for the reader that speaks the row aloud: the glyph is the only
      // thing on it that says which distribution.
      semanticsLabel: dist?.name ?? 'server',
    );
  }
}
